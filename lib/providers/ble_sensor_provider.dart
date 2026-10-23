import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/bluetooth/ble_uuids.dart';
import '../core/bluetooth/ftms_controller.dart';
import '../core/bluetooth/ftms_data_parser.dart';
import '../core/physics/virtual_shifting.dart';
import '../core/safety/safety_limiter.dart';

class BleSensorProvider extends ChangeNotifier {
  // ─── ÉTAT SCAN ─────────────────────────────────────────────────────────────
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  // ─── PÉRIPHÉRIQUES CONNECTÉS ────────────────────────────────────────────────
  BluetoothDevice? _connectedTrainer;
  BluetoothDevice? _connectedHeartRateDevice;
  FtmsController? _ftmsController;
  StreamSubscription<List<int>>? _heartRateSub;

  // ─── TÉLÉMÉTRIE EN DIRECT ───────────────────────────────────────────────────
  int _powerWatts = 0;
  double _cadenceRpm = 0.0;
  double _speedKmh = 0.0;
  int? _heartRateBpm;
  DateTime _lastTelemetryTime = DateTime.now();

  // ─── CHANGEMENT DE BRAQUET VIRTUEL (ZWIFT COG) ──────────────────────────────
  final VirtualShifter _virtualShifter = VirtualShifter();

  // ─── CONTRÔLEUR DE SÉCURITÉ MATÉRIELLE ──────────────────────────────────────
  late final SafetyLimiter _safetyLimiter;
  Timer? _safetyLimiterTimer;

  // ─── PARAMÈTRES DE CONTRÔLE ─────────────────────────────────────────────────
  int _targetPowerWatts = 0;
  double _simulatedSlopePercent = 0.0;
  int _directResistancePercent = 35; // Résistance de départ équilibrée
  bool _isControllingResistance = false;

  // ─── CONSOLE DE LOGS EN DIRECT ──────────────────────────────────────────────
  final List<String> _logs = [];
  bool _isDisposed = false;

  BleSensorProvider() {
    _safetyLimiter = SafetyLimiter(
      maxPowerCeilingWatts: 450,
      onSafeCommandCalculated: (safeWatts) {
        if (_ftmsController != null && _targetPowerWatts > 0) {
          _ftmsController!.setTargetPower(safeWatts);
        }
      },
    );

    // Boucle de régulation de rampe de sécurité (5 Hz / chaque 200ms)
    _safetyLimiterTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _safetyLimiter.tick();
    });
  }

  // Getters
  bool get isScanning => _isScanning;
  List<ScanResult> get scanResults => _scanResults;
  BluetoothDevice? get connectedTrainer => _connectedTrainer;
  BluetoothDevice? get connectedHeartRateDevice => _connectedHeartRateDevice;
  int get powerWatts => _powerWatts;
  double get cadenceRpm => _cadenceRpm;
  double get speedKmh => _speedKmh;
  int? get heartRateBpm => _heartRateBpm;
  DateTime get lastTelemetryTime => _lastTelemetryTime;
  int get currentVirtualGear => _virtualShifter.currentGear;
  int get totalVirtualGears => VirtualShifter.totalGears;
  double get currentGearRatio => _virtualShifter.currentRatio;
  bool get isEmergencyStopped => _safetyLimiter.isEmergencyStopped;
  bool get hasTrainerControl => _ftmsController?.hasControl ?? false;
  int get targetPowerWatts => _targetPowerWatts;
  double get simulatedSlopePercent => _simulatedSlopePercent;
  int get directResistancePercent => _directResistancePercent;
  bool get isControllingResistance => _isControllingResistance;
  List<String> get logs => List.unmodifiable(_logs);

  void addLog(String message) {
    if (_isDisposed) return;
    final timeStr = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, "[$timeStr] $message");
    if (_logs.length > 100) _logs.removeLast();
    notifyListeners();
  }

  // ─── GESTION DU SCAN BLUETOOTH ──────────────────────────────────────────────
  Future<void> startScan() async {
    if (_isScanning) return;

    _scanResults.clear();
    _isScanning = true;
    notifyListeners();
    addLog("🔍 Démarrage du scan Bluetooth BLE...");

    try {
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        _scanResults = results;
        notifyListeners();
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      addLog("❌ Erreur pendant le scan : $e");
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    notifyListeners();
    addLog("⏹️ Scan Bluetooth arrêté");
  }

  // ─── CONNEXION AU SMART TRAINER (ZWIFT HUB ONE) ─────────────────────────────
  Future<bool> connectTrainer(BluetoothDevice device) async {
    addLog("🔗 Connexion à ${device.platformName} (${device.remoteId})...");

    try {
      await device.connect(license: License.nonprofit, autoConnect: false);
      _connectedTrainer = device;
      addLog("✅ Connecté au trainer ! Initialisation des protocoles...");

      _ftmsController = FtmsController(
        device: device,
        onTelemetryReceived: (telemetry) {
          _powerWatts = telemetry.powerWatts;
          _cadenceRpm = telemetry.cadenceRpm;
          _speedKmh = telemetry.speedKmh;
          if (telemetry.heartRateBpm != null && telemetry.heartRateBpm! > 0) {
            _heartRateBpm = telemetry.heartRateBpm;
          }
          _lastTelemetryTime = DateTime.now();
          notifyListeners();
        },
        onLog: (msg) => addLog(msg),
      );

      final success = await _ftmsController!.initialize();
      if (success) {
        _isControllingResistance = true;
        // Appliquer immédiatement la résistance correspondant au braquet de départ
        await _applyGearResistance();
      }
      notifyListeners();
      return success;
    } catch (e) {
      addLog("❌ Échec de connexion au trainer : $e");
      _connectedTrainer = null;
      notifyListeners();
      return false;
    }
  }

  // ─── CONNEXION À LA CEINTURE CARDIO BLE ──────────────────────────────────────
  Future<bool> connectHeartRate(BluetoothDevice device) async {
    addLog("❤️ Connexion au moniteur cardio ${device.platformName}...");
    try {
      await device.connect(license: License.nonprofit, autoConnect: false);
      _connectedHeartRateDevice = device;

      final services = await device.discoverServices();
      for (final service in services) {
        if (BleUuids.matches(service.uuid.toString(), BleUuids.heartRateService)) {
          for (final char in service.characteristics) {
            if (BleUuids.matches(char.uuid.toString(), BleUuids.heartRateMeasurement)) {
              await char.setNotifyValue(true);
              _heartRateSub = char.onValueReceived.listen((bytes) {
                final bpm = FtmsDataParser.parseHeartRate(bytes);
                if (bpm > 0) {
                  _heartRateBpm = bpm;
                  notifyListeners();
                }
              });
              addLog("✅ Flux cardio connecté avec succès !");
              notifyListeners();
              return true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      addLog("❌ Échec de connexion cardio : $e");
      _connectedHeartRateDevice = null;
      notifyListeners();
      return false;
    }
  }

  // ─── CONTRÔLE DE LA RÉSISTANCE ──────────────────────────────────────────────
  Future<void> requestTrainerControl() async {
    if (_ftmsController != null) {
      final success = await _ftmsController!.requestControl();
      _isControllingResistance = success;
      notifyListeners();
    }
  }

  /// Application de la résistance physique du braquet virtuel
  Future<void> _applyGearResistance() async {
    if (_ftmsController == null) return;

    if (_simulatedSlopePercent != 0.0) {
      // Si une pente est active, la démultiplication ajuste la pente apparente
      final apparentSlope = _virtualShifter.computeApparentSlope(_simulatedSlopePercent);
      await _ftmsController!.setSimulationSlope(slopePercent: apparentSlope);
    } else {
      // En mode libre / plat, chaque vitesse ajuste directement le niveau de frein
      // Vitesse 1 = 12% (très souple) -> Vitesse 12 = 45% -> Vitesse 24 = 92% (très dur)
      final gear = _virtualShifter.currentGear;
      final percent = ((gear - 1) * 3.5 + 12).round().clamp(10, 95);
      _directResistancePercent = percent;
      await _ftmsController!.setTargetResistance(percent);
      addLog("⚙️ Zwift Cog : Vitesse $gear/24 -> Frein appliqué : $percent%");
    }
  }

  // ─── CHANGEMENT DE BRAQUET VIRTUEL (ZWIFT COG) ──────────────────────────────
  void shiftUp() {
    if (_virtualShifter.shiftUp()) {
      addLog("⚙️ Vitesse augmentée : ${_virtualShifter.currentGear}/24 (Ratio: ${_virtualShifter.currentRatio.toStringAsFixed(2)})");
      _applyGearResistance();
      notifyListeners();
    }
  }

  void shiftDown() {
    if (_virtualShifter.shiftDown()) {
      addLog("⚙️ Vitesse descendue : ${_virtualShifter.currentGear}/24 (Ratio: ${_virtualShifter.currentRatio.toStringAsFixed(2)})");
      _applyGearResistance();
      notifyListeners();
    }
  }

  // ─── MODES DE RÉSISTANCE EXPLICITES ─────────────────────────────────────────

  /// Mode Direct : Forcer un pourcentage de frein spécifique (20%, 40%, 60%, 80%)
  Future<void> setDirectResistance(int percent) async {
    _targetPowerWatts = 0;
    _simulatedSlopePercent = 0.0;
    _directResistancePercent = percent;
    if (_ftmsController != null) {
      await _ftmsController!.setTargetResistance(percent);
      addLog("🎚️ Résistance directe imposée : $percent%");
      notifyListeners();
    }
  }

  /// Mode ERG : Puissance cible imposée
  void setTargetPower(int watts) {
    _simulatedSlopePercent = 0.0;
    _targetPowerWatts = watts;
    _safetyLimiter.setTargetPower(watts);
    notifyListeners();
    addLog("⚡ Mode ERG activé : consigne $watts W (Rampe max 20W/s)");
  }

  /// Mode Pente : Simulation d'un col
  Future<void> setSimulatedSlope(double slopePercent) async {
    _targetPowerWatts = 0;
    _simulatedSlopePercent = slopePercent;
    await _applyGearResistance();
    addLog("⛰️ Mode Pente activé : $slopePercent%");
    notifyListeners();
  }

  // ─── ARRÊT D'URGENCE 1-TAP ──────────────────────────────────────────────────
  void triggerEmergencyStop() {
    _safetyLimiter.triggerEmergencyStop();
    _ftmsController?.resetTrainer();
    _targetPowerWatts = 0;
    _simulatedSlopePercent = 0.0;
    addLog("🛑 ARRÊT D'URGENCE DÉCLENCHÉ ! Trainer débrayé en roue libre.");
    notifyListeners();
  }

  void resetEmergencyStop() {
    _safetyLimiter.resetEmergencyStop();
    addLog("🔄 Arrêt d'urgence réinitialisé.");
    notifyListeners();
  }

  // ─── DÉCONNEXION PROPRE ──────────────────────────────────────────────────────
  Future<void> disconnectAll() async {
    _safetyLimiter.triggerEmergencyStop();
    await _ftmsController?.resetTrainer();
    _ftmsController?.dispose();
    _heartRateSub?.cancel();
    await _connectedTrainer?.disconnect();
    await _connectedHeartRateDevice?.disconnect();
    _connectedTrainer = null;
    _connectedHeartRateDevice = null;
    _powerWatts = 0;
    _cadenceRpm = 0;
    _speedKmh = 0;
    _heartRateBpm = null;
    addLog("🔌 Tous les périphériques sont déconnectés");
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _safetyLimiterTimer?.cancel();
    _scanSub?.cancel();
    _safetyLimiter.triggerEmergencyStop();
    _ftmsController?.resetTrainer();
    _ftmsController?.dispose();
    _heartRateSub?.cancel();
    _connectedTrainer?.disconnect();
    _connectedHeartRateDevice?.disconnect();
    super.dispose();
  }
}

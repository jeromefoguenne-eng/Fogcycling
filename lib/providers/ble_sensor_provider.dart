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

  DateTime get lastTelemetryTime => _lastTelemetryTime;

  // ─── CHANGEMENT DE BRAQUET VIRTUEL (ZWIFT COG) ──────────────────────────────
  final VirtualShifter _virtualShifter = VirtualShifter();

  // ─── CONTRÔLEUR DE SÉCURITÉ MATÉRIELLE ──────────────────────────────────────
  late final SafetyLimiter _safetyLimiter;
  Timer? _safetyLimiterTimer;

  // ─── PARAMÈTRES DE CONTRÔLE ─────────────────────────────────────────────────
  int _targetPowerWatts = 0;
  double _simulatedSlopePercent = 0.0;
  bool _isControllingResistance = false;

  // ─── CONSOLE DE LOGS EN DIRECT ──────────────────────────────────────────────
  final List<String> _logs = [];

  BleSensorProvider() {
    _safetyLimiter = SafetyLimiter(
      maxPowerCeilingWatts: 450,
      onSafeCommandCalculated: (safeWatts) {
        if (_ftmsController != null && _ftmsController!.hasControl) {
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
  int get currentVirtualGear => _virtualShifter.currentGear;
  int get totalVirtualGears => VirtualShifter.totalGears;
  double get currentGearRatio => _virtualShifter.currentRatio;
  bool get isEmergencyStopped => _safetyLimiter.isEmergencyStopped;
  bool get hasTrainerControl => _ftmsController?.hasControl ?? false;
  int get targetPowerWatts => _targetPowerWatts;
  double get simulatedSlopePercent => _simulatedSlopePercent;
  bool get isControllingResistance => _isControllingResistance;
  List<String> get logs => List.unmodifiable(_logs);

  bool _isDisposed = false;

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

  void setTargetPower(int watts) {
    _targetPowerWatts = watts;
    _safetyLimiter.setTargetPower(watts);
    notifyListeners();
    addLog("⚡ Consigne puissance demandée : $watts W (Rampe max 20W/s)");
  }

  Future<void> setSimulatedSlope(double slopePercent) async {
    _simulatedSlopePercent = slopePercent;
    if (_ftmsController != null && _ftmsController!.hasControl) {
      // Calcul de la pente apparente selon le rapport virtuel engagé (Zwift Cog)
      final apparentSlope = _virtualShifter.computeApparentSlope(slopePercent);
      await _ftmsController!.setSimulationSlope(slopePercent: apparentSlope);
      addLog("⛰️ Pente simulée : $slopePercent% (Apparente: ${apparentSlope.toStringAsFixed(1)}%)");
      notifyListeners();
    }
  }

  // ─── CHANGEMENT DE BRAQUET VIRTUEL (ZWIFT COG) ──────────────────────────────
  void shiftUp() {
    if (_virtualShifter.shiftUp()) {
      addLog("⚙️ Vitesse augmentée : ${_virtualShifter.currentGear}/24 (Ratio: ${_virtualShifter.currentRatio.toStringAsFixed(2)})");
      // Si en mode simulation de pente, on réapplique immédiatement la nouvelle résistance
      if (_simulatedSlopePercent != 0.0) {
        setSimulatedSlope(_simulatedSlopePercent);
      }
      notifyListeners();
    }
  }

  void shiftDown() {
    if (_virtualShifter.shiftDown()) {
      addLog("⚙️ Vitesse descendue : ${_virtualShifter.currentGear}/24 (Ratio: ${_virtualShifter.currentRatio.toStringAsFixed(2)})");
      if (_simulatedSlopePercent != 0.0) {
        setSimulatedSlope(_simulatedSlopePercent);
      }
      notifyListeners();
    }
  }

  // ─── ARRÊT D'URGENCE 1-TAP ──────────────────────────────────────────────────
  void triggerEmergencyStop() {
    _safetyLimiter.triggerEmergencyStop();
    _ftmsController?.resetTrainer();
    _targetPowerWatts = 0;
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

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_uuids.dart';
import 'ftms_data_parser.dart';

enum TrainerControlMode {
  readOnly,
  targetPowerErg,
  simulationSlope,
  targetResistance,
}

class _QueuedWrite {
  final List<int> bytes;
  final String description;
  final Completer<bool> completer;

  _QueuedWrite({
    required this.bytes,
    required this.description,
    required this.completer,
  });
}

class FtmsController {
  final BluetoothDevice device;

  BluetoothCharacteristic? _controlPointChar;
  BluetoothCharacteristic? _indoorBikeDataChar;
  BluetoothCharacteristic? _cyclingPowerChar;

  StreamSubscription<List<int>>? _telemetrySub;
  StreamSubscription<List<int>>? _powerSub;
  StreamSubscription<List<int>>? _controlPointSub;

  final void Function(TrainerTelemetry telemetry) onTelemetryReceived;
  final void Function(String log) onLog;

  bool _hasControl = false;
  TrainerControlMode _currentMode = TrainerControlMode.readOnly;

  // File d'attente pour sérialiser les écritures GATT (évite les collisions BLE)
  final Queue<_QueuedWrite> _writeQueue = Queue<_QueuedWrite>();
  bool _isProcessingQueue = false;

  FtmsController({
    required this.device,
    required this.onTelemetryReceived,
    required this.onLog,
  });

  bool get hasControl => _hasControl;
  TrainerControlMode get currentMode => _currentMode;

  /// Découverte des services GATT et configuration des caractéristiques
  Future<bool> initialize() async {
    try {
      onLog("🔍 Découverte des services GATT pour ${device.platformName}...");
      final services = await device.discoverServices();

      for (final service in services) {
        final serviceUuid = BleUuids.normalize(service.uuid.toString());

        // 1. Fitness Machine Service (0x1826)
        if (serviceUuid == BleUuids.ftmsService) {
          onLog("✅ Service FTMS (0x1826) détecté !");
          for (final char in service.characteristics) {
            final charUuid = BleUuids.normalize(char.uuid.toString());
            if (charUuid == BleUuids.indoorBikeData) {
              _indoorBikeDataChar = char;
              onLog("   → Caractéristique Indoor Bike Data (0x2AD2) trouvée");
            } else if (charUuid == BleUuids.fitnessMachineControlPoint) {
              _controlPointChar = char;
              onLog("   → Caractéristique Control Point (0x2AD9) trouvée");
            }
          }
        }

        // 2. Cycling Power Service (0x1818)
        if (serviceUuid == BleUuids.cyclingPowerService) {
          onLog("✅ Service CPS (0x1818) détecté !");
          for (final char in service.characteristics) {
            final charUuid = BleUuids.normalize(char.uuid.toString());
            if (charUuid == BleUuids.cyclingPowerMeasurement) {
              _cyclingPowerChar = char;
              onLog("   → Caractéristique Cycling Power (0x2A63) trouvée");
            }
          }
        }
      }

      // Souscription aux notifications de télémétrie (Watts, RPM, Vitesse)
      if (_indoorBikeDataChar != null) {
        await _indoorBikeDataChar!.setNotifyValue(true);
        _telemetrySub = _indoorBikeDataChar!.onValueReceived.listen((bytes) {
          final telemetry = FtmsDataParser.parseIndoorBikeData(bytes);
          onTelemetryReceived(telemetry);
        });
        onLog("📡 Télémétrie FTMS active (Indoor Bike Data)");
      } else if (_cyclingPowerChar != null) {
        await _cyclingPowerChar!.setNotifyValue(true);
        _powerSub = _cyclingPowerChar!.onValueReceived.listen((bytes) {
          final telemetry = FtmsDataParser.parseCyclingPowerMeasurement(bytes);
          onTelemetryReceived(telemetry);
        });
        onLog("📡 Télémétrie CPS de repli active");
      }

      // ⚠️ ÉTAPE CRUCIALE POUR LE CONTRÔLE DE RÉSISTANCE :
      // Activer les indications sur le Control Point (0x2AD9)
      if (_controlPointChar != null) {
        try {
          await _controlPointChar!.setNotifyValue(true);
          _controlPointSub = _controlPointChar!.onValueReceived.listen((bytes) {
            _handleControlPointResponse(bytes);
          });
          onLog("🔔 Indications activées sur Control Point (0x2AD9)");

          // Prise de contrôle automatique immédiate
          await Future.delayed(const Duration(milliseconds: 300));
          await requestControl();
        } catch (e) {
          onLog("⚠️ Erreur configuration Control Point : $e");
        }
        return true;
      } else {
        onLog("⚠️ Ce trainer ne propose pas de caractéristique Control Point.");
        return _indoorBikeDataChar != null;
      }
    } catch (e) {
      onLog("❌ Erreur lors de l'initialisation FTMS : $e");
      return false;
    }
  }

  /// Traitement des réponses retournées par le Control Point (0x80 ...)
  void _handleControlPointResponse(List<int> bytes) {
    if (bytes.length < 3) return;
    if (bytes[0] == 0x80) {
      final reqOpcode = bytes[1];
      final resCode = bytes[2];
      final resName = _decodeResultCode(resCode);

      onLog("📩 Réponse Trainer [Req: 0x${reqOpcode.toRadixString(16)}, Résultat: $resName]");

      if (reqOpcode == 0x00 && resCode == 0x01) {
        _hasControl = true;
        onLog("🎉 Prise de contrôle confirmée par le Zwift Hub !");
      }
    }
  }

  String _decodeResultCode(int code) {
    switch (code) {
      case 0x01: return "Succès (0x01)";
      case 0x02: return "Opcode non supporté (0x02)";
      case 0x03: return "Paramètre invalide (0x03)";
      case 0x04: return "Échec de l'opération (0x04)";
      case 0x05: return "Contrôle non autorisé (0x05)";
      default: return "Code inconnu (0x${code.toRadixString(16)})";
    }
  }

  /// Sérialisation des écritures GATT (FIFO thread-safe)
  Future<bool> _enqueueWrite(List<int> bytes, String description) {
    final completer = Completer<bool>();
    _writeQueue.add(_QueuedWrite(
      bytes: bytes,
      description: description,
      completer: completer,
    ));

    _processQueue();
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_isProcessingQueue || _writeQueue.isEmpty) return;
    _isProcessingQueue = true;

    while (_writeQueue.isNotEmpty) {
      final writeItem = _writeQueue.removeFirst();
      if (_controlPointChar == null) {
        writeItem.completer.complete(false);
        continue;
      }

      try {
        await _controlPointChar!.write(writeItem.bytes, withoutResponse: false);
        writeItem.completer.complete(true);
      } catch (e) {
        // En cas d'échec avec réponse, tentative de repli en write without response
        try {
          await _controlPointChar!.write(writeItem.bytes, withoutResponse: true);
          writeItem.completer.complete(true);
        } catch (e2) {
          onLog("⚠️ Échec d'écriture (${writeItem.description}) : $e2");
          writeItem.completer.complete(false);
        }
      }

      // Pause de 50ms entre deux trames GATT pour laisser respirer le contrôleur Bluetooth
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isProcessingQueue = false;
  }

  /// Prise de contrôle de la machine (Opcode 0x00 : Request Control)
  Future<bool> requestControl() async {
    if (_controlPointChar == null) return false;
    onLog("🔒 Envoi Request Control (Opcode 0x00)...");
    final success = await _enqueueWrite([0x00], "Request Control");
    if (success) {
      _hasControl = true;
    }
    return success;
  }

  /// Réglage Direct du Niveau de Résistance (Opcode 0x04 : Set Target Resistance)
  /// Valeur en pourcentage (0 à 100%)
  Future<bool> setTargetResistance(int percent) async {
    if (_controlPointChar == null) return false;

    // Normalisation : la plupart des trainers FTMS acceptent le niveau de 0.1 ou 1 unité
    final clampedPercent = percent.clamp(0, 100);
    final resistanceUnit = clampedPercent; // 0..100

    final buffer = [0x04, resistanceUnit];
    final success = await _enqueueWrite(buffer, "Set Target Resistance $clampedPercent%");
    if (success) {
      _currentMode = TrainerControlMode.targetResistance;
    }
    return success;
  }

  /// Réglage de la Puissance Cible en Mode ERG (Opcode 0x05 : Set Target Power)
  /// Paramètre : targetWatts (sint16 en Watts)
  Future<bool> setTargetPower(int targetWatts) async {
    if (_controlPointChar == null) return false;

    final buffer = ByteData(3);
    buffer.setUint8(0, 0x05); // Opcode 0x05 : Set Target Power
    buffer.setInt16(1, targetWatts, Endian.little); // Puissance en watts

    final success = await _enqueueWrite(buffer.buffer.asUint8List(), "Set Target Power $targetWatts W");
    if (success) {
      _currentMode = TrainerControlMode.targetPowerErg;
    }
    return success;
  }

  /// Réglage des Paramètres de Simulation de Pente (Opcode 0x11)
  /// Pente : résolution 0.01 % (ex: 5.5% = 550)
  Future<bool> setSimulationSlope({
    required double slopePercent,
    double windSpeedKmh = 0.0,
    double crr = 0.004,
    double cda = 0.32,
  }) async {
    if (_controlPointChar == null) return false;

    final buffer = ByteData(7);
    buffer.setUint8(0, 0x11); // Opcode 0x11 : Set Indoor Bike Simulation Parameters

    // Wind speed (sint16, 0.001 m/s)
    final windMPerS = (windSpeedKmh / 3.6 * 1000).round();
    buffer.setInt16(1, windMPerS, Endian.little);

    // Grade (sint16, 0.01%)
    final gradeRaw = (slopePercent * 100).round();
    buffer.setInt16(3, gradeRaw, Endian.little);

    // Crr (uint8, 0.0001)
    final crrRaw = (crr * 10000).round().clamp(0, 255);
    buffer.setUint8(5, crrRaw);

    // Wind Resistance Coefficient / CdA (uint8, 0.01 kg/m)
    final cdaRaw = (cda * 100).round().clamp(0, 255);
    buffer.setUint8(6, cdaRaw);

    final success = await _enqueueWrite(buffer.buffer.asUint8List(), "Set Slope $slopePercent%");
    if (success) {
      _currentMode = TrainerControlMode.simulationSlope;
    }
    return success;
  }

  /// Remise à zéro / Débrayage d'urgence (Opcode 0x01 : Reset)
  Future<void> resetTrainer() async {
    if (_controlPointChar == null) return;
    await _enqueueWrite([0x01], "Reset Trainer");
    _currentMode = TrainerControlMode.readOnly;
    onLog("🛑 Smart Trainer réinitialisé (roue libre passive)");
  }

  void dispose() {
    _telemetrySub?.cancel();
    _powerSub?.cancel();
    _controlPointSub?.cancel();
    _writeQueue.clear();
  }
}

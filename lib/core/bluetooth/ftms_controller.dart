import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_uuids.dart';
import 'ftms_data_parser.dart';

enum TrainerControlMode {
  readOnly,
  targetPowerErg,
  simulationSlope,
}

class FtmsController {
  final BluetoothDevice device;

  BluetoothCharacteristic? _controlPointChar;
  BluetoothCharacteristic? _indoorBikeDataChar;
  BluetoothCharacteristic? _cyclingPowerChar;

  StreamSubscription<List<int>>? _telemetrySub;
  StreamSubscription<List<int>>? _powerSub;

  final void Function(TrainerTelemetry telemetry) onTelemetryReceived;
  final void Function(String log) onLog;

  bool _hasControl = false;
  TrainerControlMode _currentMode = TrainerControlMode.readOnly;

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

      // Souscription aux notifications de télémétrie
      if (_indoorBikeDataChar != null) {
        await _indoorBikeDataChar!.setNotifyValue(true);
        _telemetrySub = _indoorBikeDataChar!.onValueReceived.listen((bytes) {
          final telemetry = FtmsDataParser.parseIndoorBikeData(bytes);
          onTelemetryReceived(telemetry);
        });
        onLog("📡 Abonnement aux données FTMS actif");
        return true;
      } else if (_cyclingPowerChar != null) {
        await _cyclingPowerChar!.setNotifyValue(true);
        _powerSub = _cyclingPowerChar!.onValueReceived.listen((bytes) {
          final telemetry = FtmsDataParser.parseCyclingPowerMeasurement(bytes);
          onTelemetryReceived(telemetry);
        });
        onLog("📡 Abonnement de repli aux données CPS actif");
        return true;
      } else {
        onLog("⚠️ Aucun flux de puissance standard (FTMS ou CPS) n'a été trouvé.");
        return false;
      }
    } catch (e) {
      onLog("❌ Erreur lors de l'initialisation FTMS : $e");
      return false;
    }
  }

  /// Prise de contrôle de la machine (Opcode 0x00 : Request Control)
  /// Requis par le standard FTMS avant de pouvoir régler la résistance
  Future<bool> requestControl() async {
    if (_controlPointChar == null) {
      onLog("⚠️ Control Point non disponible sur cet appareil");
      return false;
    }

    try {
      onLog("🔒 Envoi de la requête de prise de contrôle (Opcode 0x00)...");
      // Opcode 0x00 = Request Control
      await _controlPointChar!.write([0x00], withoutResponse: false);
      _hasControl = true;
      onLog("✅ Contrôle accordé par le Smart Trainer !");
      return true;
    } catch (e) {
      onLog("❌ Échec de prise de contrôle : $e");
      _hasControl = false;
      return false;
    }
  }

  /// Réglage de la Puissance Cible en Mode ERG (Opcode 0x05 : Set Target Power)
  /// Paramètre : targetWatts (sint16 en Watts)
  Future<bool> setTargetPower(int targetWatts) async {
    if (_controlPointChar == null || !_hasControl) return false;

    try {
      final buffer = ByteData(3);
      buffer.setUint8(0, 0x05); // Opcode 0x05 : Set Target Power
      buffer.setInt16(1, targetWatts, Endian.little); // Puissance en watts

      await _controlPointChar!.write(buffer.buffer.asUint8List(), withoutResponse: false);
      _currentMode = TrainerControlMode.targetPowerErg;
      return true;
    } catch (e) {
      onLog("⚠️ Erreur lors de l'envoi de la puissance cible ($targetWatts W) : $e");
      return false;
    }
  }

  /// Réglage des Paramètres de Simulation de Pente (Opcode 0x11)
  /// Pente : résolution 0.01 % (ex: 5.5% = 550)
  Future<bool> setSimulationSlope({
    required double slopePercent,
    double windSpeedKmh = 0.0,
    double crr = 0.004,
    double cda = 0.32,
  }) async {
    if (_controlPointChar == null || !_hasControl) return false;

    try {
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

      await _controlPointChar!.write(buffer.buffer.asUint8List(), withoutResponse: false);
      _currentMode = TrainerControlMode.simulationSlope;
      return true;
    } catch (e) {
      onLog("⚠️ Erreur lors de l'envoi de la pente ($slopePercent%) : $e");
      return false;
    }
  }

  /// Remise à zéro / Débrayage d'urgence (Opcode 0x01 : Reset)
  Future<void> resetTrainer() async {
    if (_controlPointChar == null) return;
    try {
      await _controlPointChar!.write([0x01], withoutResponse: false);
      _currentMode = TrainerControlMode.readOnly;
      onLog("🛑 Smart Trainer réinitialisé (roue libre passive)");
    } catch (e) {
      onLog("⚠️ Erreur lors du Reset : $e");
    }
  }

  void dispose() {
    _telemetrySub?.cancel();
    _powerSub?.cancel();
  }
}

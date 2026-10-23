import 'dart:typed_data';

/// Modèle contenant la télémétrie décodée d'un Smart Trainer ou capteur
class TrainerTelemetry {
  final int powerWatts;
  final double cadenceRpm;
  final double speedKmh;
  final int? heartRateBpm;
  final double? distanceMeters;
  final int? resistanceLevel;
  final DateTime timestamp;

  const TrainerTelemetry({
    required this.powerWatts,
    required this.cadenceRpm,
    required this.speedKmh,
    this.heartRateBpm,
    this.distanceMeters,
    this.resistanceLevel,
    required this.timestamp,
  });

  factory TrainerTelemetry.empty() {
    return TrainerTelemetry(
      powerWatts: 0,
      cadenceRpm: 0.0,
      speedKmh: 0.0,
      timestamp: DateTime.now(),
    );
  }
}

class FtmsDataParser {
  /// Décode les trames brutes de la caractéristique "Indoor Bike Data" (0x2AD2)
  /// Spécification Bluetooth SIG Fitness Machine Service v1.0
  static TrainerTelemetry parseIndoorBikeData(List<int> rawBytes) {
    if (rawBytes.length < 2) return TrainerTelemetry.empty();

    final data = ByteData.sublistView(Uint8List.fromList(rawBytes));
    int offset = 0;

    // Flags sur 16 bits (Little Endian)
    final flags = data.getUint16(offset, Endian.little);
    offset += 2;

    double speedKmh = 0.0;
    double cadenceRpm = 0.0;
    int powerWatts = 0;
    int? heartRate;
    double? distance;
    int? resistance;

    // Bit 0 : 0 = Instantaneous Speed est présent ! (1 = absent)
    final bool hasSpeed = (flags & (1 << 0)) == 0;
    if (hasSpeed && offset + 2 <= rawBytes.length) {
      speedKmh = data.getUint16(offset, Endian.little) * 0.01;
      offset += 2;
    }

    // Bit 1 : Average Speed
    if ((flags & (1 << 1)) != 0 && offset + 2 <= rawBytes.length) {
      offset += 2; // Ignoré pour télémétrie instantanée
    }

    // Bit 2 : Instantaneous Cadence (résolution 0.5 RPM)
    if ((flags & (1 << 2)) != 0 && offset + 2 <= rawBytes.length) {
      cadenceRpm = data.getUint16(offset, Endian.little) * 0.5;
      offset += 2;
    }

    // Bit 3 : Average Cadence
    if ((flags & (1 << 3)) != 0 && offset + 2 <= rawBytes.length) {
      offset += 2;
    }

    // Bit 4 : Total Distance (24-bit uint)
    if ((flags & (1 << 4)) != 0 && offset + 3 <= rawBytes.length) {
      final b0 = data.getUint8(offset);
      final b1 = data.getUint8(offset + 1);
      final b2 = data.getUint8(offset + 2);
      distance = (b0 | (b1 << 8) | (b2 << 16)).toDouble();
      offset += 3;
    }

    // Bit 5 : Resistance Level (sint16)
    if ((flags & (1 << 5)) != 0 && offset + 2 <= rawBytes.length) {
      resistance = data.getInt16(offset, Endian.little);
      offset += 2;
    }

    // Bit 6 : Instantaneous Power (sint16 en Watts)
    if ((flags & (1 << 6)) != 0 && offset + 2 <= rawBytes.length) {
      powerWatts = data.getInt16(offset, Endian.little);
      if (powerWatts < 0) powerWatts = 0;
      offset += 2;
    }

    // Bit 7 : Average Power
    if ((flags & (1 << 7)) != 0 && offset + 2 <= rawBytes.length) {
      offset += 2;
    }

    // Bit 8 : Expended Energy (kcal + kJ + hour/minute)
    if ((flags & (1 << 8)) != 0 && offset + 5 <= rawBytes.length) {
      offset += 5;
    }

    // Bit 9 : Heart Rate (uint8)
    if ((flags & (1 << 9)) != 0 && offset + 1 <= rawBytes.length) {
      heartRate = data.getUint8(offset);
      offset += 1;
    }

    return TrainerTelemetry(
      powerWatts: powerWatts,
      cadenceRpm: cadenceRpm,
      speedKmh: speedKmh,
      heartRateBpm: heartRate,
      distanceMeters: distance,
      resistanceLevel: resistance,
      timestamp: DateTime.now(),
    );
  }

  /// Décode les trames Cycling Power Measurement (0x2A63)
  static TrainerTelemetry parseCyclingPowerMeasurement(List<int> rawBytes) {
    if (rawBytes.length < 4) return TrainerTelemetry.empty();

    final data = ByteData.sublistView(Uint8List.fromList(rawBytes));
    int offset = 0;

    final flags = data.getUint16(offset, Endian.little);
    offset += 2;

    int powerWatts = data.getInt16(offset, Endian.little);
    if (powerWatts < 0) powerWatts = 0;
    offset += 2;

    // Bit 0 : Pedal Power Balance (optionnel)
    if ((flags & (1 << 0)) != 0 && offset + 1 <= rawBytes.length) {
      offset += 1;
    }

    // Bit 2 : Accumulated Torque (optionnel)
    if ((flags & (1 << 2)) != 0 && offset + 2 <= rawBytes.length) {
      offset += 2;
    }

    // Bit 4 : Wheel Revolution Data
    if ((flags & (1 << 4)) != 0 && offset + 6 <= rawBytes.length) {
      offset += 6;
    }

    // Bit 5 : Crank Revolution Data (permet d'estimer la cadence)
    double cadenceRpm = 0.0;
    // La cadence brute CPS nécessite le différentiel entre 2 paquets successifs
    // Si CPS est couplé à FTMS, FTMS fournit directement la cadence pré-calculée.

    return TrainerTelemetry(
      powerWatts: powerWatts,
      cadenceRpm: cadenceRpm,
      speedKmh: 0.0,
      timestamp: DateTime.now(),
    );
  }

  /// Décode les trames Heart Rate Measurement (0x2A37)
  static int parseHeartRate(List<int> rawBytes) {
    if (rawBytes.isEmpty) return 0;

    final flags = rawBytes[0];
    final bool is16Bit = (flags & 0x01) != 0;

    if (is16Bit && rawBytes.length >= 3) {
      final data = ByteData.sublistView(Uint8List.fromList(rawBytes));
      return data.getUint16(1, Endian.little);
    } else if (rawBytes.length >= 2) {
      return rawBytes[1];
    }
    return 0;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fogcycling/core/bluetooth/ftms_data_parser.dart';
import 'package:fogcycling/core/physics/virtual_shifting.dart';
import 'package:fogcycling/core/safety/safety_limiter.dart';

void main() {
  group('FtmsDataParser Tests', () {
    test('Decodes Instantaneous Power and Cadence correctly from FTMS 0x2AD2', () {
      // Construction d'une trame FTMS Indoor Bike Data :
      // Flags (16-bit) :
      // bit 0 = 0 (Speed present)
      // bit 2 = 1 (Cadence present, bit mask 0x04)
      // bit 6 = 1 (Power present, bit mask 0x40)
      // Flags = 0x0044 -> Little endian: [0x44, 0x00]
      // Speed (uint16, 0.01 km/h) : 30.00 km/h = 3000 = 0x0BB8 -> [0xB8, 0x0B]
      // Cadence (uint16, 0.5 RPM) : 90 RPM = 180 = 0x00B4 -> [0xB4, 0x00]
      // Power (sint16, 1 Watt) : 250 Watts = 0x00FA -> [0xFA, 0x00]
      final rawBytes = [
        0x44, 0x00, // Flags
        0xB8, 0x0B, // Speed 30.00 km/h
        0xB4, 0x00, // Cadence 90 RPM
        0xFA, 0x00, // Power 250 W
      ];

      final telemetry = FtmsDataParser.parseIndoorBikeData(rawBytes);

      expect(telemetry.powerWatts, equals(250));
      expect(telemetry.cadenceRpm, equals(90.0));
      expect(telemetry.speedKmh, closeTo(30.0, 0.01));
    });

    test('Decodes Heart Rate correctly from HRS 0x2A37', () {
      // 8-bit format: flag = 0x00, HR = 145 BPM
      final bytes8Bit = [0x00, 0x91];
      expect(FtmsDataParser.parseHeartRate(bytes8Bit), equals(145));

      // 16-bit format: flag = 0x01, HR = 175 BPM (0x00AF)
      final bytes16Bit = [0x01, 0xAF, 0x00];
      expect(FtmsDataParser.parseHeartRate(bytes16Bit), equals(175));
    });
  });

  group('VirtualShifter (Zwift Cog) Tests', () {
    test('Default gear is 10 and transitions properly across 24 gears', () {
      final shifter = VirtualShifter();

      expect(shifter.currentGear, equals(10));
      expect(shifter.currentRatio, equals(1.95));

      // Shift up (plus dur)
      expect(shifter.shiftUp(), isTrue);
      expect(shifter.currentGear, equals(11));
      expect(shifter.currentRatio, equals(2.15));

      // Shift down (plus souple)
      expect(shifter.shiftDown(), isTrue);
      expect(shifter.currentGear, equals(10));

      // Cap at 24 gears
      shifter.setGear(24);
      expect(shifter.shiftUp(), isFalse);
      expect(shifter.currentGear, equals(24));

      // Cap at 1 gear
      shifter.setGear(1);
      expect(shifter.shiftDown(), isFalse);
      expect(shifter.currentGear, equals(1));
    });

    test('Computes apparent slope based on virtual gear ratio', () {
      final shifter = VirtualShifter();
      // On gear 12 (index 11, neutral reference ratio 2.38)
      shifter.setGear(12);
      expect(shifter.computeApparentSlope(8.0), closeTo(8.0, 0.01));

      // In small gear 1 (mountain gear, ratio 0.85), apparent slope should be softer
      shifter.setGear(1);
      final climbingSlope = shifter.computeApparentSlope(8.0);
      expect(climbingSlope, lessThan(8.0));
      expect(climbingSlope, closeTo(8.0 * (0.85 / 2.38), 0.01));
    });
  });

  group('SafetyLimiter Tests', () {
    test('Respects max power ceiling and emergency stop', () {
      int lastSafeWatts = 0;
      final limiter = SafetyLimiter(
        maxPowerCeilingWatts: 400,
        onSafeCommandCalculated: (w) => lastSafeWatts = w,
      );

      // Request 600W (above 400W ceiling)
      limiter.setTargetPower(600);
      expect(limiter.targetWatts, equals(400));

      // Trigger Emergency Stop
      limiter.triggerEmergencyStop();
      expect(limiter.isEmergencyStopped, isTrue);
      expect(lastSafeWatts, equals(0));

      // Target power during emergency stop should be ignored
      limiter.setTargetPower(200);
      expect(lastSafeWatts, equals(0));

      // Reset emergency stop
      limiter.resetEmergencyStop();
      expect(limiter.isEmergencyStopped, isFalse);
    });
  });
}

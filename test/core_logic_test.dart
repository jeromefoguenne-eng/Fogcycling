import 'package:flutter_test/flutter_test.dart';
import 'package:fogcycling/core/bluetooth/ftms_data_parser.dart';
import 'package:fogcycling/core/physics/virtual_shifting.dart';
import 'package:fogcycling/core/safety/safety_limiter.dart';
import 'package:fogcycling/core/workouts/workout_models.dart';

void main() {
  group('FtmsDataParser Tests', () {
    test('Decodes Instantaneous Power and Cadence correctly from FTMS 0x2AD2', () {
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
      final bytes8Bit = [0x00, 0x91];
      expect(FtmsDataParser.parseHeartRate(bytes8Bit), equals(145));

      final bytes16Bit = [0x01, 0xAF, 0x00];
      expect(FtmsDataParser.parseHeartRate(bytes16Bit), equals(175));
    });
  });

  group('VirtualShifter (Zwift Cog) Tests', () {
    test('Default gear is 10 and transitions properly across 24 gears', () {
      final shifter = VirtualShifter();

      expect(shifter.currentGear, equals(10));
      expect(shifter.currentRatio, equals(1.95));

      expect(shifter.shiftUp(), isTrue);
      expect(shifter.currentGear, equals(11));
      expect(shifter.currentRatio, equals(2.15));

      expect(shifter.shiftDown(), isTrue);
      expect(shifter.currentGear, equals(10));

      shifter.setGear(24);
      expect(shifter.shiftUp(), isFalse);
      expect(shifter.currentGear, equals(24));

      shifter.setGear(1);
      expect(shifter.shiftDown(), isFalse);
      expect(shifter.currentGear, equals(1));
    });

    test('Computes apparent slope based on virtual gear ratio', () {
      final shifter = VirtualShifter();
      shifter.setGear(12);
      expect(shifter.computeApparentSlope(8.0), closeTo(8.0, 0.01));

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

      limiter.setTargetPower(600);
      expect(limiter.targetWatts, equals(400));

      limiter.triggerEmergencyStop();
      expect(limiter.isEmergencyStopped, isTrue);
      expect(lastSafeWatts, equals(0));

      limiter.setTargetPower(200);
      expect(limiter.targetWatts, equals(0));

      limiter.resetEmergencyStop();
      limiter.setTargetPower(200);
      expect(limiter.targetWatts, equals(200));
    });
  });

  group('Workout Engine (Phase 3) Tests', () {
    test('Computes accurate ERG target watts from Athlete FTP', () {
      final workouts = WorkoutCatalog.workouts;
      expect(workouts.length, greaterThanOrEqualTo(3));

      final expressPlan = workouts.first;
      expect(expressPlan.totalDurationSeconds, equals(300)); // 5 minutes

      // Segment 1: 50% of 200W FTP = 100W
      expect(expressPlan.segments[0].targetWattsForFtp(200), equals(100));
      expect(expressPlan.segments[0].zoneName, equals("Z1 RÉCUP"));

      // Segment 4: 100% of 240W FTP = 240W
      expect(expressPlan.segments[3].targetWattsForFtp(240), equals(240));
      expect(expressPlan.segments[3].zoneName, equals("Z4 SEUIL"));
    });
  });
}

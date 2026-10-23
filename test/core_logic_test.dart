import 'package:flutter_test/flutter_test.dart';
import 'package:fogcycling/core/bluetooth/ftms_data_parser.dart';
import 'package:fogcycling/core/career/races_and_peloton_models.dart';
import 'package:fogcycling/core/physics/virtual_shifting.dart';
import 'package:fogcycling/core/profile/athlete_profile_models.dart';
import 'package:fogcycling/core/routes/mythical_routes.dart';
import 'package:fogcycling/core/safety/safety_limiter.dart';
import 'package:fogcycling/core/strava/strava_exporter.dart';
import 'package:fogcycling/core/workouts/workout_models.dart';
import 'package:fogcycling/core/multiplayer/multiplayer_models.dart';
import 'package:fogcycling/core/coach/coach_stravos_ai_engine.dart';
import 'package:fogcycling/core/settings/device_performance_and_storage.dart';
import 'package:fogcycling/providers/athlete_profile_provider.dart';
import 'package:fogcycling/providers/multiplayer_provider.dart';

void main() {
  group('FtmsDataParser Tests', () {
    test('Decodes Instantaneous Power and Cadence correctly from FTMS 0x2AD2', () {
      final rawBytes = [
        0x44, 0x00,
        0xB8, 0x0B,
        0xB4, 0x00,
        0xFA, 0x00,
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
      expect(workouts.length, greaterThanOrEqualTo(7));

      final expressPlan = workouts.first;
      expect(expressPlan.totalDurationSeconds, equals(300));

      expect(expressPlan.segments[0].targetWattsForFtp(200), equals(100));
      expect(expressPlan.segments[0].zoneName, equals("Z1 RÉCUP"));

      expect(expressPlan.segments[3].targetWattsForFtp(240), equals(240));
      expect(expressPlan.segments[3].zoneName, equals("Z4 SEUIL"));
    });
  });

  group('Phase 4 — Mythical Routes, AI 10 Levels & Strava Exporter Tests', () {
    test('10 AI difficulty levels scale from 170W to 260W by 10W increments', () {
      final levels = AiDifficultyLevel.allLevels;
      expect(levels.length, equals(10));
      expect(levels[0].averageWatts, equals(170));
      expect(levels[1].averageWatts, equals(180));
      expect(levels[2].averageWatts, equals(190));
      expect(levels[3].averageWatts, equals(200));
      expect(levels[9].averageWatts, equals(260));
    });

    test('MythicalRoutesCatalog contains iconic climbs and interpolates GPS coordinates', () {
      expect(MythicalRoutesCatalog.routes.length, equals(12));
      final ventoux = MythicalRoutesCatalog.getById('mont_ventoux');
      expect(ventoux.komCategory, equals(KomCategory.hc));

      final gpsStart = ventoux.getGpsCoordinatesAt(0);
      expect(gpsStart['lat'], closeTo(44.1238, 0.01));
      expect(gpsStart['ele'], closeTo(340, 1.0));

      final gpsTop = ventoux.getGpsCoordinatesAt(ventoux.totalDistanceMeters);
      expect(gpsTop['ele'], closeTo(1910, 1.0));
    });

    test('StravaExporter generates valid Garmin TCX XML with GPS and Watts', () {
      final xml = StravaExporter.generateGarminTcx(
        activityTitle: 'Montée du Ventoux',
        routeName: 'Mont Ventoux',
        trackpoints: [
          StravaTrackpoint(
            timestamp: DateTime.utc(2026, 10, 23, 14, 0, 0),
            latitude: 44.1238,
            longitude: 5.1802,
            altitudeMeters: 340.0,
            distanceMeters: 10.0,
            watts: 235,
            cadenceRpm: 88,
            heartRateBpm: 152,
          ),
        ],
        totalTimeSeconds: 60,
        totalDistanceMeters: 450.0,
        averageWatts: 235,
        maxWatts: 280,
      );

      expect(xml, contains('<TrainingCenterDatabase'));
      expect(xml, contains('<ns3:Watts>235</ns3:Watts>'));
      expect(xml, contains('<Cadence>88</Cadence>'));
      expect(xml, contains('<LatitudeDegrees>44.123800</LatitudeDegrees>'));
    });
  });

  group('Phase 5 — Athlete Profile, Coggan 7 Power Zones, WKO5 TSS & RBAC Admin Tests', () {
    test('Computes all 7 Coggan power zones accurately from FTP', () {
      final zones = PowerZoneRange.computeCogganZones(220);
      expect(zones.length, equals(7));
      expect(zones[0].zoneNumber, equals(1));
      expect(zones[0].maxWatts, equals(121)); // 55% of 220
      expect(zones[3].zoneNumber, equals(4)); // Z4 Threshold (91% - 105%)
      expect(zones[3].minWatts, equals(199));
      expect(zones[3].maxWatts, equals(231));
    });

    test('Computes accurate WKO5 Training Stress Score (TSS) and updates AthleteProfileProvider', () {
      // 1 hour at FTP (avgWatts = 212 -> NP = 220, FTP = 220 -> IF = 1.0) equals 100 TSS
      final tssOneHourAtFtp = RecordedRideActivity.computeTss(
        durationSeconds: 3600,
        avgWatts: 212,
        ftpWatts: 220,
      );
      expect(tssOneHourAtFtp, closeTo(100.0, 1.0));

      final provider = AthleteProfileProvider();
      expect(provider.isAdmin, isTrue);
      expect(provider.rideHistory.length, greaterThanOrEqualTo(3));

      final initialCount = provider.rideHistory.length;
      provider.recordCompletedRide(
        title: 'Test Mont Ventoux',
        routeName: 'Mont Ventoux',
        durationSeconds: 3600,
        distanceKm: 21.5,
        elevationGainMeters: 1570,
        avgWatts: 210,
        avgCadenceRpm: 85,
        avgHeartRateBpm: 158,
      );
      expect(provider.rideHistory.length, equals(initialCount + 1));

      // Test RBAC protection when switching to standard member role
      provider.toggleRoleForTesting();
      expect(provider.isAdmin, isFalse);
      final countBeforeUnauthorizedSet = provider.auditLogs.length;
      provider.setAdminSafetyMaxWattsCeiling(350); // Should be blocked and logged as RBAC_DENIED
      expect(provider.auditLogs.length, equals(countBeforeUnauthorizedSet + 1));
      expect(provider.auditLogs.first.category, equals('RBAC_DENIED'));
    });
  });

  group('Phase 6 — Realtime Multiplayer, Dead Reckoning & Private Rooms Tests', () {
    test('RiderSyncPacket extrapolates Dead Reckoning distance and serializes to JSON', () {
      const packet = RiderSyncPacket(
        riderId: 'peer_1',
        displayName: 'Maxime V.',
        countryFlag: '🇧🇪',
        clubTag: 'LIEGE',
        distanceMeters: 1000.0,
        lateralOffsetX: -0.35,
        speedMps: 10.0, // 36 km/h
        watts: 252,
        weightKg: 70.0,
        cadenceRpm: 90,
        jerseyHexColor: 0xFFFACC15,
        bikeHexColor: 0xFFF97316,
        timestampMs: 10000,
      );

      expect(packet.wattsPerKg, equals(3.6));
      // 500ms later at 10 m/s -> +5.0 meters (1005.0m)
      expect(packet.extrapolateDistanceAt(10500), closeTo(1005.0, 0.01));

      final jsonMap = packet.toJson();
      final decoded = RiderSyncPacket.fromJson(jsonMap);
      expect(decoded.riderId, equals('peer_1'));
      expect(decoded.watts, equals(252));
    });

    test('MultiplayerProvider manages rooms, private PIN rooms, live gaps and emotes', () {
      final mp = MultiplayerProvider();
      expect(mp.roomRiders.length, equals(9));
      expect(mp.availableRooms.length, greaterThanOrEqualTo(5));

      mp.tickMultiplayer(
        playerWatts: 245,
        playerCadenceRpm: 92,
        playerSpeedKmh: 35.0,
        playerDistanceMeters: 150.0,
        currentSlopePercent: 4.5,
      );

      expect(mp.relativeRidersJsonFor3d, isNotEmpty);

      mp.sendLiveEmote(LiveRaceEmote.rideOn);
      expect(mp.playerActiveEmote, equals(LiveRaceEmote.rideOn));

      final privRoom = mp.createAndJoinPrivateRoom(
        roomTitle: 'Sortie Liège',
        route: MythicalRoutesCatalog.getById('la_roche_aux_faucons'),
        pinCode: '4000',
      );
      expect(privRoom.pinCode, equals('4000'));
      expect(mp.activeRoom.roomId, equals(privRoom.roomId));
    });
  });

  group('Phase 7 & 8 — Coach Stravos AI Engine, W\' Balance (Skiba), PDC, Nutrition & Mobile Presets Tests', () {
    test('W\' Balance depletes above CP/FTP and reconstitutes exponentially below CP', () {
      final engine = CoachStravosAiEngine();
      expect(engine.currentWPrimeBalanceKj, closeTo(18.0, 0.1));

      // Attack at 350W for 20 seconds with CP = 200W -> depletes 150W * 20s = 3000 J (3.0 kJ)
      for (int i = 0; i < 20; i++) {
        engine.updateWPrimeBalance(currentWatts: 350, criticalPowerWatts: 200);
      }
      expect(engine.currentWPrimeBalanceKj, closeTo(15.0, 0.2));

      // Recover at 120W for 30 seconds -> W' balance increases
      for (int i = 0; i < 30; i++) {
        engine.updateWPrimeBalance(currentWatts: 120, criticalPowerWatts: 200);
      }
      expect(engine.currentWPrimeBalanceKj, greaterThanOrEqualTo(15.2));
    });

    test('Generates custom AI ERG workouts adapted to TSB and computes scientific cycling nutrition', () {
      final engine = CoachStravosAiEngine();
      final customPlan = engine.generateCustomWorkout(
        durationMinutes: 45,
        goal: StravosTrainingGoal.puncheurArdennais,
        currentTsbForm: -12.5, // Fatigued -> auto-scales intensity by 0.95
        athleteFtp: 210,
      );
      expect(customPlan.segments.length, greaterThanOrEqualTo(5));
      expect(customPlan.title, contains('45m'));

      final nutrition = engine.computeNutritionPlan(
        durationSeconds: 5400, // 1h30 climb
        avgWatts: 205,
        ftpWatts: 210,
        weightKg: 72.0,
      );
      expect(nutrition.carbsGramsPerHour, equals(90));
      expect(nutrition.hydrationMlPerHour, equals(750));
      expect(nutrition.postRideCarbsGrams, greaterThan(60));
    });

    test('AthleteProfileProvider manages Phase 8 WebGL graphics quality presets', () {
      final profile = AthleteProfileProvider();
      expect(profile.graphicsQuality, equals(GraphicsQualityPreset.balanced60Fps));
      profile.setGraphicsQuality(GraphicsQualityPreset.ecoBattery);
      expect(profile.graphicsQuality, equals(GraphicsQualityPreset.ecoBattery));
      expect(profile.graphicsQuality.jsKey, equals('eco'));
    });
  });
}

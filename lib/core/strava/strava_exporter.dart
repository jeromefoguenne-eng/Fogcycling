import 'dart:io';

/// Point d'enregistrement GPS + Télémétrie (1 Hz) pour Strava
class StravaTrackpoint {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double altitudeMeters;
  final double distanceMeters;
  final int watts;
  final int cadenceRpm;
  final int? heartRateBpm;

  const StravaTrackpoint({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.altitudeMeters,
    required this.distanceMeters,
    required this.watts,
    required this.cadenceRpm,
    this.heartRateBpm,
  });
}

/// Générateur et Exportateur d'activités aux formats standards Strava (.TCX Garmin & .GPX)
class StravaExporter {
  /// Génère le contenu XML complet au standard Garmin Training Center (.TCX)
  /// Ce format est reconnu nativement par Strava avec Carte GPS, Altitude, Watts, Cadence et Cardio.
  static String generateGarminTcx({
    required String activityTitle,
    required String routeName,
    required List<StravaTrackpoint> trackpoints,
    required int totalTimeSeconds,
    required double totalDistanceMeters,
    required int averageWatts,
    required int maxWatts,
  }) {
    final startTimeIso = trackpoints.isNotEmpty
        ? trackpoints.first.timestamp.toUtc().toIso8601String()
        : DateTime.now().toUtc().toIso8601String();

    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln(
        '<TrainingCenterDatabase xsi:schemaLocation="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2 http://www.garmin.com/xmlschemas/TrainingCenterDatabasev2.xsd" xmlns:ns5="http://www.garmin.com/xmlschemas/ActivityGoals/v1" xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2" xmlns:ns2="http://www.garmin.com/xmlschemas/UserProfile/v2" xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">');
    buffer.writeln('  <Activities>');
    buffer.writeln('    <Activity Sport="Biking">');
    buffer.writeln('      <Id>$startTimeIso</Id>');
    buffer.writeln('      <Notes>$activityTitle - Parcours : $routeName (Fogcycling Virtual Trainer)</Notes>');
    buffer.writeln('      <Lap StartTime="$startTimeIso">');
    buffer.writeln('        <TotalTimeSeconds>$totalTimeSeconds</TotalTimeSeconds>');
    buffer.writeln('        <DistanceMeters>${totalDistanceMeters.toStringAsFixed(1)}</DistanceMeters>');
    buffer.writeln('        <Calories>${((averageWatts * totalTimeSeconds) / 1000 * 0.95).round()}</Calories>');
    buffer.writeln('        <Intensity>Active</Intensity>');
    buffer.writeln('        <TriggerMethod>Manual</TriggerMethod>');
    buffer.writeln('        <Track>');

    for (final pt in trackpoints) {
      buffer.writeln('          <Trackpoint>');
      buffer.writeln('            <Time>${pt.timestamp.toUtc().toIso8601String()}</Time>');
      buffer.writeln('            <Position>');
      buffer.writeln('              <LatitudeDegrees>${pt.latitude.toStringAsFixed(6)}</LatitudeDegrees>');
      buffer.writeln('              <LongitudeDegrees>${pt.longitude.toStringAsFixed(6)}</LongitudeDegrees>');
      buffer.writeln('            </Position>');
      buffer.writeln('            <AltitudeMeters>${pt.altitudeMeters.toStringAsFixed(1)}</AltitudeMeters>');
      buffer.writeln('            <DistanceMeters>${pt.distanceMeters.toStringAsFixed(1)}</DistanceMeters>');
      if (pt.heartRateBpm != null && pt.heartRateBpm! > 0) {
        buffer.writeln('            <HeartRateBpm><Value>${pt.heartRateBpm}</Value></HeartRateBpm>');
      }
      buffer.writeln('            <Cadence>${pt.cadenceRpm.clamp(0, 220)}</Cadence>');
      buffer.writeln('            <Extensions>');
      buffer.writeln('              <ns3:TPX>');
      buffer.writeln('                <ns3:Watts>${pt.watts}</ns3:Watts>');
      buffer.writeln('              </ns3:TPX>');
      buffer.writeln('            </Extensions>');
      buffer.writeln('          </Trackpoint>');
    }

    buffer.writeln('        </Track>');
    buffer.writeln('        <Extensions>');
    buffer.writeln('          <ns3:LX>');
    buffer.writeln('            <ns3:AvgWatts>$averageWatts</ns3:AvgWatts>');
    buffer.writeln('            <ns3:MaxWatts>$maxWatts</ns3:MaxWatts>');
    buffer.writeln('          </ns3:LX>');
    buffer.writeln('        </Extensions>');
    buffer.writeln('      </Lap>');
    buffer.writeln('    </Activity>');
    buffer.writeln('  </Activities>');
    buffer.writeln('</TrainingCenterDatabase>');

    return buffer.toString();
  }

  /// Sauvegarde le fichier .TCX sur le stockage de l'appareil pour envoi ou partage Strava
  static Future<String> saveTcxFile({
    required String activityTitle,
    required String routeName,
    required List<StravaTrackpoint> trackpoints,
    required int totalTimeSeconds,
    required double totalDistanceMeters,
    required int averageWatts,
    required int maxWatts,
  }) async {
    final xml = generateGarminTcx(
      activityTitle: activityTitle,
      routeName: routeName,
      trackpoints: trackpoints,
      totalTimeSeconds: totalTimeSeconds,
      totalDistanceMeters: totalDistanceMeters,
      averageWatts: averageWatts,
      maxWatts: maxWatts,
    );

    final safeDate = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    final dir = Directory.systemTemp;
    final filePath = '${dir.path}/Fogcycling_Strava_$safeDate.tcx';
    final file = File(filePath);
    await file.writeAsString(xml);
    return filePath;
  }
}

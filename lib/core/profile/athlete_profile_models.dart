import 'package:flutter/material.dart';

/// Zone de puissance physiologique d'Andrew Coggan (Z1 à Z7) calculée selon la FTP
class PowerZoneRange {
  final int zoneNumber;
  final String name;
  final int minWatts;
  final int maxWatts;
  final Color color;

  const PowerZoneRange({
    required this.zoneNumber,
    required this.name,
    required this.minWatts,
    required this.maxWatts,
    required this.color,
  });

  static List<PowerZoneRange> computeCogganZones(int ftp) {
    return [
      PowerZoneRange(
        zoneNumber: 1,
        name: 'Z1 Récupération Active (<55%)',
        minWatts: 0,
        maxWatts: (ftp * 0.55).round(),
        color: const Color(0xFF94A3B8),
      ),
      PowerZoneRange(
        zoneNumber: 2,
        name: 'Z2 Endurance Fondamentale (56-75%)',
        minWatts: (ftp * 0.55).round() + 1,
        maxWatts: (ftp * 0.75).round(),
        color: const Color(0xFF38BDF8),
      ),
      PowerZoneRange(
        zoneNumber: 3,
        name: 'Z3 Tempo / Rythme (76-90%)',
        minWatts: (ftp * 0.75).round() + 1,
        maxWatts: (ftp * 0.90).round(),
        color: const Color(0xFF22C55E),
      ),
      PowerZoneRange(
        zoneNumber: 4,
        name: 'Z4 Seuil Lactique FTP (91-105%)',
        minWatts: (ftp * 0.90).round() + 1,
        maxWatts: (ftp * 1.05).round(),
        color: const Color(0xFFFACC15),
      ),
      PowerZoneRange(
        zoneNumber: 5,
        name: 'Z5 PMA / VO2max (106-120%)',
        minWatts: (ftp * 1.05).round() + 1,
        maxWatts: (ftp * 1.20).round(),
        color: const Color(0xFFF97316),
      ),
      PowerZoneRange(
        zoneNumber: 6,
        name: 'Z6 Capacité Anaérobie (121-150%)',
        minWatts: (ftp * 1.20).round() + 1,
        maxWatts: (ftp * 1.50).round(),
        color: const Color(0xFFEF4444),
      ),
      PowerZoneRange(
        zoneNumber: 7,
        name: 'Z7 Puissance Neuromusculaire (>150%)',
        minWatts: (ftp * 1.50).round() + 1,
        maxWatts: 2000,
        color: const Color(0xFFA855F7),
      ),
    ];
  }
}

/// Modèle de vélo dans le Garage 3D de l'Espace Membre
class GarageBikeModel {
  final String id;
  final String name;
  final String specialty;
  final double weightKg;
  final String hexColor;
  final Color displayColor;

  const GarageBikeModel({
    required this.id,
    required this.name,
    required this.specialty,
    required this.weightKg,
    required this.hexColor,
    required this.displayColor,
  });

  static const List<GarageBikeModel> catalog = [
    GarageBikeModel(
      id: 'fog_aero_orange',
      name: 'Fogcycling Aero S-Pro Orange',
      specialty: 'Polyvalent & Aérodynamique',
      weightKg: 7.4,
      hexColor: '0xf97316',
      displayColor: Color(0xFFF97316),
    ),
    GarageBikeModel(
      id: 'climber_ultralight',
      name: 'Alpe Featherweight 6.8 Blanc',
      specialty: 'Grimpeur Pur (Ventoux / Galibier)',
      weightKg: 6.8,
      hexColor: '0xf8fafc',
      displayColor: Color(0xFFF8FAFC),
    ),
    GarageBikeModel(
      id: 'flandrien_cobble',
      name: 'Flandrien Cobble-Master Bleu',
      specialty: 'Pavés & Classiques (Quaremont / Roubaix)',
      weightKg: 7.6,
      hexColor: '0x38bdf8',
      displayColor: Color(0xFF38BDF8),
    ),
    GarageBikeModel(
      id: 'tt_chrono_gold',
      name: 'Chrono Gold Edition',
      specialty: 'Contre-la-Montre & Haute Vitesse',
      weightKg: 7.9,
      hexColor: '0xfacc15',
      displayColor: Color(0xFFFACC15),
    ),
  ];
}

/// Modèle de maillot dans le Garage 3D
class GarageJerseyModel {
  final String id;
  final String name;
  final String hexColor;
  final Color displayColor;

  const GarageJerseyModel({
    required this.id,
    required this.name,
    required this.hexColor,
    required this.displayColor,
  });

  static const List<GarageJerseyModel> catalog = [
    GarageJerseyModel(
      id: 'fogcycling_pro',
      name: 'Maillot Pro Team Fogcycling (Bleu & Or)',
      hexColor: '0x0284c7',
      displayColor: Color(0xFF0284C7),
    ),
    GarageJerseyModel(
      id: 'maillot_jaune',
      name: '🟡 Maillot Jaune (Leader Grand Tour)',
      hexColor: '0xfacc15',
      displayColor: Color(0xFFFACC15),
    ),
    GarageJerseyModel(
      id: 'maillot_pois',
      name: '🔴⚪ Maillot Rouge à Pois (Roi de la Montagne)',
      hexColor: '0xef4444',
      displayColor: Color(0xFFEF4444),
    ),
    GarageJerseyModel(
      id: 'maillot_vert',
      name: '🟢 Maillot Vert (Leader Sprinteur)',
      hexColor: '0x22c55e',
      displayColor: Color(0xFF22C55E),
    ),
    GarageJerseyModel(
      id: 'maglia_rosa',
      name: '🩷 Maglia Rosa (Leader du Giro)',
      hexColor: '0xf472b6',
      displayColor: Color(0xFFF472B6),
    ),
  ];
}

/// Activité enregistrée dans l'historique du membre (avec métriques WKO5 : NP, IF, TSS)
class RecordedRideActivity {
  final String id;
  final String title;
  final String routeName;
  final DateTime date;
  final int durationSeconds;
  final double distanceKm;
  final int elevationGainMeters;
  final int avgWatts;
  final int normalizedPowerWatts;
  final double intensityFactor;
  final double trainingStressScore;
  final int avgCadenceRpm;
  final int? avgHeartRateBpm;

  const RecordedRideActivity({
    required this.id,
    required this.title,
    required this.routeName,
    required this.date,
    required this.durationSeconds,
    required this.distanceKm,
    required this.elevationGainMeters,
    required this.avgWatts,
    required this.normalizedPowerWatts,
    required this.intensityFactor,
    required this.trainingStressScore,
    required this.avgCadenceRpm,
    this.avgHeartRateBpm,
  });

  /// Calcule le TSS (Training Stress Score) officiel selon la formule Coggan
  static double computeTss({
    required int durationSeconds,
    required int avgWatts,
    required int ftpWatts,
  }) {
    if (ftpWatts <= 0 || durationSeconds <= 0) return 0.0;
    final np = (avgWatts * 1.04).round();
    final intensityFactor = np / ftpWatts;
    final tss = (durationSeconds * np * intensityFactor) / (ftpWatts * 3600.0) * 100.0;
    return double.parse(tss.toStringAsFixed(1));
  }
}

/// Entrée du journal d'audit de sécurité (Espace Administrateur Phase 5)
class SecurityAuditEntry {
  final DateTime timestamp;
  final String category;
  final String severity; // 'INFO', 'WARN', 'CRITICAL'
  final String message;

  const SecurityAuditEntry({
    required this.timestamp,
    required this.category,
    required this.severity,
    required this.message,
  });
}

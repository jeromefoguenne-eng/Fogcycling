import 'package:flutter/material.dart';

/// Modèle de segment unitaire d'une séance d'entraînement structurée (Phase 3).
class WorkoutSegment {
  final String name;
  final int durationSeconds;
  final double ftpFactor; // Ex: 0.55 pour 55% de la FTP, 1.00 pour 100% FTP
  final int targetCadenceRpm;
  final String coachAdvice;

  const WorkoutSegment({
    required this.name,
    required this.durationSeconds,
    required this.ftpFactor,
    required this.targetCadenceRpm,
    required this.coachAdvice,
  });

  /// Calcule la puissance cible en Watts selon la FTP de l'athlète
  int targetWattsForFtp(int userFtp) {
    return (userFtp * ftpFactor).round().clamp(50, 450);
  }

  /// Couleur Coggan associée à l'intensité du bloc
  Color get zoneColor {
    if (ftpFactor < 0.60) return const Color(0xFF94A3B8); // Z1 Récupération (Gris)
    if (ftpFactor < 0.76) return const Color(0xFF38BDF8); // Z2 Endurance (Bleu)
    if (ftpFactor < 0.90) return const Color(0xFF22C55E); // Z3 Tempo (Vert)
    if (ftpFactor < 1.05) return const Color(0xFFFACC15); // Z4 Seuil (Jaune/Or)
    if (ftpFactor < 1.20) return const Color(0xFFF97316); // Z5 PMA (Orange)
    return const Color(0xFFEF4444); // Z6 Anaérobie (Rouge)
  }

  String get zoneName {
    if (ftpFactor < 0.60) return "Z1 RÉCUP";
    if (ftpFactor < 0.76) return "Z2 ENDURANCE";
    if (ftpFactor < 0.90) return "Z3 TEMPO";
    if (ftpFactor < 1.05) return "Z4 SEUIL";
    if (ftpFactor < 1.20) return "Z5 PMA";
    return "Z6 MAX";
  }
}

/// Plan d'entraînement complet composé d'une séquence de blocs.
class WorkoutPlan {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final List<WorkoutSegment> segments;

  const WorkoutPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.segments,
  });

  int get totalDurationSeconds =>
      segments.fold(0, (sum, item) => sum + item.durationSeconds);

  String get formattedTotalDuration {
    final mins = (totalDurationSeconds / 60).round();
    return "$mins min";
  }
}

/// Catalogue officiel des séances structurées conçues par Coach Stravos.
class WorkoutCatalog {
  static const List<WorkoutPlan> workouts = [
    // 1. SÉANCE DE VALIDATION RAPIDE (5 MINUTES)
    WorkoutPlan(
      id: 'express_erg_test',
      title: 'Test Express ERG (5 min)',
      subtitle: 'Blocs courts de 45s à 60s pour sentir les paliers automatiques du Zwift Hub One.',
      category: 'DÉCOUVERTE & CALIBRATION',
      segments: [
        WorkoutSegment(
          name: 'Mise en jambes Z1',
          durationSeconds: 45,
          ftpFactor: 0.50,
          targetCadenceRpm: 85,
          coachAdvice: 'Coach Stravos : Souplesse maximale, laissez le frein ERG stabiliser la résistance.',
        ),
        WorkoutSegment(
          name: 'Activation Endurance Z2',
          durationSeconds: 45,
          ftpFactor: 0.70,
          targetCadenceRpm: 90,
          coachAdvice: 'Coach Stravos : Accélérez légèrement la cadence à 90 RPM sans écraser les pédales.',
        ),
        WorkoutSegment(
          name: 'Palier Tempo Z3',
          durationSeconds: 60,
          ftpFactor: 0.85,
          targetCadenceRpm: 88,
          coachAdvice: 'Coach Stravos : Gainage abdominal engagé, coup de pédale bien rond.',
        ),
        WorkoutSegment(
          name: 'Effort Seuil FTP Z4',
          durationSeconds: 60,
          ftpFactor: 1.00,
          targetCadenceRpm: 92,
          coachAdvice: 'Coach Stravos : Maintenez la cadence haute ! Si elle chute, le frein ERG se durcit.',
        ),
        WorkoutSegment(
          name: 'Récupération Active Z1',
          durationSeconds: 45,
          ftpFactor: 0.50,
          targetCadenceRpm: 80,
          coachAdvice: 'Coach Stravos : Relâchez les épaules et ventilez profondément.',
        ),
        WorkoutSegment(
          name: 'Punch PMA Z5',
          durationSeconds: 45,
          ftpFactor: 1.18,
          targetCadenceRpm: 98,
          coachAdvice: 'Coach Stravos : Dernier bloc explosif ! Vélocité maximale jusqu\'au portique !',
        ),
      ],
    ),

    // 2. SWEET SPOT & SEUIL (24 MINUTES)
    WorkoutPlan(
      id: 'sweet_spot_builder',
      title: 'Sweet Spot & Seuil (24 min)',
      subtitle: '3 répétitions à 90% FTP pour élever votre seuil lactique avec un coût de fatigue maîtrisé.',
      category: 'SEUIL & FTP',
      segments: [
        WorkoutSegment(
          name: 'Échauffement Z1',
          durationSeconds: 180,
          ftpFactor: 0.55,
          targetCadenceRpm: 85,
          coachAdvice: 'Coach Stravos : Début de séance progressif, faites monter la température musculaire.',
        ),
        WorkoutSegment(
          name: 'Déblocage Z2',
          durationSeconds: 120,
          ftpFactor: 0.72,
          targetCadenceRpm: 90,
          coachAdvice: 'Coach Stravos : Ouvrez la cage thoracique, préparez le premier bloc Sweet Spot.',
        ),
        WorkoutSegment(
          name: 'Sweet Spot #1 (90% FTP)',
          durationSeconds: 240,
          ftpFactor: 0.90,
          targetCadenceRpm: 90,
          coachAdvice: 'Coach Stravos : Zone d\'or 90% FTP. Restez assis, mains en haut du cintre.',
        ),
        WorkoutSegment(
          name: 'Récupération #1',
          durationSeconds: 120,
          ftpFactor: 0.52,
          targetCadenceRpm: 82,
          coachAdvice: 'Coach Stravos : Hydratez-vous dès maintenant, 2 minutes de relâchement.',
        ),
        WorkoutSegment(
          name: 'Sweet Spot #2 (92% FTP)',
          durationSeconds: 240,
          ftpFactor: 0.92,
          targetCadenceRpm: 88,
          coachAdvice: 'Coach Stravos : Deuxième série. Ne laissez pas tomber la cadence sous 85 RPM.',
        ),
        WorkoutSegment(
          name: 'Récupération #2',
          durationSeconds: 120,
          ftpFactor: 0.52,
          targetCadenceRpm: 82,
          coachAdvice: 'Coach Stravos : Très belle régularité. Il reste un dernier bloc de travail.',
        ),
        WorkoutSegment(
          name: 'Seuil Final #3 (96% FTP)',
          durationSeconds: 240,
          ftpFactor: 0.96,
          targetCadenceRpm: 92,
          coachAdvice: 'Coach Stravos : Dernier bloc proche de votre FTP ! Mobilisez toute votre concentration.',
        ),
        WorkoutSegment(
          name: 'Retour au calme',
          durationSeconds: 180,
          ftpFactor: 0.48,
          targetCadenceRpm: 80,
          coachAdvice: 'Coach Stravos : Séance accomplie avec brio. Tournez les jambes souplement.',
        ),
      ],
    ),

    // 3. PYRAMIDE PMA / VO2MAX
    WorkoutPlan(
      id: 'pma_pyramid_vo2',
      title: 'Pyramide PMA VO2max (18 min)',
      subtitle: 'Intervalles intenses en Zone 5 (110% à 120% FTP) pour développer votre cylindrée aérobie.',
      category: 'VO2MAX & PMA',
      segments: [
        WorkoutSegment(
          name: 'Échauffement Progressif',
          durationSeconds: 180,
          ftpFactor: 0.60,
          targetCadenceRpm: 88,
          coachAdvice: 'Coach Stravos : Échauffement essentiel avant de solliciter le système cardiovasculaire.',
        ),
        WorkoutSegment(
          name: 'Déblocage Seuil',
          durationSeconds: 60,
          ftpFactor: 0.95,
          targetCadenceRpm: 95,
          coachAdvice: 'Coach Stravos : 1 minute de mise sous tension avant l\'attaque de la pyramide.',
        ),
        WorkoutSegment(
          name: 'Récupération Pré-Série',
          durationSeconds: 60,
          ftpFactor: 0.50,
          targetCadenceRpm: 80,
          coachAdvice: 'Coach Stravos : Respirez calmement, départ de la pyramide dans quelques secondes.',
        ),
        WorkoutSegment(
          name: 'PMA 1 min (112% FTP)',
          durationSeconds: 60,
          ftpFactor: 1.12,
          targetCadenceRpm: 96,
          coachAdvice: 'Coach Stravos : Premier échelon de la pyramide. Cadence vive !',
        ),
        WorkoutSegment(
          name: 'Récupération Active',
          durationSeconds: 60,
          ftpFactor: 0.50,
          targetCadenceRpm: 82,
          coachAdvice: 'Coach Stravos : Récupération 1:1. Faites redescendre les pulsations.',
        ),
        WorkoutSegment(
          name: 'Sommet PMA 90s (115% FTP)',
          durationSeconds: 90,
          ftpFactor: 1.15,
          targetCadenceRpm: 95,
          coachAdvice: 'Coach Stravos : Cœur de séance ! Tenez le haut du pavé pendant 90 secondes.',
        ),
        WorkoutSegment(
          name: 'Récupération Active',
          durationSeconds: 90,
          ftpFactor: 0.50,
          targetCadenceRpm: 80,
          coachAdvice: 'Coach Stravos : Le plus dur est derrière vous. Préparez le sprint final.',
        ),
        WorkoutSegment(
          name: 'Finish Explosif 60s (120% FTP)',
          durationSeconds: 60,
          ftpFactor: 1.20,
          targetCadenceRpm: 100,
          coachAdvice: 'Coach Stravos : Donnez tout sur cette dernière minute à 120% FTP !',
        ),
        WorkoutSegment(
          name: 'Retour au calme Z1',
          durationSeconds: 180,
          ftpFactor: 0.45,
          targetCadenceRpm: 80,
          coachAdvice: 'Coach Stravos : Excellente séance VO2max. Relâchement complet.',
        ),
      ],
    ),
  ];
}

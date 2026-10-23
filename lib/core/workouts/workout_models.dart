import 'package:flutter/material.dart';

/// Niveau d'intensité globale d'une séance ou d'un plan (Filtre façon Zwift)
enum WorkoutIntensity {
  all('Toutes intensités'),
  soft('Douce (Z1-Z2 Récup)'),
  moderate('Modérée (Z3 Tempo & Force)'),
  intense('Intense (Z4 Seuil & FTP)'),
  extreme('Extrême (Z5-Z6 PMA & Punch)');

  final String label;
  const WorkoutIntensity(this.label);
}

/// Modèle de segment unitaire d'une séance d'entraînement structurée.
class WorkoutSegment {
  final String name;
  final int durationSeconds;
  final double ftpFactor;
  final int targetCadenceRpm;
  final String coachAdvice;

  const WorkoutSegment({
    required this.name,
    required this.durationSeconds,
    required this.ftpFactor,
    required this.targetCadenceRpm,
    required this.coachAdvice,
  });

  int targetWattsForFtp(int userFtp) {
    return (userFtp * ftpFactor).round().clamp(50, 450);
  }

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
  final String category; // Nom du Plan multi-semaines
  final String goalObjective; // Objectif physiologique
  final WorkoutIntensity intensity;
  final List<WorkoutSegment> segments;

  const WorkoutPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.goalObjective = 'Progression Globale',
    this.intensity = WorkoutIntensity.moderate,
    required this.segments,
  });

  int get totalDurationSeconds =>
      segments.fold(0, (sum, item) => sum + item.durationSeconds);

  String get formattedTotalDuration {
    final mins = (totalDurationSeconds / 60).round();
    return "$mins min";
  }
}

/// Catalogue officiel des Plans et Séances structurées conçues par Coach Stravos.
class WorkoutCatalog {
  static const List<WorkoutPlan> workouts = [
    // 1. SÉANCE DE VALIDATION RAPIDE (5 MINUTES)
    WorkoutPlan(
      id: 'express_erg_test',
      title: 'Test Express ERG (5 min)',
      subtitle: 'Blocs courts de 45s à 60s pour sentir les paliers automatiques du Zwift Hub One.',
      category: 'PLAN DÉCOUVERTE',
      goalObjective: 'Calibration Matérielle & Échauffement',
      intensity: WorkoutIntensity.moderate,
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

    // 2. SWEET SPOT & SEUIL (PLAN BOOSTER SA FTP)
    WorkoutPlan(
      id: 'sweet_spot_builder',
      title: 'Sweet Spot & Seuil (24 min)',
      subtitle: '3 répétitions à 90-96% FTP pour élever votre seuil lactique avec un coût de fatigue maîtrisé.',
      category: 'PLAN BOOSTER SA FTP',
      goalObjective: 'Augmenter la Puissance au Seuil (+15W FTP)',
      intensity: WorkoutIntensity.intense,
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

    // 3. OVER-UNDERS LACTATE SHUTTLE (PLAN BOOSTER SA FTP)
    WorkoutPlan(
      id: 'over_unders_lactate',
      title: 'Over-Unders Recyclage Lactique (20 min)',
      subtitle: 'Alternance de 2 min sous le seuil (90%) et 1 min au-dessus (108%) pour apprendre à récupérer dans l\'effort.',
      category: 'PLAN BOOSTER SA FTP',
      goalObjective: 'Tolérance aux changements de rythme en course',
      intensity: WorkoutIntensity.intense,
      segments: [
        WorkoutSegment(name: 'Échauffement Progressif', durationSeconds: 180, ftpFactor: 0.60, targetCadenceRpm: 88, coachAdvice: 'Coach Stravos : Préparez vos jambes à encaisser les variations de rythme.'),
        WorkoutSegment(name: 'Under #1 (90% FTP)', durationSeconds: 120, ftpFactor: 0.90, targetCadenceRpm: 88, coachAdvice: 'Coach Stravos : Installez-vous au Sweet Spot à 88 RPM.'),
        WorkoutSegment(name: 'Over #1 (108% FTP)', durationSeconds: 60, ftpFactor: 1.08, targetCadenceRpm: 96, coachAdvice: 'Coach Stravos : Accélération au-dessus du seuil ! Simulez la réponse à une attaque !'),
        WorkoutSegment(name: 'Under #2 (88% FTP - Recyclage)', durationSeconds: 120, ftpFactor: 0.88, targetCadenceRpm: 88, coachAdvice: 'Coach Stravos : Ne coupez pas l\'effort ! Éliminez les lactates tout en restant à 88% FTP.'),
        WorkoutSegment(name: 'Over #2 (110% FTP)', durationSeconds: 60, ftpFactor: 1.10, targetCadenceRpm: 96, coachAdvice: 'Coach Stravos : Deuxième relance ! Gardez le buste immobile.'),
        WorkoutSegment(name: 'Récupération Active', durationSeconds: 120, ftpFactor: 0.50, targetCadenceRpm: 80, coachAdvice: 'Coach Stravos : Soufflez 2 minutes avant le bloc final.'),
        WorkoutSegment(name: 'Under #3 (90% FTP)', durationSeconds: 120, ftpFactor: 0.90, targetCadenceRpm: 90, coachAdvice: 'Coach Stravos : Dernière rampe sous le seuil.'),
        WorkoutSegment(name: 'Over Final (112% FTP)', durationSeconds: 60, ftpFactor: 1.12, targetCadenceRpm: 98, coachAdvice: 'Coach Stravos : Basculez au sommet du col en puissance !'),
        WorkoutSegment(name: 'Retour au calme', durationSeconds: 180, ftpFactor: 0.48, targetCadenceRpm: 80, coachAdvice: 'Coach Stravos : Travail de clairance lactique terminé. Bravo !'),
      ],
    ),

    // 4. FORCE SOUS-MAXIMALE GRIMPEUR (PLAN ROI DE LA MONTAGNE)
    WorkoutPlan(
      id: 'mountain_torque_climber',
      title: 'Force Spécifique Grimpeur 65 RPM (22 min)',
      subtitle: 'Travail de couple musculaire à basse cadence (60-65 RPM) idéal sur les pentes du Ventoux ou du Galibier.',
      category: 'PLAN ROI DE LA MONTAGNE',
      goalObjective: 'Puissance musculaire en col raide (> 8%)',
      intensity: WorkoutIntensity.moderate,
      segments: [
        WorkoutSegment(name: 'Échauffement Véloce', durationSeconds: 180, ftpFactor: 0.58, targetCadenceRpm: 92, coachAdvice: 'Coach Stravos : Échauffez bien les articulations des genoux à 92 RPM.'),
        WorkoutSegment(name: 'Bloc Force #1 (65 RPM)', durationSeconds: 240, ftpFactor: 0.84, targetCadenceRpm: 65, coachAdvice: 'Coach Stravos : Baissez volontairement la cadence à 65 RPM. Le Zwift Hub va durcir le couple : poussez et tirez sur les pédales !'),
        WorkoutSegment(name: 'Transfert Vélocité (95 RPM)', durationSeconds: 120, ftpFactor: 0.70, targetCadenceRpm: 95, coachAdvice: 'Coach Stravos : Débloquez immédiatement les fibres à 95 RPM !'),
        WorkoutSegment(name: 'Bloc Force #2 (60 RPM)', durationSeconds: 240, ftpFactor: 0.88, targetCadenceRpm: 60, coachAdvice: 'Coach Stravos : Deuxième montée en force pure à 60 RPM. Gainage lombaire verrouillé.'),
        WorkoutSegment(name: 'Transfert Final Haute Cadence', durationSeconds: 120, ftpFactor: 0.95, targetCadenceRpm: 98, coachAdvice: 'Coach Stravos : Transférez la force en vitesse pure au seuil !'),
        WorkoutSegment(name: 'Retour au calme', durationSeconds: 180, ftpFactor: 0.48, targetCadenceRpm: 85, coachAdvice: 'Coach Stravos : Vos quadriceps sont prêts pour les grands cols.'),
      ],
    ),

    // 5. PUNCHEUR ARDENNAIS & FLANDRIEN (MUR DE HUY / QUAREMONT)
    WorkoutPlan(
      id: 'puncheur_ardennais_classic',
      title: 'Explosivité Puncheur — Mur de Huy & Flandres (18 min)',
      subtitle: 'Attaques tranchantes de 45s à 125-135% FTP pour faire la différence dans La Roche-aux-Faucons ou le Quaremont.',
      category: 'PLAN CLASSIQUES & MONUMENTS',
      goalObjective: 'Capacité anaérobie & Attaques en bosse (1 à 2 min)',
      intensity: WorkoutIntensity.extreme,
      segments: [
        WorkoutSegment(name: 'Approche nerveuse du pied de côte', durationSeconds: 180, ftpFactor: 0.65, targetCadenceRpm: 90, coachAdvice: 'Coach Stravos : Placement en tête de peloton avant le pied du Mur.'),
        WorkoutSegment(name: 'Attaque Côte #1 (125% FTP)', durationSeconds: 45, ftpFactor: 1.25, targetCadenceRpm: 98, coachAdvice: 'Coach Stravos : ATTAQUE FRANCHE ! 45 secondes à 125% FTP !'),
        WorkoutSegment(name: 'Récupération Active', durationSeconds: 90, ftpFactor: 0.50, targetCadenceRpm: 80, coachAdvice: 'Coach Stravos : Récupérez dans les roues.'),
        WorkoutSegment(name: 'Attaque Pavés Quaremont #2 (130% FTP)', durationSeconds: 45, ftpFactor: 1.30, targetCadenceRpm: 95, coachAdvice: 'Coach Stravos : Écrasez les pavés ! 130% FTP sans faiblir !'),
        WorkoutSegment(name: 'Récupération Active', durationSeconds: 90, ftpFactor: 0.50, targetCadenceRpm: 80, coachAdvice: 'Coach Stravos : Calmez la respiration avant La Redoute.'),
        WorkoutSegment(name: 'Attaque La Redoute #3 (130% FTP)', durationSeconds: 60, ftpFactor: 1.30, targetCadenceRpm: 96, coachAdvice: 'Coach Stravos : 1 minute pleine à 130% FTP pour lâcher tout le monde !'),
        WorkoutSegment(name: 'Récupération Active', durationSeconds: 90, ftpFactor: 0.50, targetCadenceRpm: 80, coachAdvice: 'Coach Stravos : Plus qu\'une seule rampe au sommet du Mur de Huy !'),
        WorkoutSegment(name: 'Finish Mur de Huy 19% (138% FTP)', durationSeconds: 45, ftpFactor: 1.38, targetCadenceRpm: 100, coachAdvice: 'Coach Stravos : SPRINT AU SOMMET DU MUR DE HUY !'),
        WorkoutSegment(name: 'Retour au calme', durationSeconds: 180, ftpFactor: 0.45, targetCadenceRpm: 80, coachAdvice: 'Coach Stravos : Digne d\'un vainqueur de Monument ardennais !'),
      ],
    ),

    // 6. PYRAMIDE PMA VO2MAX
    WorkoutPlan(
      id: 'pma_pyramid_vo2',
      title: 'Pyramide PMA VO2max (18 min)',
      subtitle: 'Intervalles intenses en Zone 5 (110% à 120% FTP) pour développer votre cylindrée aérobie.',
      category: 'PLAN VO2MAX & PMA',
      goalObjective: 'Développement du débit cardiaque maximal (VO2max)',
      intensity: WorkoutIntensity.extreme,
      segments: [
        WorkoutSegment(name: 'Échauffement Progressif', durationSeconds: 180, ftpFactor: 0.60, targetCadenceRpm: 88, coachAdvice: 'Coach Stravos : Échauffement essentiel avant de solliciter le système cardiovasculaire.'),
        WorkoutSegment(name: 'Déblocage Seuil', durationSeconds: 60, ftpFactor: 0.95, targetCadenceRpm: 95, coachAdvice: 'Coach Stravos : 1 minute de mise sous tension avant l\'attaque de la pyramide.'),
        WorkoutSegment(name: 'Récupération Pré-Série', durationSeconds: 60, ftpFactor: 0.50, targetCadenceRpm: 80, coachAdvice: 'Coach Stravos : Respirez calmement, départ de la pyramide dans quelques secondes.'),
        WorkoutSegment(name: 'PMA 1 min (112% FTP)', durationSeconds: 60, ftpFactor: 1.12, targetCadenceRpm: 96, coachAdvice: 'Coach Stravos : Premier échelon de la pyramide. Cadence vive !'),
        WorkoutSegment(name: 'Récupération Active', durationSeconds: 60, ftpFactor: 0.50, targetCadenceRpm: 82, coachAdvice: 'Coach Stravos : Récupération 1:1. Faites redescendre les pulsations.'),
        WorkoutSegment(name: 'Sommet PMA 90s (115% FTP)', durationSeconds: 90, ftpFactor: 1.15, targetCadenceRpm: 95, coachAdvice: 'Coach Stravos : Cœur de séance ! Tenez le haut du pavé pendant 90 secondes.'),
        WorkoutSegment(name: 'Récupération Active', durationSeconds: 90, ftpFactor: 0.50, targetCadenceRpm: 80, coachAdvice: 'Coach Stravos : Le plus dur est derrière vous. Préparez le sprint final.'),
        WorkoutSegment(name: 'Finish Explosif 60s (120% FTP)', durationSeconds: 60, ftpFactor: 1.20, targetCadenceRpm: 100, coachAdvice: 'Coach Stravos : Donnez tout sur cette dernière minute à 120% FTP !'),
        WorkoutSegment(name: 'Retour au calme Z1', durationSeconds: 180, ftpFactor: 0.45, targetCadenceRpm: 80, coachAdvice: 'Coach Stravos : Excellente séance VO2max. Relâchement complet.'),
      ],
    ),

    // 7. RÉCUPÉRATION ACTIVE & VÉLOCITÉ Z1-Z2
    WorkoutPlan(
      id: 'active_recovery_spin',
      title: 'Récupération Active & Souplesse (15 min)',
      subtitle: 'Séance douce en Zone 1/2 à haute vélocité pour éliminer les toxines le lendemain d\'une étape difficile.',
      category: 'PLAN RÉCUPÉRATION',
      goalObjective: 'Régénération musculaire & Souplesse de pédalage',
      intensity: WorkoutIntensity.soft,
      segments: [
        WorkoutSegment(name: 'Mise en route très souple', durationSeconds: 180, ftpFactor: 0.48, targetCadenceRpm: 85, coachAdvice: 'Coach Stravos : Aucune tension dans les jambes, laissez tourner le pédalier.'),
        WorkoutSegment(name: 'Vélocité Fluide Z2 (95 RPM)', durationSeconds: 300, ftpFactor: 0.60, targetCadenceRpm: 95, coachAdvice: 'Coach Stravos : Cherchez un coup de pédale parfaitement fluide sans rebondir sur la selle.'),
        WorkoutSegment(name: 'Oxygénation Z1 (90 RPM)', durationSeconds: 240, ftpFactor: 0.52, targetCadenceRpm: 90, coachAdvice: 'Coach Stravos : Respiration nasale calme, favorisez le retour veineux.'),
        WorkoutSegment(name: 'Relâchement Final', durationSeconds: 180, ftpFactor: 0.45, targetCadenceRpm: 82, coachAdvice: 'Coach Stravos : Jambes fraîches et prêtes pour la prochaine étape du Grand Tour !'),
      ],
    ),
  ];
}

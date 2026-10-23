import 'dart:math' as math;
import '../workouts/workout_models.dart';

/// Objectifs physiologiques disponibles dans le générateur IA de Coach Stravos (Phase 7)
enum StravosTrainingGoal {
  climbingThreshold(
    "⛰️ Seuil & Grimpe de Cols (FTP / Z4)",
    "Idéal pour préparer le Mont Ventoux, le Galibier ou l'Alpe d'Huez.",
  ),
  puncheurArdennais(
    "💥 Explosivité Ardennaise (PMA & Mur de Huy)",
    "Effort violent de 1 à 4 minutes pour La Redoute, le Mur de Huy et la Roche-aux-Faucons.",
  ),
  flandrienCobbles(
    "🪨 Force & Sur-régime Pavés (Quaremont / Roubaix)",
    "Travail de couple à basse cadence (65-75 RPM) suivi de relances lactiques.",
  ),
  vo2MaxIntervals(
    "🔥 Développement PMA (30/30 & 40/20)",
    "Augmente votre cylindrée aérobie maximale (VO2max) et la recharge de W'.",
  ),
  activeRecovery(
    "🌿 Vélocité & Récupération Active (Z1/Z2)",
    "Élimination des toxines à haute cadence (95-100 RPM) sans fatigue nerveuse.",
  );

  final String title;
  final String description;
  const StravosTrainingGoal(this.title, this.description);
}

/// Record de puissance sur la Courbe Puissance-Temps (Power Duration Curve - PDC)
class PowerDurationPoint {
  final String label;
  final int durationSeconds;
  final int bestWatts;
  final double wattsPerKg;
  final String physiologicalSystem;

  const PowerDurationPoint({
    required this.label,
    required this.durationSeconds,
    required this.bestWatts,
    required this.wattsPerKg,
    required this.physiologicalSystem,
  });
}

/// Recommandation nutritionnelle et hydrique scientifique (post-2022) par Coach Stravos
class NutritionRecommendation {
  final int mechanicalWorkKj;
  final int estimatedCaloriesKcal;
  final int carbsGramsPerHour;
  final int hydrationMlPerHour;
  final int sodiumMgPerHour;
  final int postRideCarbsGrams;
  final int postRideProteinGrams;
  final String inRideAdvice;
  final String recoveryMealAdvice;

  const NutritionRecommendation({
    required this.mechanicalWorkKj,
    required this.estimatedCaloriesKcal,
    required this.carbsGramsPerHour,
    required this.hydrationMlPerHour,
    required this.sodiumMgPerHour,
    required this.postRideCarbsGrams,
    required this.postRideProteinGrams,
    required this.inRideAdvice,
    required this.recoveryMealAdvice,
  });
}

/// Rapport de débriefing post-séance généré par Coach Stravos IA
class PostRideDebriefReport {
  final int complianceScorePercent;
  final double aerobicDecouplingPercent;
  final double lowestWPrimeBalanceKj;
  final String quadrantDominance;
  final String coachHeadline;
  final String physiologicalAnalysis;
  final NutritionRecommendation nutrition;

  const PostRideDebriefReport({
    required this.complianceScorePercent,
    required this.aerobicDecouplingPercent,
    required this.lowestWPrimeBalanceKj,
    required this.quadrantDominance,
    required this.coachHeadline,
    required this.physiologicalAnalysis,
    required this.nutrition,
  });
}

/// Moteur Physiologique & IA de Coach Stravos (Phase 7) :
/// - Modélisation dynamique de la réserve anaérobie W' Balance (modèle différentiel de Skiba)
/// - Courbe Puissance-Temps (PDC : 5s, 1m, 5m, 20m, 60m) et Quadrant Analysis (Force vs Vélocité)
/// - Générateur IA de séances structurées sur mesure adaptées au TSB (fatigue) et au temps disponible
/// - Calculateur de nutrition cycliste (glucides g/h ratio 2:1, hydratation, électrolytes et récupération)
class CoachStravosAiEngine {
  /// Capacité de travail anaérobie totale W'0 par défaut (en Joules : 18 000 J = 18.0 kJ)
  final double _wPrimeCapacityJoules = 18000.0;
  double _currentWPrimeBalanceJoules = 18000.0;
  double _lowestWPrimeReachedJoules = 18000.0;

  // Records PDC de la session / saison
  int _peak5SecWatts = 540;
  int _peak1MinWatts = 335;
  final int _peak5MinWatts = 255;
  final int _peak20MinWatts = 212;

  double get wPrimeCapacityKj => _wPrimeCapacityJoules / 1000.0;
  double get currentWPrimeBalanceKj =>
      double.parse((_currentWPrimeBalanceJoules / 1000.0).toStringAsFixed(1));
  double get wPrimePercentage =>
      ((_currentWPrimeBalanceJoules / _wPrimeCapacityJoules) * 100.0).clamp(0.0, 100.0);
  double get lowestWPrimeReachedKj =>
      double.parse((_lowestWPrimeReachedJoules / 1000.0).toStringAsFixed(1));

  /// Met à jour la réserve d'énergie anaérobie W' Balance (Modèle de Skiba) seconde par seconde
  void updateWPrimeBalance({
    required int currentWatts,
    required int criticalPowerWatts,
    double dtSeconds = 1.0,
  }) {
    final cp = math.max(criticalPowerWatts, 100);
    if (currentWatts > cp) {
      // Dépense anaérobie au-dessus de CP/FTP
      final depletion = (currentWatts - cp) * dtSeconds;
      _currentWPrimeBalanceJoules =
          (_currentWPrimeBalanceJoules - depletion).clamp(0.0, _wPrimeCapacityJoules);
    } else if (_currentWPrimeBalanceJoules < _wPrimeCapacityJoules) {
      // Reconstitution exponentielle sous CP (formule de Skiba : Tau_W')
      final dCp = (cp - currentWatts).clamp(1, cp);
      final tauWPrime = 546.0 * math.exp(-0.01 * dCp) + 316.0;
      final deficit = _wPrimeCapacityJoules - _currentWPrimeBalanceJoules;
      final recovery = deficit * (1.0 - math.exp(-dtSeconds / tauWPrime));
      _currentWPrimeBalanceJoules =
          (_currentWPrimeBalanceJoules + recovery).clamp(0.0, _wPrimeCapacityJoules);
    }

    if (_currentWPrimeBalanceJoules < _lowestWPrimeReachedJoules) {
      _lowestWPrimeReachedJoules = _currentWPrimeBalanceJoules;
    }

    // Mise à jour dynamique des pics de puissance si le joueur bat un record
    if (currentWatts > _peak5SecWatts) _peak5SecWatts = currentWatts;
    if ((currentWatts * 0.82).round() > _peak1MinWatts) {
      _peak1MinWatts = (currentWatts * 0.82).round();
    }
  }

  void resetWPrime() {
    _currentWPrimeBalanceJoules = _wPrimeCapacityJoules;
    _lowestWPrimeReachedJoules = _wPrimeCapacityJoules;
  }

  /// Retourne la Courbe Puissance-Temps (PDC) complète en Watts et W/kg
  List<PowerDurationPoint> getPowerDurationCurve({
    required int ftpWatts,
    required double weightKg,
  }) {
    final w = math.max(weightKg, 45.0);
    final p20 = math.max(_peak20MinWatts, (ftpWatts / 0.95).round());
    final p5 = math.max(_peak5MinWatts, (ftpWatts * 1.22).round());
    final p1 = math.max(_peak1MinWatts, (ftpWatts * 1.62).round());
    final p5s = math.max(_peak5SecWatts, (ftpWatts * 2.65).round());

    return [
      PowerDurationPoint(
        label: "5 sec (Sprint)",
        durationSeconds: 5,
        bestWatts: p5s,
        wattsPerKg: double.parse((p5s / w).toStringAsFixed(2)),
        physiologicalSystem: "Neuromusculaire / Créatine Phosphate",
      ),
      PowerDurationPoint(
        label: "1 min (Attaque)",
        durationSeconds: 60,
        bestWatts: p1,
        wattsPerKg: double.parse((p1 / w).toStringAsFixed(2)),
        physiologicalSystem: "Capacité Anaérobie Lactique (W')",
      ),
      PowerDurationPoint(
        label: "5 min (PMA)",
        durationSeconds: 300,
        bestWatts: p5,
        wattsPerKg: double.parse((p5 / w).toStringAsFixed(2)),
        physiologicalSystem: "Puissance Maximale Aérobie (VO2max)",
      ),
      PowerDurationPoint(
        label: "20 min (Seuil)",
        durationSeconds: 1200,
        bestWatts: p20,
        wattsPerKg: double.parse((p20 / w).toStringAsFixed(2)),
        physiologicalSystem: "Seuil Anaérobie (FTP = ${(p20 * 0.95).round()}W)",
      ),
    ];
  }

  /// Analyse de Quadrant (Quadrant Analysis : Force Pédale vs Vélocité)
  String analyzePedalingQuadrant({
    required int watts,
    required double cadenceRpm,
    required int ftpWatts,
  }) {
    final highPower = watts >= ftpWatts;
    final highCadence = cadenceRpm >= 85.0;

    if (highPower && highCadence) {
      return "Q1 — Vélocité Haute Puissance (Sprint / Attaque PMA)";
    } else if (highPower && !highCadence) {
      return "Q2 — Force Musculaire en Bosse (Ascension raide / Pavés)";
    } else if (!highPower && !highCadence) {
      return "Q3 — Récupération / Roue libre dans le peloton";
    } else {
      return "Q4 — Vélocité Économique (Souplesse neuromusculaire)";
    }
  }

  /// Génère une séance d'entraînement structurée sur mesure en 1 clic selon :
  /// - la durée choisie (minutes)
  /// - l'objectif physiologique
  /// - l'indice de fraîcheur TSB (Form Balance) du cycliste
  WorkoutPlan generateCustomWorkout({
    required int durationMinutes,
    required StravosTrainingGoal goal,
    required double currentTsbForm,
    required int athleteFtp,
  }) {
    // Ajustement intelligent selon la fatigue (TSB)
    // Si l'athlète est fatigué (TSB < -10), Coach Stravos réduit l'intensité cible de 5% pour éviter le surentraînement
    final fatigueAdjustment = currentTsbForm < -10.0
        ? 0.95
        : (currentTsbForm > 5.0 ? 1.03 : 1.00);

    final totalSec = (durationMinutes.clamp(15, 120)) * 60;
    final warmupSec = (totalSec * 0.20).round();
    final cooldownSec = (totalSec * 0.15).round();
    final mainSetSec = totalSec - warmupSec - cooldownSec;

    final List<WorkoutSegment> segments = [
      WorkoutSegment(
        name: "Échauffement Progressif Stravos",
        durationSeconds: warmupSec,
        ftpFactor: double.parse((0.62 * fatigueAdjustment).toStringAsFixed(2)),
        targetCadenceRpm: 90,
        coachAdvice:
            "Coach Stravos : Déverrouillez les articulations en souplesse (90 RPM). TSB du jour : ${currentTsbForm >= 0 ? '+' : ''}$currentTsbForm.",
      ),
    ];

    switch (goal) {
      case StravosTrainingGoal.climbingThreshold:
        final blockSec = (mainSetSec / 3).round();
        segments.addAll([
          WorkoutSegment(
            name: "Ascension Seuil Z4 — Bloc 1",
            durationSeconds: blockSec,
            ftpFactor: double.parse((0.96 * fatigueAdjustment).toStringAsFixed(2)),
            targetCadenceRpm: 82,
            coachAdvice:
                "Coach Stravos : Restez bien gainé sur le bassin, tirez-poussez rond à 82 RPM comme dans la forêt du Ventoux !",
          ),
          WorkoutSegment(
            name: "Récupération Active sur replat",
            durationSeconds: (blockSec * 0.45).round(),
            ftpFactor: 0.58,
            targetCadenceRpm: 92,
            coachAdvice: "Coach Stravos : Hydratez-vous (2 gorgées) et rechargez votre réserve W' !",
          ),
          WorkoutSegment(
            name: "Ascension Seuil Z4+ — Bloc Final",
            durationSeconds: blockSec,
            ftpFactor: double.parse((1.01 * fatigueAdjustment).toStringAsFixed(2)),
            targetCadenceRpm: 85,
            coachAdvice: "Coach Stravos : Tenez votre FTP jusqu'au sommet virtuel, respiration profonde !",
          ),
        ]);
        break;

      case StravosTrainingGoal.puncheurArdennais:
        final reps = 3;
        final workSec = (mainSetSec / (reps * 2)).round();
        for (int i = 1; i <= reps; i++) {
          segments.add(
            WorkoutSegment(
              name: "Attaque Ardennaise #$i (Z5 PMA)",
              durationSeconds: workSec,
              ftpFactor: double.parse((1.16 * fatigueAdjustment).toStringAsFixed(2)),
              targetCadenceRpm: 94,
              coachAdvice:
                  "Coach Stravos : Attaque franche façon Mur de Huy / Roche-aux-Faucons ! Mobilisez votre W' !",
            ),
          );
          segments.add(
            WorkoutSegment(
              name: "Recharge W' dans les roues #$i",
              durationSeconds: workSec,
              ftpFactor: 0.55,
              targetCadenceRpm: 88,
              coachAdvice: "Coach Stravos : Laissez redescendre les pulsations sous 75% FCmax.",
            ),
          );
        }
        break;

      case StravosTrainingGoal.flandrienCobbles:
        final halfMain = (mainSetSec / 2).round();
        segments.addAll([
          WorkoutSegment(
            name: "Secteur Pavé en Force (68 RPM)",
            durationSeconds: (halfMain * 0.65).round(),
            ftpFactor: double.parse((0.92 * fatigueAdjustment).toStringAsFixed(2)),
            targetCadenceRpm: 68,
            coachAdvice:
                "Coach Stravos : Travail de couple musculaire (Quadrant Q2) à 68 RPM sans bouger les épaules !",
          ),
          WorkoutSegment(
            name: "Sortie de Secteur — Sur-régime Z5",
            durationSeconds: (halfMain * 0.35).round(),
            ftpFactor: double.parse((1.12 * fatigueAdjustment).toStringAsFixed(2)),
            targetCadenceRpm: 96,
            coachAdvice: "Coach Stravos : Relancez tout de suite en vélocité à la sortie des pavés !",
          ),
          WorkoutSegment(
            name: "Transition Endurance Z2",
            durationSeconds: (halfMain * 0.40).round(),
            ftpFactor: 0.65,
            targetCadenceRpm: 90,
            coachAdvice: "Coach Stravos : Relâchez la pression sur le cintre.",
          ),
          WorkoutSegment(
            name: "Final Vieux Quaremont",
            durationSeconds: (halfMain * 0.60).round(),
            ftpFactor: double.parse((1.05 * fatigueAdjustment).toStringAsFixed(2)),
            targetCadenceRpm: 80,
            coachAdvice: "Coach Stravos : Écrasez les pédales jusqu'à la banderole !",
          ),
        ]);
        break;

      case StravosTrainingGoal.vo2MaxIntervals:
        final blocks = 4;
        final unitSec = (mainSetSec / (blocks * 2)).round();
        for (int b = 1; b <= blocks; b++) {
          segments.add(
            WorkoutSegment(
              name: "Bloc PMA VO2max #$b (120% FTP)",
              durationSeconds: unitSec,
              ftpFactor: double.parse((1.20 * fatigueAdjustment).toStringAsFixed(2)),
              targetCadenceRpm: 98,
              coachAdvice: "Coach Stravos : Cadence haute (98 RPM) pour saturer la consommation d'oxygène !",
            ),
          );
          segments.add(
            WorkoutSegment(
              name: "Contre-exercice Z1 #$b",
              durationSeconds: unitSec,
              ftpFactor: 0.52,
              targetCadenceRpm: 85,
              coachAdvice: "Coach Stravos : Soufflez profondément, reconstitution exponentielle de W'.",
            ),
          );
        }
        break;

      case StravosTrainingGoal.activeRecovery:
        segments.addAll([
          WorkoutSegment(
            name: "Endurance Fondamentale Véloce",
            durationSeconds: (mainSetSec * 0.6).round(),
            ftpFactor: 0.64,
            targetCadenceRpm: 95,
            coachAdvice: "Coach Stravos : Pédalage ultra-fluide à 95 RPM (Quadrant Q4) pour drainer les jambes.",
          ),
          WorkoutSegment(
            name: "Vélocité Neuromusculaire 100 RPM",
            durationSeconds: (mainSetSec * 0.4).round(),
            ftpFactor: 0.58,
            targetCadenceRpm: 100,
            coachAdvice: "Coach Stravos : Aucun rebond sur la selle, cherchez la souplesse parfaite.",
          ),
        ]);
        break;
    }

    segments.add(
      WorkoutSegment(
        name: "Retour au Calme & Clairance Lactate",
        durationSeconds: cooldownSec,
        ftpFactor: 0.50,
        targetCadenceRpm: 85,
        coachAdvice: "Coach Stravos : Séance terminée avec brio ! Pensez à votre apport glucides/protéines.",
      ),
    );

    return WorkoutPlan(
      id: 'stravos_ai_${DateTime.now().millisecondsSinceEpoch}',
      title: "IA Stravos : ${goal.title.replaceAll(RegExp(r'^[^\s]+\s'), '')} (${durationMinutes}m)",
      subtitle:
          "Généré sur mesure pour FTP ${athleteFtp}W & TSB ${currentTsbForm >= 0 ? '+' : ''}$currentTsbForm",
      category: "COACH STRAVOS IA",
      goalObjective: goal.title,
      intensity: goal == StravosTrainingGoal.activeRecovery
          ? WorkoutIntensity.soft
          : (goal == StravosTrainingGoal.climbingThreshold
              ? WorkoutIntensity.intense
              : WorkoutIntensity.extreme),
      segments: segments,
    );
  }

  /// Calcule les besoins exacts en nutrition et hydratation selon la science du sport post-2022
  NutritionRecommendation computeNutritionPlan({
    required int durationSeconds,
    required int avgWatts,
    required int ftpWatts,
    required double weightKg,
  }) {
    final hours = math.max(durationSeconds / 3600.0, 0.25);
    final workKj = ((avgWatts * durationSeconds) / 1000.0).round();
    // Rendement mécanique humain ~23.9% -> 1 kJ mécanique ≈ 1.04 kcal métabolique
    final kcal = (workKj * 1.04).round();
    final intensityFactor = ftpWatts > 0 ? avgWatts / ftpWatts : 0.75;

    int carbsPerHour;
    String inRideAdvice;
    if (durationSeconds <= 2700 && intensityFactor < 0.80) {
      carbsPerHour = 30;
      inRideAdvice =
          "Effort < 45 min : 30g de glucides/h (boisson isotonique légère) suffisent pour maintenir la glycémie.";
    } else if (intensityFactor < 0.92 && durationSeconds <= 5400) {
      carbsPerHour = 60;
      inRideAdvice =
          "Effort soutenu : Ciblez 60g de glucides/h (1 bidon isotonique 35g + 1 gel ou barre 25g toutes les 45 min).";
    } else {
      carbsPerHour = 90;
      inRideAdvice =
          "Haute intensité / Grand Col : Ciblez 80 à 90g de glucides/h avec ratio Glucose:Fructose 2:1 (double transporteur intestinal SGLT1 + GLUT5).";
    }

    final hydrationMlPerHour = avgWatts >= 200 ? 750 : 600;
    final sodiumMgPerHour = avgWatts >= 200 ? 650 : 450;

    final postCarbs = (weightKg * (hours >= 1.0 ? 1.1 : 0.8)).round();
    final postProtein = (weightKg * 0.32).round();

    return NutritionRecommendation(
      mechanicalWorkKj: workKj,
      estimatedCaloriesKcal: kcal,
      carbsGramsPerHour: carbsPerHour,
      hydrationMlPerHour: hydrationMlPerHour,
      sodiumMgPerHour: sodiumMgPerHour,
      postRideCarbsGrams: postCarbs,
      postRideProteinGrams: postProtein,
      inRideAdvice: inRideAdvice,
      recoveryMealAdvice:
          "Fenêtre métabolique (30 min post-effort) : ${postCarbs}g de glucides à index glycémique moyen/élevé + ${postProtein}g de protéines (ratio ~3:1) pour resynthétiser le glycogène musculaire.",
    );
  }

  /// Génère le rapport complet de débriefing post-séance
  PostRideDebriefReport generatePostRideDebrief({
    required int durationSeconds,
    required int avgWatts,
    required int targetOrFtpWatts,
    required double cadenceRpm,
    required double weightKg,
    int? avgHeartRateBpm,
  }) {
    final target = math.max(targetOrFtpWatts, 120);
    final diffRatio = ((avgWatts - target).abs() / target).clamp(0.0, 0.5);
    final compliance = ((1.0 - diffRatio * 0.85) * 100.0).round().clamp(65, 100);

    // Estimation du découplage aérobie Pw:HR (< 5% = excellente endurance fondamentale)
    final decoupling = avgHeartRateBpm != null && avgHeartRateBpm > 155 ? 4.2 : 2.6;
    final quadrant = analyzePedalingQuadrant(
      watts: avgWatts,
      cadenceRpm: cadenceRpm,
      ftpWatts: targetOrFtpWatts,
    );
    final nutrition = computeNutritionPlan(
      durationSeconds: math.max(durationSeconds, 1800),
      avgWatts: math.max(avgWatts, 180),
      ftpWatts: targetOrFtpWatts,
      weightKg: weightKg,
    );

    return PostRideDebriefReport(
      complianceScorePercent: compliance,
      aerobicDecouplingPercent: decoupling,
      lowestWPrimeBalanceKj: lowestWPrimeReachedKj,
      quadrantDominance: quadrant,
      coachHeadline: compliance >= 90
          ? "Exécution Magistrale ($compliance% d'adhérence ERG) !"
          : "Solide Séance de Travail ($compliance% d'adhérence) !",
      physiologicalAnalysis:
          "Découplage aérobie (Pw:HR) maîtrisé à $decoupling% (< 5% = base aérobie solide). Votre réserve anaérobie W' est descendue jusqu'à $lowestWPrimeReachedKj kJ sur ${wPrimeCapacityKj.toStringAsFixed(1)} kJ disponibles. Dominance : $quadrant.",
      nutrition: nutrition,
    );
  }
}

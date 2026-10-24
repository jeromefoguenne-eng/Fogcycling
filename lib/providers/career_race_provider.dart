import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../core/career/races_and_peloton_models.dart';
import '../core/routes/mythical_routes.dart';
import '../core/strava/strava_exporter.dart';
import 'ble_sensor_provider.dart';

/// Contrôleur central de la Phase 4 :
/// - Sélection libre du Lieu / Col Mythique (12 parcours réels)
/// - Courses par étapes (Grands Tours) et Classiques (~1h)
/// - Peloton IA réglable sur 10 niveaux (170W à 260W)
/// - Équipiers IA, Stratégie d'avant-course et Ordres Radio en direct
/// - Moteur physique d'Aspiration (Drafting -0% à -40% de vent)
/// - Classements Maillot Jaune, Maillot à Pois (GPM) et Maillot Vert (Sprint)
/// - Enregistrement GPS réel et Export Strava (.TCX Garmin enrichi)
class CareerRaceProvider extends ChangeNotifier {
  // ─── 1. LIEU / PARCOURS SÉLECTIONNÉ ────────────────────────────────────────
  MythicalRoute _activeRoute = MythicalRoutesCatalog.routes.first; // Mont Ventoux par défaut
  double _lastAppliedSlope = -999.0;

  // ─── 2. ÉPREUVE EN COURS (SORTIE LIBRE, GRAND TOUR OU CLASSIQUE) ───────────
  CyclingCompetition? _activeCompetition;
  int _activeStageIndex = 0;
  bool _isRaceActive = false;

  // ─── 3. PARAMÈTRES IA (10 NIVEAUX : 170W -> 260W) & STRATÉGIE D'ÉQUIPE ─────
  AiDifficultyLevel _aiLevel = AiDifficultyLevel.allLevels[3]; // Niveau 4 = 200W par défaut
  TeamStrategy _teamStrategy = TeamStrategy.protectLeader;
  TeammateRadioOrder _activeRadioOrder = TeammateRadioOrder.shelterLeader;
  PelotonPositionTactic _positionTactic = PelotonPositionTactic.stayInPack;

  // ─── 4. PELOTON DE 150 COUREURS (1 JOUEUR + 3 ÉQUIPIERS + 146 ADVERSAIRES) ──
  final List<PelotonRider> _peloton = [];
  double _playerDistanceMeters = 0.0;
  int _playerGcTimeSeconds = 0;
  int _playerKomPoints = 0;
  int _playerSprintPoints = 0;
  bool _isBoxedInPack = false;

  // Franchissement des banderoles sur l'étape en cours
  bool _sprintBannerCrossed = false;
  bool _komBannerCrossed = false;
  String _raceRadioBannerMessage =
      "📻 Directeur Sportif : Vos 3 équipiers vous protègent du vent. Choisissez votre tactique !";

  // ─── 5. ASPIRATION (DRAFTING) ──────────────────────────────────────────────
  double _currentDraftSavingPercent = 0.0; // 0% à 40%
  String _draftStatusLabel = "💨 PLEIN VENT (0%)";

  // ─── 6. ENREGISTREUR STRAVA (.TCX) ─────────────────────────────────────────
  final List<StravaTrackpoint> _stravaTrackpoints = [];
  int _maxRecordedWatts = 0;

  CareerRaceProvider() {
    _initPeloton();
  }

  // Getters
  MythicalRoute get activeRoute => _activeRoute;
  CyclingCompetition? get activeCompetition => _activeCompetition;
  int get activeStageIndex => _activeStageIndex;
  RaceStage? get activeStage =>
      (_activeCompetition != null && _activeStageIndex < _activeCompetition!.stages.length)
          ? _activeCompetition!.stages[_activeStageIndex]
          : null;
  bool get isRaceActive => _isRaceActive;
  AiDifficultyLevel get aiLevel => _aiLevel;
  TeamStrategy get teamStrategy => _teamStrategy;
  TeammateRadioOrder get activeRadioOrder => _activeRadioOrder;
  PelotonPositionTactic get positionTactic => _positionTactic;
  bool get isBoxedInPack => _isBoxedInPack;
  List<PelotonRider> get peloton => List.unmodifiable(_peloton);
  List<PelotonRider> get teammates => _peloton.where((r) => r.isTeammate).toList();
  double get playerDistanceMeters => _playerDistanceMeters;
  int get playerGcTimeSeconds => _playerGcTimeSeconds;
  int get playerKomPoints => _playerKomPoints;
  int get playerSprintPoints => _playerSprintPoints;
  String get raceRadioBannerMessage => _raceRadioBannerMessage;
  double get currentDraftSavingPercent => _currentDraftSavingPercent;
  String get draftStatusLabel => _draftStatusLabel;
  List<StravaTrackpoint> get stravaTrackpoints => List.unmodifiable(_stravaTrackpoints);

  /// Nombre total de cyclistes dans le peloton (149 IA + 1 Joueur = 150 cyclistes)
  int get totalPelotonSize => _peloton.length + 1;

  /// Rang actuel du joueur sur la route (1er à 150e)
  int get playerLiveRankOnRoad {
    int ahead = _peloton.where((r) => r.distanceMeters > _playerDistanceMeters).length;
    return ahead + 1;
  }

  void _initPeloton() {
    _peloton.clear();
    // Vos 3 Équipiers dévoués (Team Fogcycling)
    _peloton.addAll([
      PelotonRider(
        id: 'tm_1',
        name: 'Lucas Vermeulen (Équipier)',
        countryFlag: '🇧🇪',
        teamName: 'Team Fogcycling',
        isTeammate: true,
        specialty: RiderSpecialty.puncheur,
        powerFactor: 1.02,
        distanceMeters: 2.2,
        lateralOffsetMeters: -0.4,
      ),
      PelotonRider(
        id: 'tm_2',
        name: 'Mateo Rossi (Grimpeur)',
        countryFlag: '🇮🇹',
        teamName: 'Team Fogcycling',
        isTeammate: true,
        specialty: RiderSpecialty.climber,
        powerFactor: 1.04,
        distanceMeters: 3.5,
        lateralOffsetMeters: 0.5,
      ),
      PelotonRider(
        id: 'tm_3',
        name: 'Thomas Lambert (Poisson-Pilote)',
        countryFlag: '🇫🇷',
        teamName: 'Team Fogcycling',
        isTeammate: true,
        specialty: RiderSpecialty.sprinter,
        powerFactor: 1.03,
        distanceMeters: 1.8,
        lateralOffsetMeters: 0.2,
      ),
      // 9 Leaders Rivaux IA (Grimpeurs, Sprinteurs, Flandriens, Baroudeurs)
      PelotonRider(
        id: 'ai_1',
        name: 'Tadej Kovac',
        countryFlag: '🇸🇮',
        teamName: 'UAE Virtuel',
        isTeammate: false,
        specialty: RiderSpecialty.climber,
        powerFactor: 1.06,
        distanceMeters: 18.0,
        lateralOffsetMeters: -0.8,
      ),
      PelotonRider(
        id: 'ai_2',
        name: 'Jonas Lindholm',
        countryFlag: '🇩🇰',
        teamName: 'Nordic Lease',
        isTeammate: false,
        specialty: RiderSpecialty.climber,
        powerFactor: 1.05,
        distanceMeters: 16.5,
        lateralOffsetMeters: 0.9,
      ),
      PelotonRider(
        id: 'ai_3',
        name: 'Remco De Wolf',
        countryFlag: '🇧🇪',
        teamName: 'Soudal Quick',
        isTeammate: false,
        specialty: RiderSpecialty.rouleur,
        powerFactor: 1.04,
        distanceMeters: 21.0,
        lateralOffsetMeters: -0.2,
      ),
      PelotonRider(
        id: 'ai_4',
        name: 'Wout Van Daele',
        countryFlag: '🇧🇪',
        teamName: 'Flanders Pro',
        isTeammate: false,
        specialty: RiderSpecialty.puncheur,
        powerFactor: 1.03,
        distanceMeters: 14.5,
        lateralOffsetMeters: 1.1,
      ),
      PelotonRider(
        id: 'ai_5',
        name: 'Mathieu Van Der Berg',
        countryFlag: '🇳🇱',
        teamName: 'Alpecin Aero',
        isTeammate: false,
        specialty: RiderSpecialty.puncheur,
        powerFactor: 1.04,
        distanceMeters: 19.0,
        lateralOffsetMeters: -1.1,
      ),
      PelotonRider(
        id: 'ai_6',
        name: 'Jasper Maes (Sprinteur)',
        countryFlag: '🇧🇪',
        teamName: 'Alpecin Aero',
        isTeammate: false,
        specialty: RiderSpecialty.sprinter,
        powerFactor: 0.98,
        distanceMeters: 9.0,
        lateralOffsetMeters: 0.7,
      ),
      PelotonRider(
        id: 'ai_7',
        name: 'Carlos Navarro',
        countryFlag: '🇪🇸',
        teamName: 'Iberia Movi',
        isTeammate: false,
        specialty: RiderSpecialty.climber,
        powerFactor: 1.01,
        distanceMeters: 32.0, // Baroudeur d'échappée
        lateralOffsetMeters: 0.0,
      ),
      PelotonRider(
        id: 'ai_8',
        name: 'Julian Allemand',
        countryFlag: '🇫🇷',
        teamName: 'Armorique',
        isTeammate: false,
        specialty: RiderSpecialty.puncheur,
        powerFactor: 0.99,
        distanceMeters: 34.0, // Baroudeur d'échappée
        lateralOffsetMeters: -0.6,
      ),
      PelotonRider(
        id: 'ai_9',
        name: 'Filippo Ganna-Rosa',
        countryFlag: '🇮🇹',
        teamName: 'Squadra Corsa',
        isTeammate: false,
        specialty: RiderSpecialty.rouleur,
        powerFactor: 1.00,
        distanceMeters: 11.5,
        lateralOffsetMeters: -0.9,
      ),
    ]);

    // Ajout de 137 coureurs de peloton WorldTour pour former un peloton massif de 150 cyclistes (1 joueur + 149 IA)
    const teams = [
      'UAE Virtuel',
      'Nordic Lease',
      'Soudal Quick',
      'Alpecin Aero',
      'Iberia Movi',
      'Squadra Corsa',
      'Armorique',
      'Bora Alpine',
      'Lidl Trekking',
      'Inéos Grenadier',
    ];
    const flags = ['🇧🇪', '🇫🇷', '🇮🇹', '🇪🇸', '🇳🇱', '🇩🇰', '🇸🇮', '🇩🇪', '🇬🇧', '🇨🇴'];
    const specialties = RiderSpecialty.values;

    for (int idx = 10; idx <= 146; idx++) {
      // Répartition spatiale réaliste : de +30m devant le joueur (tête de peloton) à -42m derrière (queue de peloton)
      // Le joueur démarre ainsi autour de la 55e place sur 150 au cœur du peloton !
      final normalizedRank = (idx - 10) / 136.0; // 0.0 -> 1.0
      final initialDist = 28.0 - (normalizedRank * 70.0);
      final laneCol = (idx % 5) - 2; // -2, -1, 0, 1, 2
      final latOffset = laneCol * 0.58;
      final factor = 0.93 + ((idx * 7) % 14) * 0.01; // 0.93 à 1.06

      _peloton.add(
        PelotonRider(
          id: 'ai_$idx',
          name: 'Coureur #${idx + 3} (${teams[idx % teams.length]})',
          countryFlag: flags[idx % flags.length],
          teamName: teams[idx % teams.length],
          isTeammate: false,
          specialty: specialties[idx % specialties.length],
          powerFactor: factor,
          distanceMeters: initialDist,
          lateralOffsetMeters: latOffset,
        ),
      );
    }
  }

  // ─── CHANGEMENT LIBRE DU LIEU / PARCOURS (POUR SORTIE LIBRE OU WORKOUT) ────
  void selectRoute(MythicalRoute route, BleSensorProvider ble, {bool resetProgress = true}) {
    _activeRoute = route;
    if (resetProgress) {
      _playerDistanceMeters = 0.0;
      _sprintBannerCrossed = false;
      _komBannerCrossed = false;
      _initPeloton();
    }
    final initialSlope = route.getSlopeAtDistance(_playerDistanceMeters);
    _lastAppliedSlope = initialSlope;
    ble.setSimulatedSlope(initialSlope);
    _raceRadioBannerMessage =
        "📍 Lieu sélectionné : ${route.countryFlag} ${route.name} (${route.distanceKm} km, moy ${route.avgSlopePercent}%, max ${route.maxSlopePercent}%)";
    notifyListeners();
  }

  // ─── CONFIGURATION NIVEAU IA (1 à 10 : 170W à 260W) & STRATÉGIE D'ÉQUIPE ───
  void setAiDifficultyLevel(AiDifficultyLevel level) {
    _aiLevel = level;
    _raceRadioBannerMessage =
        "🤖 Niveau IA réglé sur Niveau ${level.level}/10 (${level.averageWatts} W de moyenne - ${level.title})";
    notifyListeners();
  }

  void setTeamStrategy(TeamStrategy strategy) {
    _teamStrategy = strategy;
    if (strategy == TeamStrategy.protectLeader) {
      _activeRadioOrder = TeammateRadioOrder.shelterLeader;
    } else if (strategy == TeamStrategy.mountainTrain || strategy == TeamStrategy.chaseBreakaway) {
      _activeRadioOrder = TeammateRadioOrder.pullPeloton;
    }
    _raceRadioBannerMessage = "📋 Stratégie de départ validée : ${strategy.title}";
    notifyListeners();
  }

  void sendRadioOrder(TeammateRadioOrder order) {
    _activeRadioOrder = order;
    _raceRadioBannerMessage = "📻 Ordre Radio envoyé aux équipiers : ${order.label} — ${order.tooltip}";
    notifyListeners();
  }

  void setPositionTactic(PelotonPositionTactic tactic) {
    _positionTactic = tactic;
    _raceRadioBannerMessage = "🚴 Placement Peloton (150 coureurs) : ${tactic.label} — ${tactic.description}";
    notifyListeners();
  }

  // ─── LANCEMENT D'UN GRAND TOUR OU D'UNE CLASSIQUE ──────────────────────────
  void startCompetitionStage(
    CyclingCompetition competition,
    int stageIndex,
    BleSensorProvider ble,
  ) {
    _activeCompetition = competition;
    _activeStageIndex = stageIndex.clamp(0, competition.stages.length - 1);
    _isRaceActive = true;

    final stage = competition.stages[_activeStageIndex];
    selectRoute(stage.route, ble, resetProgress: true);

    if (_teamStrategy == TeamStrategy.breakawayRelay) {
      // Envoyer un équipier 25m à l'avant dans l'échappée matinale
      _peloton.first.distanceMeters = 25.0;
    }

    _raceRadioBannerMessage =
        "🏁 DÉPART : ${competition.title} — ${stage.title} | Peloton 150 coureurs (IA ${aiLevel.averageWatts}W)";
    notifyListeners();
  }

  // ─── BOUCLE PHYSIQUE 1 HZ : ASPIRATION, PELOTON 150, PLACEMENT & STRAVA ────
  void tickSimulation({
    required int playerWatts,
    required double playerCadenceRpm,
    required double rawTrainerSpeedKmh,
    required int? heartRateBpm,
    required bool isErgWorkoutActive,
    required BleSensorProvider ble,
  }) {
    final currentSlope = _activeRoute.getSlopeAtDistance(_playerDistanceMeters);
    final baseAiWatts = _aiLevel.averageWatts.toDouble();

    // 1. Si on n'est PAS en mode ERG d'entraînement, ajuster automatiquement la pente du Zwift Hub !
    if (!isErgWorkoutActive && (currentSlope - _lastAppliedSlope).abs() >= 0.4) {
      _lastAppliedSlope = currentSlope;
      ble.setSimulatedSlope(currentSlope);
    }

    // 2. Calcul de l'Aspiration (Drafting) & Densité autour du joueur dans le Peloton de 150 coureurs
    int ridersCloselyAhead = 0;
    int ridersBoxingPlayer = 0;
    bool teammateDirectlyDrafting = false;

    for (final rider in _peloton) {
      final gap = rider.distanceMeters - _playerDistanceMeters;
      if (gap >= 0.8 && gap <= 12.0) {
        ridersCloselyAhead++;
        if (rider.isTeammate && gap <= 5.5) {
          teammateDirectlyDrafting = true;
        }
      }
      if (gap >= -2.0 && gap <= 4.8) {
        ridersBoxingPlayer++;
      }
    }

    // En montée raide (> 7.5%), la vitesse chute et l'effet d'abri aérodynamique diminue naturellement
    final aeroSlopeAttenuation = currentSlope > 7.5 ? 0.35 : (currentSlope > 4.5 ? 0.70 : 1.0);

    // Gestion tactique du placement dans le peloton de 150 cyclistes :
    // - Sur l'Aile (moveUpOnWing) : couloir extérieur dégagé (0 enfermement), mais seulement 12% d'abri du vent !
    // - Frotter Top 25 (holdTop25) : dépense modérée pour garder sa place devant (-28% vent).
    // - Cœur Peloton (stayInPack) : abri maximal (-40% vent), mais risque d'enfermement et recul naturel si on relâche.
    _isBoxedInPack = false;

    if (_positionTactic == PelotonPositionTactic.moveUpOnWing) {
      final wingDraft = ridersCloselyAhead >= 1 ? 12.0 : 0.0;
      _currentDraftSavingPercent = (wingDraft * aeroSlopeAttenuation).roundToDouble();
      _draftStatusLabel = "⚡ SUR L'AILE (-${_currentDraftSavingPercent.toInt()}% VENT • COULOIR LIBRE)";
    } else if (_positionTactic == PelotonPositionTactic.holdTop25) {
      final top25Draft = ridersCloselyAhead >= 2 ? 28.0 : (ridersCloselyAhead == 1 ? 18.0 : 0.0);
      _currentDraftSavingPercent = (top25Draft * aeroSlopeAttenuation).roundToDouble();
      _draftStatusLabel = "🎯 FROTTER TOP 25 (-${_currentDraftSavingPercent.toInt()}% VENT)";
    } else if (teammateDirectlyDrafting || _activeRadioOrder == TeammateRadioOrder.shelterLeader) {
      _currentDraftSavingPercent = (35.0 * aeroSlopeAttenuation).roundToDouble();
      _draftStatusLabel = "🛡️ ABRI ÉQUIPIER (-${_currentDraftSavingPercent.toInt()}% W)";
    } else if (ridersCloselyAhead >= 3) {
      _currentDraftSavingPercent = (40.0 * aeroSlopeAttenuation).roundToDouble();
      _isBoxedInPack = ridersBoxingPlayer >= 10 && _activeRadioOrder != TeammateRadioOrder.pullPeloton;
      _draftStatusLabel = _isBoxedInPack
          ? "⚠️ ENFERMÉ PELOTON (-${_currentDraftSavingPercent.toInt()}% W • BLOQUÉ)"
          : "🛡️ CŒUR PELOTON (-${_currentDraftSavingPercent.toInt()}% W)";
    } else if (ridersCloselyAhead >= 1) {
      _currentDraftSavingPercent = (25.0 * aeroSlopeAttenuation).roundToDouble();
      _draftStatusLabel = "🚴 DANS LA ROUE (-${_currentDraftSavingPercent.toInt()}% W)";
    } else {
      _currentDraftSavingPercent = 0.0;
      _draftStatusLabel = "💨 PLEIN VENT EN TÊTE (0% ABRI)";
    }

    // 3. Calcul de la vitesse effective du joueur (tenant compte des Watts, Pente, Pavés, Aspiration & Placement 150)
    double effectivePlayerSpeedKmh = rawTrainerSpeedKmh;
    if (playerWatts > 10) {
      double tacticalWatts = playerWatts.toDouble();
      // Si vos équipiers tirent un train de remontée (pullPeloton), ils ouvrent la route !
      if (_activeRadioOrder == TeammateRadioOrder.pullPeloton && teammates.any((t) => t.staminaPercent > 15)) {
        tacticalWatts *= 1.07;
      }
      // Si vous déboîtez sur l'aile (moveUpOnWing) en appuyant fort, la trajectoire est 100% fluide pour doubler
      if (_positionTactic == PelotonPositionTactic.moveUpOnWing && playerWatts >= baseAiWatts * 0.98) {
        tacticalWatts *= 1.05;
      }
      // À l'inverse, si vous restez enfermé au cœur du peloton (isBoxedInPack) et tentez de sprinter sans déboîter sur l'aile, vous êtes gêné par la masse des 150 coureurs !
      if (_isBoxedInPack && playerWatts > baseAiWatts * 1.08) {
        tacticalWatts = baseAiWatts * 1.03;
      }

      effectivePlayerSpeedKmh = _computePhysicalSpeedKmh(
        watts: tacticalWatts,
        weightKg: 72.0,
        slopePercent: currentSlope,
        crr: _activeRoute.rollingResistanceCrr,
        draftSavingRatio: _currentDraftSavingPercent / 100.0,
      );
    }

    if (effectivePlayerSpeedKmh > 0.5) {
      double stepMeters = effectivePlayerSpeedKmh / 3.6;
      // Effet "Machine à laver" du peloton de 150 coureurs : si on reste passif dans le cœur du paquet sous la puissance du peloton, on recule naturellement !
      if (_positionTactic == PelotonPositionTactic.stayInPack &&
          playerWatts < baseAiWatts * 0.94 &&
          ridersCloselyAhead >= 8) {
        stepMeters -= 0.28;
      }
      _playerDistanceMeters += math.max(0.0, stepMeters);
      _playerGcTimeSeconds++;
    }

    // Alerte tactique Radio si le joueur recule trop loin (> 65e/150) à l'approche d'un mur ou d'un sprint
    final currentRank = playerLiveRankOnRoad;
    if (currentRank > 65 && currentSlope >= 5.0 && _positionTactic == PelotonPositionTactic.stayInPack) {
      _raceRadioBannerMessage =
          "⚠️ Cassure en côte (${currentRank}e/150) ! Cliquez sur [⚡ Aile] ou [🚂 Remonter] pour doubler le peloton !";
    }
    for (int i = 0; i < _peloton.length; i++) {
      final r = _peloton[i];
      final riderSlope = _activeRoute.getSlopeAtDistance(r.distanceMeters);

      double targetRiderWatts = baseAiWatts * r.powerFactor;
      double riderDraftRatio = 0.28; // Le peloton s'abrite mutuellement

      if (r.isTeammate) {
        // Comportement intelligent de vos 3 équipiers selon votre Ordre Radio !
        if (_activeRadioOrder == TeammateRadioOrder.shelterLeader) {
          // L'équipier régule sa vitesse pour rester 2.0m à 3.5m juste devant vous !
          final desiredPos = _playerDistanceMeters + 2.2 + (i * 1.1);
          final diff = desiredPos - r.distanceMeters;
          r.distanceMeters += (effectivePlayerSpeedKmh / 3.6) + (diff * 0.35);
          r.currentWatts = (playerWatts * 1.05).round().clamp(140, 420);
          r.currentSpeedKmh = effectivePlayerSpeedKmh;
          r.staminaPercent = (r.staminaPercent - 0.08).clamp(15.0, 100.0);
          continue;
        } else if (_activeRadioOrder == TeammateRadioOrder.pullPeloton) {
          if (r.staminaPercent > 15) {
            targetRiderWatts *= 1.22; // +22% Watts en tête de train
            riderDraftRatio = 0.05;
            r.staminaPercent = (r.staminaPercent - 0.25).clamp(5.0, 100.0);
          }
        } else if (_activeRadioOrder == TeammateRadioOrder.leadOutSprint) {
          if (r.staminaPercent > 10) {
            targetRiderWatts *= 1.45; // Train de sprint Poisson-Pilote !
            r.staminaPercent = (r.staminaPercent - 0.6).clamp(5.0, 100.0);
          }
        } else if (_activeRadioOrder == TeammateRadioOrder.recover) {
          targetRiderWatts *= 0.85;
          riderDraftRatio = 0.38;
          r.staminaPercent = (r.staminaPercent + 0.35).clamp(5.0, 100.0);
        }
      } else {
        // Comportement tactique des Adversaires selon leur spécialité
        if (r.specialty == RiderSpecialty.climber && riderSlope >= 6.0) {
          targetRiderWatts *= 1.12; // Les grimpeurs attaquent dans les cols !
        } else if (r.specialty == RiderSpecialty.sprinter) {
          final distToSprint = (_activeRoute.intermediateSprintMeters - r.distanceMeters).abs();
          final distToFinish = (_activeRoute.totalDistanceMeters - r.distanceMeters).abs();
          if (distToSprint < 280 || distToFinish < 350) {
            targetRiderWatts *= 1.65; // Sprint massif aux banderoles !
          }
        }
      }

      final rSpeedKmh = _computePhysicalSpeedKmh(
        watts: targetRiderWatts,
        weightKg: r.specialty.weightKg,
        slopePercent: riderSlope,
        crr: _activeRoute.rollingResistanceCrr,
        draftSavingRatio: riderDraftRatio,
      );

      r.currentWatts = targetRiderWatts.round();
      r.currentSpeedKmh = rSpeedKmh;
      if (effectivePlayerSpeedKmh > 0.5 || _isRaceActive) {
        r.distanceMeters += (rSpeedKmh / 3.6);
        r.gcTotalTimeSeconds++;
      }
    }

    // 5. Détection du passage du Sprint Intermédiaire (Maillot Vert) et du Sommet GPM (Maillot à Pois)
    if (!_sprintBannerCrossed && _playerDistanceMeters >= _activeRoute.intermediateSprintMeters) {
      _sprintBannerCrossed = true;
      _awardIntermediateSprintPoints();
    }
    if (!_komBannerCrossed && _playerDistanceMeters >= _activeRoute.komSummitMeters) {
      _komBannerCrossed = true;
      _awardKomSummitPoints();
    }

    // 6. Enregistrement GPS réel 1 Hz pour Strava (.TCX)
    if (effectivePlayerSpeedKmh > 0.5 && playerWatts > 0) {
      if (playerWatts > _maxRecordedWatts) _maxRecordedWatts = playerWatts;
      final gps = _activeRoute.getGpsCoordinatesAt(_playerDistanceMeters);
      _stravaTrackpoints.add(
        StravaTrackpoint(
          timestamp: DateTime.now(),
          latitude: gps['lat']!,
          longitude: gps['lon']!,
          altitudeMeters: gps['ele']!,
          distanceMeters: _playerDistanceMeters,
          watts: playerWatts,
          cadenceRpm: playerCadenceRpm.round(),
          heartRateBpm: heartRateBpm,
        ),
      );
    }

    notifyListeners();
  }

  /// Équation physique réaliste de vitesse cycliste (Gravité + Roulement Pavés/Asphalte + Traînée Aéro avec Aspiration)
  double _computePhysicalSpeedKmh({
    required double watts,
    required double weightKg,
    required double slopePercent,
    required double crr,
    required double draftSavingRatio,
  }) {
    const double bikeMassKg = 7.8;
    final double totalMass = weightKg + bikeMassKg;
    const double g = 9.81;
    final double slopeRad = math.atan(slopePercent / 100.0);

    final double fGravity = totalMass * g * math.sin(slopeRad);
    final double fRolling = totalMass * g * math.cos(slopeRad) * crr;
    final double effectiveCda = 0.32 * (1.0 - draftSavingRatio.clamp(0.0, 0.45));
    const double airDensity = 1.20;

    // Résolution itérative rapide (Newton-Raphson 6 itérations) de : P = (F_grav + F_roll + 0.5*rho*CdA*v^2) * v
    double v = 8.0; // m/s initial
    for (int iter = 0; iter < 6; iter++) {
      final fAero = 0.5 * airDensity * effectiveCda * v * v;
      final fTotal = fGravity + fRolling + fAero;
      final pCalc = fTotal * v;
      final dPdv = fGravity + fRolling + 1.5 * airDensity * effectiveCda * v * v;
      if (dPdv.abs() > 0.01) {
        v = (v - (pCalc - watts) / dPdv).clamp(1.8, 22.5);
      }
    }
    return v * 3.6;
  }

  void _awardIntermediateSprintPoints() {
    const points = [20, 17, 15, 13, 11, 10, 9, 8, 7, 6];
    final rank = playerLiveRankOnRoad;
    final earned = rank <= points.length ? points[rank - 1] : 0;
    _playerSprintPoints += earned;

    // Attribuer les autres points aux coureurs du peloton
    final sorted = [..._peloton]..sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters));
    for (int i = 0; i < sorted.length && i < points.length; i++) {
      sorted[i].sprintPoints += points[i];
    }

    _raceRadioBannerMessage =
        "🟢 SPRINT INTERMÉDIAIRE FRANCHI : Vous passez ${rank}e (+$earned pts Maillot Vert) !";
  }

  void _awardKomSummitPoints() {
    final points = _activeRoute.komCategory.pointsTable;
    final rank = playerLiveRankOnRoad;
    final earned = rank <= points.length ? points[rank - 1] : 0;
    _playerKomPoints += earned;

    final sorted = [..._peloton]..sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters));
    for (int i = 0; i < sorted.length && i < points.length; i++) {
      sorted[i].komPoints += points[i];
    }

    _raceRadioBannerMessage =
        "🔴⚪ SOMMET GPM (${_activeRoute.komCategory.label}) : Vous passez ${rank}e (+$earned pts Maillot à Pois) !";
  }

  /// Exporte la sortie en cours au format Strava (.TCX Garmin avec GPS, Altitude, Watts, RPM, BPM)
  Future<String> exportRideToStravaTcx({required int averageWatts, required int elapsedSeconds}) async {
    final title = _activeCompetition != null && activeStage != null
        ? "${_activeCompetition!.title} - ${activeStage!.title}"
        : "Fogcycling - Ascension ${_activeRoute.name}";

    return StravaExporter.saveTcxFile(
      activityTitle: title,
      routeName: _activeRoute.name,
      trackpoints: _stravaTrackpoints,
      totalTimeSeconds: elapsedSeconds > 0 ? elapsedSeconds : 1,
      totalDistanceMeters: _playerDistanceMeters,
      averageWatts: averageWatts,
      maxWatts: _maxRecordedWatts,
    );
  }
}

import '../routes/mythical_routes.dart';

/// Les 10 niveaux de difficulté de l'IA (de 170 W à 260 W par paliers de 10 W)
class AiDifficultyLevel {
  final int level; // 1 à 10
  final int averageWatts; // 170, 180, ..., 260
  final String title;

  const AiDifficultyLevel({
    required this.level,
    required this.averageWatts,
    required this.title,
  });

  static List<AiDifficultyLevel> get allLevels => List.generate(10, (index) {
        final lvl = index + 1;
        final watts = 170 + (index * 10);
        const titles = [
          'Cyclotouriste',
          'Cyclosportif Débutant',
          'Cyclosportif Régulier',
          'Amateur Entraîné',
          'Compétiteur Club',
          'Compétiteur Régional',
          'Compétiteur National',
          'Élite Amateur',
          'Semi-Pro Continental',
          'Pro WorldTour',
        ];
        return AiDifficultyLevel(
          level: lvl,
          averageWatts: watts,
          title: titles[index],
        );
      });
}

/// Stratégies de course définies lors du briefing d'avant-course avec vos équipiers
enum TeamStrategy {
  protectLeader(
    '🛡️ Garde Rapprochée',
    'Vos 3 équipiers restent autour de vous en permanence pour couper le vent (-35% de Watts requis).',
  ),
  mountainTrain(
    '🚂 Train de Montagne',
    'Vos grimpeurs prennent la tête du peloton dès que la pente dépasse 5% pour distancer les sprinteurs.',
  ),
  chaseBreakaway(
    '💥 Contrôle & Chasse',
    'Vos rouleurs roulent en tête dans la plaine pour neutraliser les échappées avant le final.',
  ),
  breakawayRelay(
    '🚀 Point d\'Appui à l\'Avant',
    'Un équipier attaque dès le départ pour viser les maillots distinctifs et vous servir de relais final.',
  );

  final String title;
  final String description;
  const TeamStrategy(this.title, this.description);
}

/// Ordres radio tactiques envoyés en direct pendant la course
enum TeammateRadioOrder {
  shelterLeader('🛡️ M\'abriter', 'Un équipier se place 2m devant vous (-35% vent)'),
  pullPeloton('🚂 Remonter Peloton', 'Vos équipiers vous remontent vers la tête des 150 coureurs'),
  leadOutSprint('⚡ Poisson-Pilote', 'Train de sprint maximal pendant 25 secondes'),
  recover('🔋 Récupérer', 'Vos équipiers se replacent dans les roues pour recharger l\'énergie');

  final String label;
  final String tooltip;
  const TeammateRadioOrder(this.label, this.tooltip);
}

/// Tactique de placement individuel au sein du Peloton de 150 coureurs
enum PelotonPositionTactic {
  stayInPack(
    '🛡️ Cœur Peloton (-40% vent)',
    'Économie maximale d\'énergie au chaud, mais recul progressif et risque d\'enfermement/cassure.',
    0.0,
  ),
  holdTop25(
    '🎯 Frotter Top 25 (-28% vent)',
    'Défend votre place dans les 25 premiers pour aborder les côtes et éviter les cassures.',
    0.45,
  ),
  moveUpOnWing(
    '⚡ Remonter sur l\'Aile (-12% vent)',
    'Déboîte sur l\'extérieur pour doubler rapidement le peloton (demande un effort énergétique).',
    -1.45,
  );

  final String label;
  final String description;
  final double targetLateralLane;
  const PelotonPositionTactic(this.label, this.description, this.targetLateralLane);
}

/// Spécialité physiologique d'un coureur IA (Adversaire ou Équipier)
enum RiderSpecialty {
  climber('Grimpeur', 59.0),
  sprinter('Sprinteur', 76.0),
  puncheur('Puncheur / Flandrien', 69.0),
  rouleur('Rouleur CLM', 73.0);

  final String label;
  final double weightKg;
  const RiderSpecialty(this.label, this.weightKg);
}

/// Coureur du peloton (Équipier de votre équipe ou Adversaire IA)
class PelotonRider {
  final String id;
  final String name;
  final String countryFlag;
  final String teamName;
  final bool isTeammate;
  final RiderSpecialty specialty;
  final double powerFactor; // Multiplicateur par rapport au niveau d'IA choisi

  // État dynamique en course
  double distanceMeters;
  double lateralOffsetMeters;
  int currentWatts;
  double currentSpeedKmh;
  double staminaPercent; // Jauge d'énergie (100% -> 0%)

  // Classements cumulés sur une course par étapes
  int gcTotalTimeSeconds;
  int komPoints;
  int sprintPoints;

  PelotonRider({
    required this.id,
    required this.name,
    required this.countryFlag,
    required this.teamName,
    required this.isTeammate,
    required this.specialty,
    this.powerFactor = 1.0,
    this.distanceMeters = 0.0,
    this.lateralOffsetMeters = 0.0,
    this.currentWatts = 0,
    this.currentSpeedKmh = 0.0,
    this.staminaPercent = 100.0,
    this.gcTotalTimeSeconds = 0,
    this.komPoints = 0,
    this.sprintPoints = 0,
  });
}

/// Étape individuelle d'un Grand Tour ou d'une Classique
class RaceStage {
  final int stageNumber;
  final String title;
  final String stageType; // 'Haute Montagne', 'Vallons / Puncheurs', 'Pavés', 'Contre-la-Montre', 'Plaine & Sprint'
  final String expectedDuration; // ex: '30 min' à '1h30'
  final String routeId;

  const RaceStage({
    required this.stageNumber,
    required this.title,
    required this.stageType,
    required this.expectedDuration,
    required this.routeId,
  });

  MythicalRoute get route => MythicalRoutesCatalog.getById(routeId);
}

/// Épreuve complète (Grand Tour par étapes ou Monument d'un jour)
class CyclingCompetition {
  final String id;
  final String title;
  final String countryFlag;
  final String subtitle;
  final bool isStageRace; // true = Grand Tour, false = Classique d'un jour
  final String leaderJerseyName;
  final List<RaceStage> stages;

  const CyclingCompetition({
    required this.id,
    required this.title,
    required this.countryFlag,
    required this.subtitle,
    required this.isStageRace,
    required this.leaderJerseyName,
    required this.stages,
  });
}

/// Catalogue officiel des Grands Tours et des Monuments de Fogcycling
class CareerCompetitionsCatalog {
  static const List<CyclingCompetition> grandTours = [
    // 1. MINI TOUR DE FRANCE (10 ÉTAPES)
    CyclingCompetition(
      id: 'tour_de_france',
      title: 'Mini Tour de France (10 Étapes)',
      countryFlag: '🇫🇷',
      subtitle: 'De la Trouée d\'Arenberg au sommet du Galibier et du Mont Ventoux. Conquérez le Maillot Jaune, le Maillot à Pois et le Maillot Vert.',
      isStageRace: true,
      leaderJerseyName: 'Maillot Jaune',
      stages: [
        RaceStage(stageNumber: 1, title: 'Étape 1 : Prologue Contre-la-Montre', stageType: 'Contre-la-Montre (30 min)', expectedDuration: '30 min', routeId: 'cauberg_valkenburg'),
        RaceStage(stageNumber: 2, title: 'Étape 2 : Plaine & Bordures du Nord', stageType: 'Plaine & Sprints', expectedDuration: '40 min', routeId: 'poggio_sanremo'),
        RaceStage(stageNumber: 3, title: 'Étape 3 : L\'Enfer des Pavés d\'Arenberg', stageType: 'Secteurs Pavés', expectedDuration: '50 min', routeId: 'paris_roubaix_cobbles'),
        RaceStage(stageNumber: 4, title: 'Étape 4 : Puncheurs en Ardennes', stageType: 'Vallons & Côtes', expectedDuration: '45 min', routeId: 'mur_de_huy'),
        RaceStage(stageNumber: 5, title: 'Étape 5 : Massif Ardennais & Redoute', stageType: 'Moyenne Montagne', expectedDuration: '55 min', routeId: 'roche_aux_faucons'),
        RaceStage(stageNumber: 6, title: 'Étape 6 : Le Géant de Provence (Mont Ventoux)', stageType: 'Haute Montagne HC', expectedDuration: '1h20', routeId: 'mont_ventoux'),
        RaceStage(stageNumber: 7, title: 'Étape 7 : Transition & Sprint Intermédiaire', stageType: 'Plaine & Sprints', expectedDuration: '40 min', routeId: 'poggio_sanremo'),
        RaceStage(stageNumber: 8, title: 'Étape 8 (Reine) : Toit des Alpes — Col du Galibier', stageType: 'Haute Montagne HC', expectedDuration: '1h30', routeId: 'col_du_galibier'),
        RaceStage(stageNumber: 9, title: 'Étape 9 : Les 21 Virages de l\'Alpe d\'Huez', stageType: 'Haute Montagne HC', expectedDuration: '1h05', routeId: 'alpe_dhuez'),
        RaceStage(stageNumber: 10, title: 'Étape 10 : Finale Royale & Sprint des Champs', stageType: 'Sprint Final', expectedDuration: '35 min', routeId: 'cauberg_valkenburg'),
      ],
    ),

    // 2. TOUR DE BELGIQUE (6 ÉTAPES)
    CyclingCompetition(
      id: 'tour_de_belgique',
      title: 'Tour de Belgique (6 Étapes)',
      countryFlag: '🇧🇪',
      subtitle: 'Des monts pavés des Flandres aux côtes terribles de Wallonie (Mur de Huy, Redoute, Roche-aux-Faucons).',
      isStageRace: true,
      leaderJerseyName: 'Maillot Rouge-Jaune-Noir',
      stages: [
        RaceStage(stageNumber: 1, title: 'Étape 1 : Bordures de la Mer du Nord', stageType: 'Plaine & Vent', expectedDuration: '35 min', routeId: 'poggio_sanremo'),
        RaceStage(stageNumber: 2, title: 'Étape 2 : Monts des Flandres (Quaremont & Paterberg)', stageType: 'Monts Pavés', expectedDuration: '50 min', routeId: 'vieux_quaremont'),
        RaceStage(stageNumber: 3, title: 'Étape 3 : Assaut du Mur de Grammont (Kapelmuur)', stageType: 'Pavés & Côte', expectedDuration: '40 min', routeId: 'mur_de_grammont'),
        RaceStage(stageNumber: 4, title: 'Étape 4 : La Flèche Mosane — Mur de Huy', stageType: 'Arrivée au Sommet (19%)', expectedDuration: '40 min', routeId: 'mur_de_huy'),
        RaceStage(stageNumber: 5, title: 'Étape 5 (Reine) : Ardennaise (Redoute & Roche-aux-Faucons)', stageType: 'Étape Reine Wallonne', expectedDuration: '1h00', routeId: 'roche_aux_faucons'),
        RaceStage(stageNumber: 6, title: 'Étape 6 : Finale Royale à Bruxelles', stageType: 'Circuit Final', expectedDuration: '35 min', routeId: 'cauberg_valkenburg'),
      ],
    ),

    // 3. GIRO D'ITALIA (8 ÉTAPES)
    CyclingCompetition(
      id: 'giro_ditalia',
      title: 'Giro d\'Italia (8 Étapes)',
      countryFlag: '🇮🇹',
      subtitle: 'La conquête de la Maglia Rosa : de la Riviera de Sanremo aux 48 lacets enneigés du Passo dello Stelvio.',
      isStageRace: true,
      leaderJerseyName: 'Maglia Rosa',
      stages: [
        RaceStage(stageNumber: 1, title: 'Étape 1 : Prologue Riviera Ligure', stageType: 'Contre-la-Montre', expectedDuration: '30 min', routeId: 'poggio_sanremo'),
        RaceStage(stageNumber: 2, title: 'Étape 2 : Strade Bianche de Toscane', stageType: 'Chemins Blancs', expectedDuration: '50 min', routeId: 'vieux_quaremont'),
        RaceStage(stageNumber: 3, title: 'Étape 3 : Attaque dans le Poggio', stageType: 'Puncheurs', expectedDuration: '45 min', routeId: 'poggio_sanremo'),
        RaceStage(stageNumber: 4, title: 'Étape 4 : Escarpements des Apennins', stageType: 'Moyenne Montagne', expectedDuration: '55 min', routeId: 'roche_aux_faucons'),
        RaceStage(stageNumber: 5, title: 'Étape 5 : Muro di Sormano & Lombardie', stageType: 'Rampe Extrême', expectedDuration: '45 min', routeId: 'mur_de_huy'),
        RaceStage(stageNumber: 6, title: 'Étape 6 (Cima Coppi) : Passo dello Stelvio (2758m)', stageType: 'Haute Montagne HC', expectedDuration: '1h30', routeId: 'passo_stelvio'),
        RaceStage(stageNumber: 7, title: 'Étape 7 : Dolomites & Sommets Alpins', stageType: 'Haute Montagne HC', expectedDuration: '1h15', routeId: 'col_du_galibier'),
        RaceStage(stageNumber: 8, title: 'Étape 8 : Couronnement au Duomo de Milan', stageType: 'Sprint Final', expectedDuration: '35 min', routeId: 'poggio_sanremo'),
      ],
    ),

    // 4. VUELTA A ESPAÑA (8 ÉTAPES)
    CyclingCompetition(
      id: 'vuelta_espana',
      title: 'La Vuelta a España (8 Étapes)',
      countryFlag: '🇪🇸',
      subtitle: 'Des murs basques explosifs jusqu\'à l\'enfer asturien de l\'Alto de l\'Angliru et ses pentes à 23.5%.',
      isStageRace: true,
      leaderJerseyName: 'Maillot Rojo',
      stages: [
        RaceStage(stageNumber: 1, title: 'Étape 1 : Chrono Inaugural Ibérique', stageType: 'Contre-la-Montre', expectedDuration: '30 min', routeId: 'cauberg_valkenburg'),
        RaceStage(stageNumber: 2, title: 'Étape 2 : Murs Raides du Pays Basque', stageType: 'Puncheurs', expectedDuration: '45 min', routeId: 'mur_de_huy'),
        RaceStage(stageNumber: 3, title: 'Étape 3 : Vent et Bordures d\'Andalousie', stageType: 'Plaine', expectedDuration: '40 min', routeId: 'poggio_sanremo'),
        RaceStage(stageNumber: 4, title: 'Étape 4 : Lagos de Covadonga', stageType: 'Haute Montagne', expectedDuration: '1h05', routeId: 'alpe_dhuez'),
        RaceStage(stageNumber: 5, title: 'Étape 5 : Crêtes Catalanes', stageType: 'Vallons', expectedDuration: '50 min', routeId: 'roche_aux_faucons'),
        RaceStage(stageNumber: 6, title: 'Étape 6 (Reine) : L\'Enfer de l\'Alto de l\'Angliru', stageType: 'Haute Montagne HC (23.5%)', expectedDuration: '1h15', routeId: 'alto_angliru'),
        RaceStage(stageNumber: 7, title: 'Étape 7 : Sierra de Guadarrama', stageType: 'Montagne', expectedDuration: '1h10', routeId: 'mont_ventoux'),
        RaceStage(stageNumber: 8, title: 'Étape 8 : Finale Paseo del Prado à Madrid', stageType: 'Sprint Final', expectedDuration: '35 min', routeId: 'poggio_sanremo'),
      ],
    ),
  ];

  static const List<CyclingCompetition> classicsMonuments = [
    CyclingCompetition(
      id: 'liege_bastogne_liege',
      title: 'Liège-Bastogne-Liège (La Doyenne)',
      countryFlag: '🇧🇪',
      subtitle: 'Monument ardennais (~1h) : Côte de La Redoute, Côte de La Roche-aux-Faucons et plongée vers Liège.',
      isStageRace: false,
      leaderJerseyName: 'Trophée de La Doyenne',
      stages: [
        RaceStage(stageNumber: 1, title: 'Finale La Redoute -> La Roche-aux-Faucons -> Liège', stageType: 'Monument Ardennais', expectedDuration: '55 min', routeId: 'roche_aux_faucons'),
      ],
    ),
    CyclingCompetition(
      id: 'tour_des_flandres',
      title: 'Tour des Flandres (De Ronde)',
      countryFlag: '🇧🇪',
      subtitle: 'Monument flandrien (~1h) : pavés du Vieux Quaremont, rampe à 20% du Paterberg et arrivée à Audenarde.',
      isStageRace: false,
      leaderJerseyName: 'Lion des Flandres',
      stages: [
        RaceStage(stageNumber: 1, title: 'Enchaînement Vieux Quaremont & Paterberg', stageType: 'Monument Pavé', expectedDuration: '50 min', routeId: 'vieux_quaremont'),
      ],
    ),
    CyclingCompetition(
      id: 'milan_san_remo',
      title: 'Milan-San Remo (La Primavera)',
      countryFlag: '🇮🇹',
      subtitle: 'Monument des sprinteurs et puncheurs : attaque tranchante dans le Poggio di Sanremo et sprint sur la Via Roma.',
      isStageRace: false,
      leaderJerseyName: 'Trophée Primavera',
      stages: [
        RaceStage(stageNumber: 1, title: 'Capo Berta -> Cipressa -> Poggio -> Via Roma', stageType: 'Monument Italien', expectedDuration: '45 min', routeId: 'poggio_sanremo'),
      ],
    ),
    CyclingCompetition(
      id: 'paris_roubaix',
      title: 'Paris-Roubaix (L\'Enfer du Nord)',
      countryFlag: '🇫🇷',
      subtitle: 'Monument pavé (~1h) : Trouée d\'Arenberg, Carrefour de l\'Arbre et arrivée sur le Vélodrome de Roubaix.',
      isStageRace: false,
      leaderJerseyName: 'Pavé de Roubaix',
      stages: [
        RaceStage(stageNumber: 1, title: 'Trouée d\'Arenberg & Carrefour de l\'Arbre', stageType: 'Monument Pavé 5★', expectedDuration: '55 min', routeId: 'paris_roubaix_cobbles'),
      ],
    ),
    CyclingCompetition(
      id: 'fleche_wallonne',
      title: 'La Flèche Wallonne (Mur de Huy)',
      countryFlag: '🇧🇪',
      subtitle: 'Classique wallonne : explication explosive dans les pourcentages à 19% du Chemin des Chapelles.',
      isStageRace: false,
      leaderJerseyName: 'Trophée de Huy',
      stages: [
        RaceStage(stageNumber: 1, title: 'Ascension finale du Mur de Huy', stageType: 'Classique Puncheurs', expectedDuration: '35 min', routeId: 'mur_de_huy'),
      ],
    ),
    CyclingCompetition(
      id: 'classique_des_alpes',
      title: 'La Classique des Alpes (Haute Montagne)',
      countryFlag: '🇫🇷',
      subtitle: 'Rendez-vous des purs grimpeurs au sommet du Col du Galibier (2642m).',
      isStageRace: false,
      leaderJerseyName: 'Cristal des Alpes',
      stages: [
        RaceStage(stageNumber: 1, title: 'Ascension intégrale du Col du Galibier', stageType: 'Classique Montagne HC', expectedDuration: '1h15', routeId: 'col_du_galibier'),
      ],
    ),
  ];
}

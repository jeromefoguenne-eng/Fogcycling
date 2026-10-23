import 'dart:math' as math;

/// Catégorie officielle du Grand Prix de la Montagne (GPM / KOM)
enum KomCategory {
  hc('Hors Catégorie (HC)', [25, 20, 16, 14, 12, 10, 8, 6, 4, 2]),
  cat1('1re Catégorie', [15, 12, 10, 8, 6, 4, 2, 1]),
  cat2('2e Catégorie', [10, 8, 6, 4, 2, 1]),
  cat3('3e Catégorie', [5, 3, 2, 1]),
  cat4('4e Catégorie', [2, 1]);

  final String label;
  final List<int> pointsTable;
  const KomCategory(this.label, this.pointsTable);
}

/// Thème visuel 3D envoyé au moteur Three.js selon le lieu choisi
enum RouteVisualTheme {
  ventouxLunar('ventoux_lunar', 'Désert Calcaire Lunaire (Mont Ventoux)'),
  alpineSnow('alpine_snow', 'Haute Montagne & Neiges Éternelles'),
  cobblesFlanders('cobbles_flanders', 'Pavés du Nord & Monts Flandriens'),
  ardennesWoods('ardennes_woods', 'Forêts Vallonnées Ardennaises & Mosanes'),
  mediterranean('mediterranean', 'Riviera Italienne & Cyprès');

  final String jsKey;
  final String description;
  const RouteVisualTheme(this.jsKey, this.description);
}

/// Modèle complet d'une côte, d'un col mythique ou d'un secteur de classique.
class MythicalRoute {
  final String id;
  final String name;
  final String countryFlag;
  final String region;
  final String description;
  final double distanceKm;
  final double avgSlopePercent;
  final double maxSlopePercent;
  final int elevationGainMeters;
  final int startElevationMeters;
  final KomCategory komCategory;
  final RouteVisualTheme visualTheme;
  final bool isCobblestone;
  // Coordonnées GPS réelles pour l'export Strava (.TCX / .GPX)
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  // Profil par segments (pourcentages de pente successifs)
  final List<double> slopeProfileSegments;

  const MythicalRoute({
    required this.id,
    required this.name,
    required this.countryFlag,
    required this.region,
    required this.description,
    required this.distanceKm,
    required this.avgSlopePercent,
    required this.maxSlopePercent,
    required this.elevationGainMeters,
    required this.startElevationMeters,
    required this.komCategory,
    required this.visualTheme,
    this.isCobblestone = false,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.slopeProfileSegments,
  });

  double get totalDistanceMeters => distanceKm * 1000.0;

  /// Position du Sprint Intermédiaire (Maillot Vert) à 35% du parcours
  double get intermediateSprintMeters => totalDistanceMeters * 0.35;

  /// Position du Sommet GPM / KOM (Maillot à Pois) à 92% du parcours
  double get komSummitMeters => totalDistanceMeters * 0.92;

  /// Coefficient de résistance au roulement (majoré sur les pavés de Roubaix/Flandres)
  double get rollingResistanceCrr => isCobblestone ? 0.0135 : 0.0042;

  /// Retourne la pente exacte (en %) à une distance donnée en mètres
  double getSlopeAtDistance(double meters) {
    if (slopeProfileSegments.isEmpty) return avgSlopePercent;
    final progress = (meters / totalDistanceMeters).clamp(0.0, 0.9999);
    final idx = (progress * slopeProfileSegments.length).floor();
    final baseSlope = slopeProfileSegments[idx];
    // Légère modulation naturelle sinusoïdale de micro-relief
    final microRelief = math.sin(meters * 0.015) * 0.4;
    return double.parse((baseSlope + microRelief).toStringAsFixed(1));
  }

  /// Interpole les coordonnées GPS réelles (Lat, Lon, Altitude) pour Strava
  Map<String, double> getGpsCoordinatesAt(double meters) {
    final progress = (meters / totalDistanceMeters).clamp(0.0, 1.0);
    // Ajout d'une légère sinuosité réaliste de lacets sur la trace GPS
    final switchbackOffset = math.sin(meters * 0.008) * 0.0012;
    final lat = startLat + (endLat - startLat) * progress + switchbackOffset;
    final lon = startLon + (endLon - startLon) * progress - switchbackOffset;
    final ele = startElevationMeters + (elevationGainMeters * progress);
    return {
      'lat': lat,
      'lon': lon,
      'ele': ele,
    };
  }
}

/// Catalogue officiel des 12 Cols, Côtes et Secteurs Mythiques de Fogcycling.
class MythicalRoutesCatalog {
  static const List<MythicalRoute> routes = [
    // 1. MONT VENTOUX (FRANCE)
    MythicalRoute(
      id: 'mont_ventoux',
      name: 'Mont Ventoux (par Bédoin)',
      countryFlag: '🇫🇷',
      region: 'Provence, France',
      description: 'Le Géant de Provence : traversée de la forêt de Saint-Estève puis le désert calcaire lunaire dès le Chalet Reynard jusqu\'à l\'observatoire (1910m).',
      distanceKm: 21.5,
      avgSlopePercent: 7.5,
      maxSlopePercent: 12.0,
      elevationGainMeters: 1570,
      startElevationMeters: 340,
      komCategory: KomCategory.hc,
      visualTheme: RouteVisualTheme.ventouxLunar,
      startLat: 44.1238,
      startLon: 5.1802,
      endLat: 44.1740,
      endLon: 5.2786,
      slopeProfileSegments: [2.5, 4.2, 8.9, 9.5, 10.2, 9.8, 9.2, 7.5, 8.1, 8.8, 9.4, 11.2],
    ),

    // 2. MUR DE HUY (BELGIQUE)
    MythicalRoute(
      id: 'mur_de_huy',
      name: 'Mur de Huy (Chemin des Chapelles)',
      countryFlag: '🇧🇪',
      region: 'Wallonie (Huy), Belgique',
      description: 'Juge de paix de la Flèche Wallonne : approche le long de la Meuse puis les 1300m terribles du Chemin des Chapelles avec son virage à 19%.',
      distanceKm: 4.5,
      avgSlopePercent: 9.6,
      maxSlopePercent: 19.0,
      elevationGainMeters: 215,
      startElevationMeters: 75,
      komCategory: KomCategory.cat2,
      visualTheme: RouteVisualTheme.ardennesWoods,
      startLat: 50.5185,
      startLon: 5.2325,
      endLat: 50.5142,
      endLon: 5.2478,
      slopeProfileSegments: [1.5, 2.0, 3.5, 7.5, 11.0, 14.5, 18.5, 15.0, 11.5, 9.0],
    ),

    // 3. LA ROCHE-AUX-FAUCONS & LA REDOUTE (BELGIQUE)
    MythicalRoute(
      id: 'roche_aux_faucons',
      name: 'La Roche-aux-Faucons & Redoute',
      countryFlag: '🇧🇪',
      region: 'Ardennes Liégeoises, Belgique',
      description: 'Le final explosif de Liège-Bastogne-Liège : l\'enchaînement mythique de la Côte de La Redoute à Remouchamps et de La Roche-aux-Faucons.',
      distanceKm: 14.0,
      avgSlopePercent: 8.8,
      maxSlopePercent: 16.0,
      elevationGainMeters: 540,
      startElevationMeters: 130,
      komCategory: KomCategory.cat1,
      visualTheme: RouteVisualTheme.ardennesWoods,
      startLat: 50.4801,
      startLon: 5.7061,
      endLat: 50.5562,
      endLon: 5.5681,
      slopeProfileSegments: [2.0, 8.5, 11.5, 14.0, -4.0, 1.5, 9.8, 13.5, 15.2, 6.8, 4.5, 1.0],
    ),

    // 4. VIEUX QUAREMONT & PATERBERG (FLANDRES - PAVÉS)
    MythicalRoute(
      id: 'vieux_quaremont',
      name: 'Vieux Quaremont & Paterberg',
      countryFlag: '🇧🇪',
      region: 'Ardennes Flamandes, Belgique',
      description: 'Le cœur du Tour des Flandres : les longs pavés disjoints du Vieux Quaremont suivis du mur pavé vertigineux du Paterberg (20.3%).',
      distanceKm: 11.5,
      avgSlopePercent: 5.8,
      maxSlopePercent: 20.3,
      elevationGainMeters: 310,
      startElevationMeters: 30,
      komCategory: KomCategory.cat2,
      visualTheme: RouteVisualTheme.cobblesFlanders,
      isCobblestone: true,
      startLat: 50.7738,
      startLon: 3.5322,
      endLat: 50.7819,
      endLon: 3.5514,
      slopeProfileSegments: [1.5, 4.5, 8.2, 11.0, 4.2, -3.0, 2.0, 12.5, 19.5, 14.0, 1.5],
    ),

    // 5. MUR DE GRAMMONT / KAPELMUUR (BELGIQUE - PAVÉS)
    MythicalRoute(
      id: 'mur_de_grammont',
      name: 'Mur de Grammont (Kapelmuur)',
      countryFlag: '🇧🇪',
      region: 'Grammont (Geraardsbergen), Belgique',
      description: 'L\'ascension pavée légendaire en escaliers menant à la chapelle au sommet du Oudenberg (19.8% max).',
      distanceKm: 7.5,
      avgSlopePercent: 7.8,
      maxSlopePercent: 19.8,
      elevationGainMeters: 210,
      startElevationMeters: 25,
      komCategory: KomCategory.cat2,
      visualTheme: RouteVisualTheme.cobblesFlanders,
      isCobblestone: true,
      startLat: 50.7712,
      startLon: 3.8825,
      endLat: 50.7728,
      endLon: 3.8904,
      slopeProfileSegments: [1.5, 3.0, 6.8, 9.5, 13.5, 17.5, 19.2, 12.0, 2.0],
    ),

    // 6. COL DU GALIBIER (FRANCE)
    MythicalRoute(
      id: 'col_du_galibier',
      name: 'Col du Galibier (2642m)',
      countryFlag: '🇫🇷',
      region: 'Alpes (Savoie), France',
      description: 'Le toit mythique du Tour de France depuis Valloire via Plan Lachat jusqu\'aux lacets enneigés à 2642m d\'altitude.',
      distanceKm: 18.1,
      avgSlopePercent: 6.9,
      maxSlopePercent: 10.1,
      elevationGainMeters: 1245,
      startElevationMeters: 1397,
      komCategory: KomCategory.hc,
      visualTheme: RouteVisualTheme.alpineSnow,
      startLat: 45.1652,
      startLon: 6.4278,
      endLat: 45.0641,
      endLon: 6.4079,
      slopeProfileSegments: [4.5, 5.5, 6.2, 6.8, 7.5, 8.2, 8.8, 9.2, 9.8, 10.0],
    ),

    // 7. PASSO DELLO STELVIO (ITALIE)
    MythicalRoute(
      id: 'passo_stelvio',
      name: 'Passo dello Stelvio (48 Lacets)',
      countryFlag: '🇮🇹',
      region: 'Lombardie / Tyrol du Sud, Italie',
      description: 'La Cima Coppi du Giro d\'Italia : 24.3 km d\'ascension monumentale et 48 épingles à cheveux taillées dans la roche à 2758m.',
      distanceKm: 24.3,
      avgSlopePercent: 7.4,
      maxSlopePercent: 12.0,
      elevationGainMeters: 1808,
      startElevationMeters: 950,
      komCategory: KomCategory.hc,
      visualTheme: RouteVisualTheme.alpineSnow,
      startLat: 46.6197,
      startLon: 10.5872,
      endLat: 46.5286,
      endLon: 10.4533,
      slopeProfileSegments: [5.0, 6.2, 7.0, 7.8, 8.2, 8.5, 8.8, 9.4, 10.5, 11.2],
    ),

    // 8. POGGIO DI SANREMO & VIA ROMA (ITALIE)
    MythicalRoute(
      id: 'poggio_sanremo',
      name: 'Poggio di Sanremo (La Primavera)',
      countryFlag: '🇮🇹',
      region: 'Ligurie (Sanremo), Italie',
      description: 'Le final haletant de Milan-San Remo : approche côtière à haute vitesse, attaque dans le Poggio (3.7 km à 3.7%, rampe à 8%) et plongée vers la Via Roma.',
      distanceKm: 10.5,
      avgSlopePercent: 3.7,
      maxSlopePercent: 8.0,
      elevationGainMeters: 165,
      startElevationMeters: 10,
      komCategory: KomCategory.cat3,
      visualTheme: RouteVisualTheme.mediterranean,
      startLat: 43.8225,
      startLon: 7.8091,
      endLat: 43.8165,
      endLon: 7.7765,
      slopeProfileSegments: [1.0, 1.5, 3.8, 4.5, 5.2, 7.8, 4.0, -5.5, -4.0, 0.5],
    ),

    // 9. CAUBERG (PAYS-BAS)
    MythicalRoute(
      id: 'cauberg_valkenburg',
      name: 'Cauberg (Valkenburg)',
      countryFlag: '🇳🇱',
      region: 'Limbourg, Pays-Bas',
      description: 'La côte emblématique de l\'Amstel Gold Race et des Championnats du Monde : 1200 mètres d\'effort violent au cœur de Valkenburg.',
      distanceKm: 8.0,
      avgSlopePercent: 5.8,
      maxSlopePercent: 12.0,
      elevationGainMeters: 185,
      startElevationMeters: 70,
      komCategory: KomCategory.cat3,
      visualTheme: RouteVisualTheme.ardennesWoods,
      startLat: 50.8632,
      startLon: 5.8295,
      endLat: 50.8580,
      endLon: 5.8188,
      slopeProfileSegments: [1.5, 2.5, -2.0, 1.8, 5.5, 8.8, 11.8, 9.0, 4.5, 1.2],
    ),

    // 10. ALPE D'HUEZ (FRANCE)
    MythicalRoute(
      id: 'alpe_dhuez',
      name: 'Alpe d\'Huez (Les 21 Virages)',
      countryFlag: '🇫🇷',
      region: 'Isère (Oisans), France',
      description: 'La montée aux 21 virages numérotés depuis Bourg-d\'Oisans : attaque brutale à 11% dès les premiers lacets.',
      distanceKm: 13.8,
      avgSlopePercent: 8.1,
      maxSlopePercent: 13.0,
      elevationGainMeters: 1120,
      startElevationMeters: 730,
      komCategory: KomCategory.hc,
      visualTheme: RouteVisualTheme.alpineSnow,
      startLat: 45.0608,
      startLon: 6.0369,
      endLat: 45.0911,
      endLon: 6.0694,
      slopeProfileSegments: [10.8, 10.2, 8.5, 7.8, 8.8, 9.2, 7.5, 8.5, 9.8, 6.5],
    ),

    // 11. ALTO DE L'ANGLIRU (ESPAGNE)
    MythicalRoute(
      id: 'alto_angliru',
      name: 'Alto de l\'Angliru (Cueña les Cabres)',
      countryFlag: '🇪🇸',
      region: 'Asturies, Espagne',
      description: 'Le monstre de La Vuelta : des rampes inhumaines culminant à 23.5% dans le passage de la Cueña les Cabres.',
      distanceKm: 12.5,
      avgSlopePercent: 9.8,
      maxSlopePercent: 23.5,
      elevationGainMeters: 1265,
      startElevationMeters: 305,
      komCategory: KomCategory.hc,
      visualTheme: RouteVisualTheme.alpineSnow,
      startLat: 43.2261,
      startLon: -5.9422,
      endLat: 43.2215,
      endLon: -5.9410,
      slopeProfileSegments: [5.5, 7.5, 9.5, 12.5, 16.0, 19.5, 23.0, 18.0, 14.5, 8.0],
    ),

    // 12. PARIS-ROUBAIX : TROUÉE D'ARENBERG & CARREFOUR DE L'ARBRE (FRANCE)
    MythicalRoute(
      id: 'paris_roubaix_cobbles',
      name: 'Enfer du Nord (Arenberg & Carrefour de l\'Arbre)',
      countryFlag: '🇫🇷',
      region: 'Nord, France',
      description: 'Secteurs pavés 5 étoiles de Paris-Roubaix avec arrivée sur le Vélodrome : résistance au roulement maximale où seuls les gros Watts passent.',
      distanceKm: 15.0,
      avgSlopePercent: 1.2,
      maxSlopePercent: 4.0,
      elevationGainMeters: 95,
      startElevationMeters: 35,
      komCategory: KomCategory.cat4,
      visualTheme: RouteVisualTheme.cobblesFlanders,
      isCobblestone: true,
      startLat: 50.3911,
      startLon: 3.4114,
      endLat: 50.6781,
      endLon: 3.2053,
      slopeProfileSegments: [1.0, 1.5, 0.8, 2.0, 1.2, 0.5, 1.8, 1.0, 0.5, 0.0],
    ),
  ];

  static MythicalRoute getById(String id) {
    return routes.firstWhere(
      (r) => r.id == id,
      orElse: () => routes.first,
    );
  }
}

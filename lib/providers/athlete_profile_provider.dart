import 'package:flutter/foundation.dart';
import '../core/profile/athlete_profile_models.dart';

/// Contrôleur de la Phase 5 :
/// - Espace Membre (Profil Athlète, FTP, Poids, Calcul automatique des 7 Zones de Puissance)
/// - Historique des sorties & Suivi de charge physiologique (CTL Forme, ATL Fatigue, TSB Fraîcheur)
/// - Garage 3D (Choix du vélo et du maillot distinctif)
/// - Espace Administrateur Protégé (Rôle Admin, Audit de sécurité, Paramètres de sécurité FTMS)
class AthleteProfileProvider extends ChangeNotifier {
  // ─── 1. IDENTITÉ & PHYSIOLOGIE ATHLÈTE ──────────────────────────────────────
  String _displayName = "Jérôme Foguenne";
  String _role = "admin"; // 'admin' ou 'athlete'
  double _weightKg = 72.0;
  final int _heightCm = 178;
  int _ftpWatts = 200;
  int _maxHrBpm = 185;
  final int _restingHrBpm = 52;
  int _xpPoints = 1450;

  // ─── 2. GARAGE 3D (VÉLO & MAILLOT ÉQUIPÉS) ──────────────────────────────────
  GarageBikeModel _selectedBike = GarageBikeModel.catalog.first;
  GarageJerseyModel _selectedJersey = GarageJerseyModel.catalog.first;

  // ─── 3. HISTORIQUE DES SORTIES & CHARGE WKO5 (CTL / ATL / TSB) ──────────────
  final List<RecordedRideActivity> _rideHistory = [
    RecordedRideActivity(
      id: 'hist_1',
      title: 'Validation Matérielle Zwift Hub One & Braquets Cog',
      routeName: 'Mur de Huy (Chemin des Chapelles)',
      date: DateTime(2026, 10, 23, 14, 30),
      durationSeconds: 1500,
      distanceKm: 11.4,
      elevationGainMeters: 215,
      avgWatts: 185,
      normalizedPowerWatts: 194,
      intensityFactor: 0.97,
      trainingStressScore: 39.2,
      avgCadenceRpm: 86,
      avgHeartRateBpm: 148,
    ),
    RecordedRideActivity(
      id: 'hist_2',
      title: 'Séance Sweet Spot & Seuil FTP (Coach Stravos)',
      routeName: 'La Roche-aux-Faucons & Redoute',
      date: DateTime(2026, 10, 21, 18, 00),
      durationSeconds: 2400,
      distanceKm: 19.8,
      elevationGainMeters: 540,
      avgWatts: 178,
      normalizedPowerWatts: 186,
      intensityFactor: 0.93,
      trainingStressScore: 57.6,
      avgCadenceRpm: 89,
      avgHeartRateBpm: 154,
    ),
    RecordedRideActivity(
      id: 'hist_3',
      title: 'Reconnaissance Monts des Flandres (Pavés)',
      routeName: 'Vieux Quaremont & Paterberg',
      date: DateTime(2026, 10, 19, 10, 15),
      durationSeconds: 3100,
      distanceKm: 24.5,
      elevationGainMeters: 420,
      avgWatts: 172,
      normalizedPowerWatts: 184,
      intensityFactor: 0.92,
      trainingStressScore: 72.8,
      avgCadenceRpm: 84,
      avgHeartRateBpm: 151,
    ),
  ];

  // ─── 4. ESPACE ADMINISTRATEUR & SÉCURITÉ ────────────────────────────────────
  int _adminSafetyMaxWattsCeiling = 450;
  final bool _adminStrictRlsEnabled = true;
  final List<SecurityAuditEntry> _auditLogs = [
    SecurityAuditEntry(
      timestamp: DateTime(2026, 10, 23, 14, 35),
      category: 'BLE_FTMS_AUTH',
      severity: 'INFO',
      message: 'Prise de contrôle FTMS (Opcode 0x00) validée sur Zwift Hub One avec Indications CCCD.',
    ),
    SecurityAuditEntry(
      timestamp: DateTime(2026, 10, 23, 14, 36),
      category: 'SAFETY_LIMITER',
      severity: 'INFO',
      message: 'Limiteur matériel actif : Plafond 450W, Rampe max 20W/s.',
    ),
    SecurityAuditEntry(
      timestamp: DateTime(2026, 10, 23, 15, 30),
      category: 'RLS_POLICY',
      severity: 'INFO',
      message: 'Politiques Row Level Security (PostgreSQL) vérifiées pour les tables profiles et ride_activities.',
    ),
  ];

  // Getters
  String get displayName => _displayName;
  String get role => _role;
  bool get isAdmin => _role == 'admin';
  double get weightKg => _weightKg;
  int get heightCm => _heightCm;
  int get ftpWatts => _ftpWatts;
  double get wattsPerKgAtFtp => double.parse((_ftpWatts / _weightKg).toStringAsFixed(2));
  int get maxHrBpm => _maxHrBpm;
  int get restingHrBpm => _restingHrBpm;
  int get xpPoints => _xpPoints;
  int get athleteLevel => (_xpPoints ~/ 250) + 1;

  GarageBikeModel get selectedBike => _selectedBike;
  GarageJerseyModel get selectedJersey => _selectedJersey;
  List<PowerZoneRange> get powerZones => PowerZoneRange.computeCogganZones(_ftpWatts);
  List<RecordedRideActivity> get rideHistory => List.unmodifiable(_rideHistory);
  List<SecurityAuditEntry> get auditLogs => List.unmodifiable(_auditLogs);
  int get adminSafetyMaxWattsCeiling => _adminSafetyMaxWattsCeiling;
  bool get adminStrictRlsEnabled => _adminStrictRlsEnabled;

  // Métriques de charge d'entraînement (Performance Management Chart : CTL, ATL, TSB)
  double get ctlFitness {
    final totalTss = _rideHistory.fold(0.0, (sum, r) => sum + r.trainingStressScore);
    return double.parse((42.0 + (totalTss / 14.0)).toStringAsFixed(1));
  }

  double get atlFatigue {
    final recentTss = _rideHistory.take(2).fold(0.0, (sum, r) => sum + r.trainingStressScore);
    return double.parse((35.0 + (recentTss / 5.0)).toStringAsFixed(1));
  }

  double get tsbFormBalance => double.parse((ctlFitness - atlFatigue).toStringAsFixed(1));

  // ─── ACTIONS MEMBRE ─────────────────────────────────────────────────────────
  void updateProfile({
    String? name,
    double? weightKg,
    int? ftpWatts,
    int? maxHrBpm,
  }) {
    if (name != null && name.trim().isNotEmpty) _displayName = name.trim();
    if (weightKg != null) _weightKg = weightKg.clamp(40.0, 150.0);
    if (ftpWatts != null) _ftpWatts = ftpWatts.clamp(100, 450);
    if (maxHrBpm != null) _maxHrBpm = maxHrBpm.clamp(130, 220);

    _addAuditLog('PROFILE_UPDATE', 'INFO', 'Profil mis à jour : FTP=$_ftpWatts W, Poids=$_weightKg kg.');
    notifyListeners();
  }

  void equipBike(GarageBikeModel bike) {
    _selectedBike = bike;
    notifyListeners();
  }

  void equipJersey(GarageJerseyModel jersey) {
    _selectedJersey = jersey;
    notifyListeners();
  }

  /// Sauvegarde la sortie en cours dans l'historique et attribue des points d'expérience XP
  void recordCompletedRide({
    required String title,
    required String routeName,
    required int durationSeconds,
    required double distanceKm,
    required int elevationGainMeters,
    required int avgWatts,
    required int avgCadenceRpm,
    int? avgHeartRateBpm,
  }) {
    final np = (avgWatts * 1.04).round();
    final ifFactor = double.parse((np / _ftpWatts).toStringAsFixed(2));
    final tss = RecordedRideActivity.computeTss(
      durationSeconds: durationSeconds > 0 ? durationSeconds : 60,
      avgWatts: avgWatts > 0 ? avgWatts : 150,
      ftpWatts: _ftpWatts,
    );

    final activity = RecordedRideActivity(
      id: 'ride_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      routeName: routeName,
      date: DateTime.now(),
      durationSeconds: durationSeconds > 0 ? durationSeconds : 60,
      distanceKm: distanceKm,
      elevationGainMeters: elevationGainMeters,
      avgWatts: avgWatts > 0 ? avgWatts : 150,
      normalizedPowerWatts: np,
      intensityFactor: ifFactor,
      trainingStressScore: tss,
      avgCadenceRpm: avgCadenceRpm,
      avgHeartRateBpm: avgHeartRateBpm,
    );

    _rideHistory.insert(0, activity);
    _xpPoints += (tss * 2.5).round() + 50;
    _addAuditLog('ACTIVITY_SAVED', 'INFO', 'Sortie enregistrée : $title ($distanceKm km, TSS $tss).');
    notifyListeners();
  }

  // ─── ACTIONS ADMINISTRATEUR ─────────────────────────────────────────────────
  void setAdminSafetyMaxWattsCeiling(int maxWatts) {
    if (!isAdmin) {
      _addAuditLog(
        'RBAC_DENIED',
        'CRITICAL',
        'Tentative non autorisée de modification du plafond SafetyLimiter ($maxWatts W) par le rôle $_role.',
      );
      notifyListeners();
      return;
    }
    _adminSafetyMaxWattsCeiling = maxWatts.clamp(250, 600);
    _addAuditLog(
      'ADMIN_SAFETY_CEILING',
      'WARN',
      'Plafond matériel SafetyLimiter modifié par Admin : $_adminSafetyMaxWattsCeiling W.',
    );
    notifyListeners();
  }

  void toggleRoleForTesting() {
    _role = (_role == 'admin') ? 'athlete' : 'admin';
    _addAuditLog('ROLE_SWITCH', 'INFO', 'Rôle actif basculé sur : $_role');
    notifyListeners();
  }

  void _addAuditLog(String category, String severity, String message) {
    _auditLogs.insert(
      0,
      SecurityAuditEntry(
        timestamp: DateTime.now(),
        category: category,
        severity: severity,
        message: message,
      ),
    );
  }
}

/// Contrôleur de sécurité matérielle garantissant l'intégrité physique du cycliste.
/// Empêche tout à-coup violent sur le home trainer et filtre les consignes de résistance.
class SafetyLimiter {
  /// Taux maximal de variation de puissance : 20 Watts par seconde
  static const double maxWattsPerSecond = 20.0;

  /// Plafond absolu par défaut (ajustable par l'utilisateur)
  int maxPowerCeilingWatts;

  /// Puissance actuellement appliquée au matériel
  double _currentAppliedWatts = 0.0;

  /// Puissance cible demandée par l'entraînement ou l'utilisateur
  int _targetWatts = 0;

  /// Dernière valeur envoyée pour éviter d'inonder le bus BLE
  int _lastEmittedWatts = -1;

  /// Horodatage de la dernière mise à jour
  DateTime _lastUpdateTime = DateTime.now();

  /// État d'arrêt d'urgence
  bool _isEmergencyStopped = false;

  /// Callback déclenché pour envoyer la consigne physique sécurisée
  final void Function(int safeWatts) onSafeCommandCalculated;

  SafetyLimiter({
    this.maxPowerCeilingWatts = 400,
    required this.onSafeCommandCalculated,
  });

  bool get isEmergencyStopped => _isEmergencyStopped;
  int get currentAppliedWatts => _currentAppliedWatts.round();
  int get targetWatts => _targetWatts;

  /// Définir une nouvelle consigne de puissance (Mode ERG)
  void setTargetPower(int requestedWatts) {
    if (_isEmergencyStopped) return;

    // 1. Écrêtage selon le plafond de sécurité absolu
    int clampedWatts = requestedWatts;
    if (clampedWatts > maxPowerCeilingWatts) {
      clampedWatts = maxPowerCeilingWatts;
    }
    if (clampedWatts < 0) {
      clampedWatts = 0;
    }

    _targetWatts = clampedWatts;
  }

  /// Exécuté à intervalle régulier pour faire progresser la rampe en douceur
  void tick() {
    if (_isEmergencyStopped) {
      if (_lastEmittedWatts != 0) {
        _currentAppliedWatts = 0;
        _lastEmittedWatts = 0;
        onSafeCommandCalculated(0);
      }
      return;
    }

    final now = DateTime.now();
    final elapsedSeconds = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;
    _lastUpdateTime = now;

    if (elapsedSeconds <= 0) return;

    // Calcul du delta de variation autorisé pour cet intervalle de temps
    final maxAllowedDelta = maxWattsPerSecond * elapsedSeconds;

    if (_currentAppliedWatts < _targetWatts) {
      _currentAppliedWatts += maxAllowedDelta;
      if (_currentAppliedWatts > _targetWatts) {
        _currentAppliedWatts = _targetWatts.toDouble();
      }
    } else if (_currentAppliedWatts > _targetWatts) {
      final maxDecreaseDelta = maxWattsPerSecond * 1.5 * elapsedSeconds;
      _currentAppliedWatts -= maxDecreaseDelta;
      if (_currentAppliedWatts < _targetWatts) {
        _currentAppliedWatts = _targetWatts.toDouble();
      }
    }

    final rounded = _currentAppliedWatts.round();
    // On n'émet que si la valeur a changé et si une cible est active (> 0 ou passée à 0)
    if (rounded != _lastEmittedWatts && (_targetWatts > 0 || rounded == 0)) {
      _lastEmittedWatts = rounded;
      onSafeCommandCalculated(rounded);
    }
  }

  /// Déclenchement de l'arrêt d'urgence 1-tap
  void triggerEmergencyStop() {
    _isEmergencyStopped = true;
    _targetWatts = 0;
    _currentAppliedWatts = 0.0;
    _lastEmittedWatts = 0;
    onSafeCommandCalculated(0);
  }

  /// Réinitialisation après arrêt d'urgence
  void resetEmergencyStop() {
    _isEmergencyStopped = false;
    _targetWatts = 0;
    _currentAppliedWatts = 0.0;
    _lastEmittedWatts = -1;
    _lastUpdateTime = DateTime.now();
  }
}

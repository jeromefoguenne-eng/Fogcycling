import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/workouts/workout_models.dart';
import 'ble_sensor_provider.dart';

/// Contrôleur d'exécution des séances d'entraînement structurées (Phase 3).
/// Pilote l'asservissement automatique du frein en mode ERG sur le Zwift Hub One
/// au franchissement de chaque bloc d'intervalle.
class WorkoutProvider extends ChangeNotifier {
  int _userFtp = 200; // FTP par défaut modifiable par l'utilisateur
  WorkoutPlan? _activeWorkout;
  int _currentSegmentIndex = 0;
  int _segmentElapsedSeconds = 0;
  int _totalElapsedSeconds = 0;
  bool _isPaused = false;
  Timer? _timer;
  BleSensorProvider? _boundBleProvider;

  // Getters
  int get userFtp => _userFtp;
  WorkoutPlan? get activeWorkout => _activeWorkout;
  bool get isWorkoutActive => _activeWorkout != null;
  int get currentSegmentIndex => _currentSegmentIndex;
  int get segmentElapsedSeconds => _segmentElapsedSeconds;
  int get totalElapsedSeconds => _totalElapsedSeconds;
  bool get isPaused => _isPaused;

  WorkoutSegment? get currentSegment {
    if (_activeWorkout == null) return null;
    if (_currentSegmentIndex >= _activeWorkout!.segments.length) return null;
    return _activeWorkout!.segments[_currentSegmentIndex];
  }

  WorkoutSegment? get nextSegment {
    if (_activeWorkout == null) return null;
    final nextIdx = _currentSegmentIndex + 1;
    if (nextIdx >= _activeWorkout!.segments.length) return null;
    return _activeWorkout!.segments[nextIdx];
  }

  int get currentTargetWatts {
    final seg = currentSegment;
    if (seg == null) return 0;
    return seg.targetWattsForFtp(_userFtp);
  }

  int get segmentRemainingSeconds {
    final seg = currentSegment;
    if (seg == null) return 0;
    return (seg.durationSeconds - _segmentElapsedSeconds).clamp(0, seg.durationSeconds);
  }

  /// Modifie la FTP du cycliste et met immédiatement à jour la consigne ERG en cours
  void setUserFtp(int newFtp, BleSensorProvider ble) {
    _userFtp = newFtp.clamp(100, 420);
    if (isWorkoutActive && !_isPaused) {
      ble.setTargetPower(currentTargetWatts);
    }
    notifyListeners();
  }

  /// Démarre une séance structurée et enclenche immédiatement le mode ERG sur le trainer
  void startWorkout(WorkoutPlan workout, BleSensorProvider ble) {
    _timer?.cancel();
    _activeWorkout = workout;
    _boundBleProvider = ble;
    _currentSegmentIndex = 0;
    _segmentElapsedSeconds = 0;
    _totalElapsedSeconds = 0;
    _isPaused = false;

    _applyCurrentSegmentErg();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused || _activeWorkout == null) return;

      _segmentElapsedSeconds++;
      _totalElapsedSeconds++;

      final seg = currentSegment;
      if (seg != null && _segmentElapsedSeconds >= seg.durationSeconds) {
        // Passage automatique au bloc suivant !
        if (_currentSegmentIndex + 1 < _activeWorkout!.segments.length) {
          _currentSegmentIndex++;
          _segmentElapsedSeconds = 0;
          _applyCurrentSegmentErg();
        } else {
          // Fin de la séance complète !
          stopWorkout(ble);
          return;
        }
      }
      notifyListeners();
    });

    notifyListeners();
  }

  /// Passe immédiatement à l'intervalle suivant (très pratique pour tester ou écourter un bloc)
  void skipToNextSegment(BleSensorProvider ble) {
    if (_activeWorkout == null) return;
    if (_currentSegmentIndex + 1 < _activeWorkout!.segments.length) {
      _currentSegmentIndex++;
      _segmentElapsedSeconds = 0;
      _applyCurrentSegmentErg();
      notifyListeners();
    } else {
      stopWorkout(ble);
    }
  }

  /// Revient à l'intervalle précédent
  void previousSegment(BleSensorProvider ble) {
    if (_activeWorkout == null) return;
    if (_currentSegmentIndex > 0) {
      _currentSegmentIndex--;
      _segmentElapsedSeconds = 0;
      _applyCurrentSegmentErg();
      notifyListeners();
    }
  }

  void togglePause() {
    if (_activeWorkout == null) return;
    _isPaused = !_isPaused;
    notifyListeners();
  }

  /// Arrête la séance et remet le home trainer en mode simulation de pente libre (0%)
  void stopWorkout(BleSensorProvider ble) {
    _timer?.cancel();
    _timer = null;
    _activeWorkout = null;
    _currentSegmentIndex = 0;
    _segmentElapsedSeconds = 0;
    _isPaused = false;
    ble.setSimulatedSlope(0.0);
    notifyListeners();
  }

  void _applyCurrentSegmentErg() {
    final seg = currentSegment;
    if (seg != null && _boundBleProvider != null) {
      final watts = seg.targetWattsForFtp(_userFtp);
      _boundBleProvider!.setTargetPower(watts);
      _boundBleProvider!.addLog(
        "📋 [WORKOUT] Bloc '${seg.name}' (${seg.zoneName}) -> Consigne ERG : $watts W (${seg.targetCadenceRpm} RPM)",
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

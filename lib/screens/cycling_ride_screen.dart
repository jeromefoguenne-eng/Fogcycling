import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/rendering/cycling_3d_view.dart';
import '../core/workouts/workout_models.dart';
import '../providers/ble_sensor_provider.dart';
import '../providers/workout_provider.dart';
import 'hardware_test_screen.dart';

/// Écran principal de Ride en immersion 3D Cartoon (Fogcycling World - Phases 2 & 3).
/// Combine le moteur 3D Three.js v2 avec :
/// - Un affichage tête haute (HUD) haute lisibilité
/// - Le moteur d'entraînement structuré par intervalles (Mode ERG automatique)
/// - Le changement de braquet virtuel Zwift Cog (Mode Pente libre)
class CyclingRideScreen extends StatefulWidget {
  const CyclingRideScreen({super.key});

  @override
  State<CyclingRideScreen> createState() => _CyclingRideScreenState();
}

class _CyclingRideScreenState extends State<CyclingRideScreen> {
  Timer? _rideTimer;
  int _elapsedSeconds = 0;
  double _totalDistanceMeters = 0.0;
  double _accumulatedWatts = 0.0;
  int _wattsSampleCount = 0;

  // Mode Simulation / Démo (permet de visualiser le monde 3D sans pédaler)
  bool _isDemoMode = false;
  final int _demoWatts = 175;
  final double _demoCadence = 88.0;
  final double _demoSpeed = 31.0;
  double _demoSlope = 2.0;

  @override
  void initState() {
    super.initState();
    _rideTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final ble = Provider.of<BleSensorProvider>(context, listen: false);
      final workout = Provider.of<WorkoutProvider>(context, listen: false);

      final currentSpeedKmh = _isDemoMode ? _demoSpeed : ble.speedKmh;
      final currentWatts = _isDemoMode
          ? (workout.isWorkoutActive ? workout.currentTargetWatts : _demoWatts)
          : ble.powerWatts;

      if (currentSpeedKmh > 0.5) {
        setState(() {
          _elapsedSeconds++;
          _totalDistanceMeters += (currentSpeedKmh / 3.6);
          if (currentWatts > 0) {
            _accumulatedWatts += currentWatts;
            _wattsSampleCount++;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _rideTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Color _getPowerZoneColor(int watts, int ftp) {
    final ratio = ftp > 0 ? watts / ftp : 0.0;
    if (ratio < 0.60) return const Color(0xFF94A3B8); // Z1 Récupération
    if (ratio < 0.76) return const Color(0xFF38BDF8); // Z2 Endurance
    if (ratio < 0.90) return const Color(0xFF22C55E); // Z3 Tempo
    if (ratio < 1.05) return const Color(0xFFFACC15); // Z4 Seuil
    if (ratio < 1.20) return const Color(0xFFF97316); // Z5 PMA
    return const Color(0xFFEF4444); // Z6 Anaérobie
  }

  String _getPowerZoneLabel(int watts, int ftp) {
    final ratio = ftp > 0 ? watts / ftp : 0.0;
    if (ratio < 0.60) return "Z1 RÉCUP";
    if (ratio < 0.76) return "Z2 ENDURANCE";
    if (ratio < 0.90) return "Z3 TEMPO";
    if (ratio < 1.05) return "Z4 SEUIL";
    if (ratio < 1.20) return "Z5 PMA";
    return "Z6 ANAÉROBIE";
  }

  // Ouvre la fenêtre de sélection des entraînements structurés (Phase 3)
  void _openWorkoutSelectorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer2<WorkoutProvider, BleSensorProvider>(
          builder: (context, workoutProv, bleProv, _) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              maxChildSize: 0.92,
              minChildSize: 0.5,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Barre de poignée
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // En-tête + Réglage FTP
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "ENTRAÎNEMENTS STRUCTURÉS (ERG)",
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  "Le frein du Zwift Hub s'ajuste automatiquement à chaque bloc.",
                                  style: TextStyle(color: Colors.white60, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          // Ajusteur FTP
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.remove, size: 16, color: Colors.white),
                                  onPressed: () => workoutProv.setUserFtp(workoutProv.userFtp - 10, bleProv),
                                ),
                                Column(
                                  children: [
                                    const Text("VOTRE FTP", style: TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                    Text("${workoutProv.userFtp} W", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                                  onPressed: () => workoutProv.setUserFtp(workoutProv.userFtp + 10, bleProv),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Liste des séances du catalogue Coach Stravos
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: WorkoutCatalog.workouts.length,
                          itemBuilder: (context, idx) {
                            final plan = WorkoutCatalog.workouts[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.cyanAccent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          plan.category,
                                          style: const TextStyle(
                                            color: Colors.cyanAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        "⏱️ ${plan.formattedTotalDuration} (${plan.segments.length} blocs)",
                                        style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    plan.title,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    plan.subtitle,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),

                                  // Aperçu graphique des blocs de puissance
                                  SizedBox(
                                    height: 42,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: plan.segments.map((seg) {
                                        final heightFactor = (seg.ftpFactor / 1.3).clamp(0.25, 1.0);
                                        return Expanded(
                                          flex: seg.durationSeconds,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(horizontal: 1),
                                            height: 42 * heightFactor,
                                            decoration: BoxDecoration(
                                              color: seg.zoneColor,
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0284C7),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text(
                                        "LANCER CETTE SÉANCE (MODE ERG)",
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                      ),
                                      onPressed: () {
                                        workoutProv.startWorkout(plan, bleProv);
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleSensorProvider>();
    final workout = context.watch<WorkoutProvider>();

    final activeWatts = _isDemoMode
        ? (workout.isWorkoutActive ? workout.currentTargetWatts : _demoWatts)
        : ble.powerWatts;
    final activeCadence = _isDemoMode
        ? (workout.isWorkoutActive && workout.currentSegment != null
            ? workout.currentSegment!.targetCadenceRpm.toDouble()
            : _demoCadence)
        : ble.cadenceRpm;
    final activeSpeed = _isDemoMode ? _demoSpeed : ble.speedKmh;
    final activeSlope = _isDemoMode ? _demoSlope : ble.simulatedSlopePercent;
    final activeGear = ble.currentVirtualGear;
    final avgWatts = _wattsSampleCount > 0 ? (_accumulatedWatts / _wattsSampleCount).round() : 0;
    final distanceKm = (_totalDistanceMeters / 1000.0).toStringAsFixed(2);
    final zoneColor = _getPowerZoneColor(activeWatts, workout.userFtp);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── 1. MOTEUR 3D CARTOON WEBGL v2 ──────────────────────────────────
          Positioned.fill(
            child: Cycling3dView(
              watts: activeWatts,
              cadenceRpm: activeCadence,
              speedKmh: activeSpeed,
              slopePercent: activeSlope,
              gear: activeGear,
            ),
          ),

          // ─── 2. HUD SUPÉRIEUR : TÉLÉMÉTRIE & INTERVALLES D'ENTRAÎNEMENT ─────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                child: Column(
                  children: [
                    // Barre d'actions supérieure
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge Statut Bluetooth
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const HardwareTestScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: ble.connectedTrainer != null ? Colors.greenAccent : Colors.amber,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ble.connectedTrainer != null ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                                  color: ble.connectedTrainer != null ? Colors.greenAccent : Colors.amber,
                                  size: 15,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  ble.connectedTrainer != null
                                      ? "Zwift Hub OK"
                                      : (_isDemoMode ? "Démo Active" : "Connecter HT"),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Boutons : Séances ERG | Mode Démo | Banc d'essai | Arrêt d'urgence
                        Row(
                          children: [
                            // Bouton Catalogue d'Entraînements (Phase 3)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: workout.isWorkoutActive
                                    ? Colors.amberAccent
                                    : const Color(0xFF0284C7),
                                foregroundColor: workout.isWorkoutActive ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.fitness_center, size: 15),
                              label: Text(
                                workout.isWorkoutActive ? "ERG Actif" : "Séances",
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                              ),
                              onPressed: () => _openWorkoutSelectorModal(context),
                            ),
                            const SizedBox(width: 4),
                            // Bascule Mode Démo
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: "Mode Démo sans vélo",
                              icon: Icon(
                                _isDemoMode ? Icons.videogame_asset : Icons.videogame_asset_outlined,
                                color: _isDemoMode ? Colors.amberAccent : Colors.white70,
                              ),
                              onPressed: () => setState(() => _isDemoMode = !_isDemoMode),
                            ),
                            // Banc d'essai
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: "Banc d'essai & Capteurs",
                              icon: const Icon(Icons.tune, color: Colors.cyanAccent),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const HardwareTestScreen()),
                                );
                              },
                            ),
                            // Roue libre d'urgence
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: "Roue Libre d'urgence",
                              icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
                              onPressed: () => ble.triggerEmergencyStop(),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Carte Télémétrie Principale
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        children: [
                          // 1. Puissance (Watts) + Cible ERG si actif
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.bolt, color: zoneColor, size: 16),
                                    const SizedBox(width: 3),
                                    Text(
                                      _getPowerZoneLabel(activeWatts, workout.userFtp),
                                      style: TextStyle(
                                        color: zoneColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      "$activeWatts",
                                      style: TextStyle(
                                        color: zoneColor,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      workout.isWorkoutActive
                                          ? "/ ${workout.currentTargetWatts}W"
                                          : "W",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  "Moy : $avgWatts W",
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                              ],
                            ),
                          ),

                          Container(width: 1, height: 42, color: Colors.white24),
                          const SizedBox(width: 10),

                          // 2. Cadence & Cardio
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.rotate_right, color: Colors.cyanAccent, size: 15),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${activeCadence.round()}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Text("RPM", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.favorite, color: Colors.redAccent, size: 15),
                                    const SizedBox(width: 4),
                                    Text(
                                      ble.heartRateBpm != null ? "${ble.heartRateBpm}" : "--",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Text("BPM", style: TextStyle(color: Colors.white54, fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Container(width: 1, height: 42, color: Colors.white24),
                          const SizedBox(width: 10),

                          // 3. Vitesse, Distance & Chrono
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      activeSpeed.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Text("km/h", style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                                Text(
                                  "$distanceKm km • ${_formatDuration(_elapsedSeconds)}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "Pente ${activeSlope >= 0 ? '+' : ''}${activeSlope.toStringAsFixed(1)}%",
                                  style: TextStyle(
                                    color: activeSlope > 0 ? Colors.orangeAccent : Colors.tealAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ─── 3. BANDEAU D'INTERVALLE D'ENTRAÎNEMENT ACTIF (PHASE 3) ───
                    if (workout.isWorkoutActive && workout.currentSegment != null) ...[
                      const SizedBox(height: 6),
                      _buildActiveWorkoutBanner(context, workout, ble),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ─── 4. COCKPIT INFÉRIEUR : ZWIFT COG OU CONTRÔLES ERG ──────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sélecteur rapide de Pente (uniquement hors séance ERG)
                    if (!workout.isWorkoutActive)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("Pente col : ", style: TextStyle(color: Colors.white70, fontSize: 11)),
                            for (final s in [0.0, 3.0, 6.0, 9.0])
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: InkWell(
                                  onTap: () {
                                    if (_isDemoMode) {
                                      setState(() => _demoSlope = s);
                                    } else {
                                      ble.setSimulatedSlope(s);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: (activeSlope == s) ? Colors.orangeAccent : Colors.white12,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${s.toInt()}%",
                                      style: TextStyle(
                                        color: (activeSlope == s) ? Colors.black : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Panneau Zwift Cog Virtual Shifter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.remove, size: 22, color: Colors.cyanAccent),
                              label: const Text("SOUPLE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                              onPressed: () => ble.shiftDown(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  workout.isWorkoutActive ? "MODE ERG ACTIF" : "ZWIFT COG",
                                  style: TextStyle(
                                    color: workout.isWorkoutActive ? Colors.greenAccent : Colors.amberAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  workout.isWorkoutActive
                                      ? "Cible ${workout.currentTargetWatts} W"
                                      : "Vitesse $activeGear / 24",
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add, size: 22, color: Colors.orangeAccent),
                              label: const Text("DUR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                              onPressed: () => ble.shiftUp(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bandeau d'affichage de l'intervalle d'entraînement en cours (Phase 3)
  Widget _buildActiveWorkoutBanner(
    BuildContext context,
    WorkoutProvider workout,
    BleSensorProvider ble,
  ) {
    final seg = workout.currentSegment!;
    final nextSeg = workout.nextSegment;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: seg.zoneColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Nom du bloc actuel & Cible
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "BLOC ${workout.currentSegmentIndex + 1}/${workout.activeWorkout!.segments.length} : ${seg.name.toUpperCase()}",
                      style: TextStyle(
                        color: seg.zoneColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      "Consigne : ${workout.currentTargetWatts} W  •  Cadence : ${seg.targetCadenceRpm} RPM",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Compte à rebours du bloc
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: seg.zoneColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatDuration(workout.segmentRemainingSeconds),
                  style: TextStyle(
                    color: seg.zoneColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Conseil en direct de Coach Stravos
          Text(
            seg.coachAdvice,
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontStyle: FontStyle.italic),
          ),

          const SizedBox(height: 8),

          // Graphe miniature de progression des blocs + Boutons de navigation d'intervalles
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 18,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(workout.activeWorkout!.segments.length, (i) {
                      final s = workout.activeWorkout!.segments[i];
                      final isCurrent = i == workout.currentSegmentIndex;
                      final isPast = i < workout.currentSegmentIndex;
                      final h = (s.ftpFactor / 1.3).clamp(0.3, 1.0) * 18;
                      return Expanded(
                        flex: s.durationSeconds,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 0.8),
                          height: h,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? s.zoneColor
                                : (isPast ? s.zoneColor.withValues(alpha: 0.35) : Colors.white24),
                            borderRadius: BorderRadius.circular(2),
                            border: isCurrent ? Border.all(color: Colors.white, width: 1) : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Contrôles rapides : Bloc précédent / Pause / Sauter au bloc suivant / Stop
              InkWell(
                onTap: () => workout.previousSegment(ble),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.skip_previous, color: Colors.white70, size: 20),
                ),
              ),
              InkWell(
                onTap: () => workout.togglePause(),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    workout.isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.amberAccent,
                    size: 20,
                  ),
                ),
              ),
              InkWell(
                onTap: () => workout.skipToNextSegment(ble),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.skip_next, color: Colors.cyanAccent, size: 20),
                ),
              ),
              InkWell(
                onTap: () => workout.stopWorkout(ble),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 20),
                ),
              ),
            ],
          ),
          if (nextSeg != null)
            Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Text(
                "Suivant : ${nextSeg.name} (${nextSeg.targetWattsForFtp(workout.userFtp)} W pendant ${_formatDuration(nextSeg.durationSeconds)})",
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }
}

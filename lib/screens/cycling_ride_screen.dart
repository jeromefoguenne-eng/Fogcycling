import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/career/races_and_peloton_models.dart';
import '../core/multiplayer/multiplayer_models.dart';
import '../core/rendering/cycling_3d_view.dart';
import '../core/routes/mythical_routes.dart';
import '../core/strava/strava_exporter.dart';
import '../core/workouts/workout_models.dart';
import '../providers/athlete_profile_provider.dart';
import '../providers/ble_sensor_provider.dart';
import '../providers/career_race_provider.dart';
import '../providers/multiplayer_provider.dart';
import '../providers/workout_provider.dart';
import 'hardware_test_screen.dart';
import 'member_and_admin_screen.dart';
import 'multiplayer_lobby_modal.dart';
import 'coach_stravos_ai_modal.dart';

/// Écran principal de Fogcycling (Phases 2, 3 & 4) :
/// - Monde 3D Cartoon v2 avec Peloton (Équipiers & Adversaires) et thèmes par col
/// - 12 Côtes et Cols Mythiques (Ventoux, Huy, Roche-aux-Faucons, Quaremont, Grammont, Galibier, Stelvio, Poggio...)
/// - Grands Tours par Étapes, Monuments (~1h), 10 Niveaux d'IA (170W à 260W), Stratégies & Ordres Radio d'Équipiers
/// - Plans d'Entraînement Coach Stravos par Objectif & Intensité avec choix libre du lieu
/// - Physique d'Aspiration (Drafting -0% à -40%) & Export Strava (.TCX Garmin enrichi)
class CyclingRideScreen extends StatefulWidget {
  const CyclingRideScreen({super.key});

  @override
  State<CyclingRideScreen> createState() => _CyclingRideScreenState();
}

class _CyclingRideScreenState extends State<CyclingRideScreen> {
  Timer? _rideTimer;
  int _elapsedSeconds = 0;
  double _accumulatedWatts = 0.0;
  int _wattsSampleCount = 0;

  bool _isDemoMode = false;
  final int _demoWatts = 195;
  final double _demoCadence = 88.0;
  final double _demoSpeed = 32.5;

  WorkoutIntensity _selectedWorkoutIntensity = WorkoutIntensity.all;

  @override
  void initState() {
    super.initState();
    _rideTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final ble = Provider.of<BleSensorProvider>(context, listen: false);
      final workout = Provider.of<WorkoutProvider>(context, listen: false);
      final career = Provider.of<CareerRaceProvider>(context, listen: false);
      final mp = Provider.of<MultiplayerProvider>(context, listen: false);
      final profileProv = Provider.of<AthleteProfileProvider>(context, listen: false);

      final currentWatts = _isDemoMode
          ? (workout.isWorkoutActive ? workout.currentTargetWatts : _demoWatts)
          : ble.powerWatts;
      final currentCadence = _isDemoMode
          ? (workout.isWorkoutActive && workout.currentSegment != null
              ? workout.currentSegment!.targetCadenceRpm.toDouble()
              : _demoCadence)
          : ble.cadenceRpm;
      final rawSpeedKmh = _isDemoMode ? _demoSpeed : ble.speedKmh;

      career.tickSimulation(
        playerWatts: currentWatts,
        playerCadenceRpm: currentCadence,
        rawTrainerSpeedKmh: rawSpeedKmh,
        heartRateBpm: ble.heartRateBpm,
        isErgWorkoutActive: workout.isWorkoutActive,
        ble: ble,
      );

      mp.tickMultiplayer(
        playerWatts: currentWatts,
        playerCadenceRpm: currentCadence,
        playerSpeedKmh: rawSpeedKmh,
        playerDistanceMeters: career.playerDistanceMeters,
        currentSlopePercent: career.activeRoute.getSlopeAtDistance(career.playerDistanceMeters),
        playerHeartRateBpm: ble.heartRateBpm,
      );

      profileProv.tickWPrimePhysiology(currentWatts);

      if (rawSpeedKmh > 0.5 || currentWatts > 10) {
        setState(() {
          _elapsedSeconds++;
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
    if (ratio < 0.60) return const Color(0xFF94A3B8);
    if (ratio < 0.76) return const Color(0xFF38BDF8);
    if (ratio < 0.90) return const Color(0xFF22C55E);
    if (ratio < 1.05) return const Color(0xFFFACC15);
    if (ratio < 1.20) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
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

  // ─── 1. MODAL DE CHOIX DU LIEU / COL MYTHIQUE (12 PARCOURS) ────────────────
  void _openRouteSelectorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Consumer2<CareerRaceProvider, BleSensorProvider>(
          builder: (context, career, ble, _) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.80,
              maxChildSize: 0.94,
              minChildSize: 0.5,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "⛰️ CHOISIR UN LIEU / COL MYTHIQUE (12 PARCOURS RÉELS)",
                        style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                      const Text(
                        "La pente réelle, les pavés et la trace GPS Strava s'adaptent au lieu choisi.",
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: MythicalRoutesCatalog.routes.length,
                          itemBuilder: (ctx, i) {
                            final r = MythicalRoutesCatalog.routes[i];
                            final isSelected = career.activeRoute.id == r.id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? Colors.amberAccent : Colors.white12,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "${r.countryFlag} ${r.name}",
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: r.isCobblestone ? Colors.orangeAccent : Colors.redAccent.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          r.isCobblestone ? "PAVÉS 5★" : r.komCategory.label,
                                          style: TextStyle(
                                            color: r.isCobblestone ? Colors.black : Colors.amberAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(r.description, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "📏 ${r.distanceKm} km  •  ⛰️ Moy ${r.avgSlopePercent}% (Max ${r.maxSlopePercent}%)  •  +${r.elevationGainMeters}m D+",
                                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amberAccent,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                        ),
                                        onPressed: () {
                                          career.selectRoute(r, ble);
                                          Navigator.of(context).pop();
                                        },
                                        child: Text(
                                          isSelected ? "ACTIF" : "ROULER ICI",
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ],
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

  // ─── 2. MODAL MODE CARRIÈRE : GRANDS TOURS, CLASSIQUES, IA 10 NIVEAUX & STRATÉGIE D'ÉQUIPE ───
  void _openCareerAndStrategyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Consumer2<CareerRaceProvider, BleSensorProvider>(
          builder: (context, career, ble, _) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.88,
              maxChildSize: 0.95,
              minChildSize: 0.6,
              builder: (_, scrollController) {
                return DefaultTabController(
                  length: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "🏆 MODE CARRIÈRE, ÉQUIPIERS & PELOTON IA (10 NIVEAUX)",
                          style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),

                        // Sélecteur des 10 Niveaux d'IA (170W -> 260W)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "🤖 Niveau Peloton IA : Niveau ${career.aiLevel.level}/10 (${career.aiLevel.averageWatts} W moy.)",
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    career.aiLevel.title,
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: AiDifficultyLevel.allLevels.map((lvl) {
                                    final isSelected = career.aiLevel.level == lvl.level;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          "Niv.${lvl.level} (${lvl.averageWatts}W)",
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        selected: isSelected,
                                        selectedColor: Colors.amberAccent,
                                        backgroundColor: const Color(0xFF334155),
                                        onSelected: (_) => career.setAiDifficultyLevel(lvl),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        const TabBar(
                          indicatorColor: Colors.amberAccent,
                          labelColor: Colors.amberAccent,
                          unselectedLabelColor: Colors.white60,
                          labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                          tabs: [
                            Tab(text: "GRANDS TOURS"),
                            Tab(text: "CLASSIQUES (~1H)"),
                            Tab(text: "STRATÉGIE & MAILLOTS"),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Expanded(
                          child: TabBarView(
                            children: [
                              // ONGLET 1 : GRANDS TOURS PAR ÉTAPES (TDF, Belgique, Giro, Vuelta)
                              ListView.builder(
                                controller: scrollController,
                                itemCount: CareerCompetitionsCatalog.grandTours.length,
                                itemBuilder: (ctx, idx) {
                                  final tour = CareerCompetitionsCatalog.grandTours[idx];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "${tour.countryFlag} ${tour.title}",
                                          style: const TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w900),
                                        ),
                                        Text(tour.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                        const SizedBox(height: 8),
                                        ...List.generate(tour.stages.length, (sIdx) {
                                          final st = tour.stages[sIdx];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 3),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    "${st.title} (${st.expectedDuration})",
                                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF0284C7),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    minimumSize: Size.zero,
                                                  ),
                                                  onPressed: () {
                                                    career.startCompetitionStage(tour, sIdx, ble);
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: const Text("DÉPART", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // ONGLET 2 : LES 6 MONUMENTS & CLASSIQUES (~1H00)
                              ListView.builder(
                                itemCount: CareerCompetitionsCatalog.classicsMonuments.length,
                                itemBuilder: (ctx, idx) {
                                  final classic = CareerCompetitionsCatalog.classicsMonuments[idx];
                                  final st = classic.stages.first;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "${classic.countryFlag} ${classic.title}",
                                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                            Text(
                                              "⏱️ ${st.expectedDuration}",
                                              style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(classic.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amberAccent,
                                              foregroundColor: Colors.black,
                                            ),
                                            icon: const Icon(Icons.emoji_events, size: 16),
                                            label: const Text("PRENDRE LE DÉPART DE LA CLASSIQUE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                                            onPressed: () {
                                              career.startCompetitionStage(classic, 0, ble);
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // ONGLET 3 : STRATÉGIE D'ÉQUIPE, ÉQUIPIERS & CLASSEMENTS MAILLOTS
                              ListView(
                                children: [
                                  const Text(
                                    "📋 BRIEFING DE DÉPART : STRATÉGIE DE VOS 3 ÉQUIPIERS",
                                    style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 6),
                                  ...TeamStrategy.values.map((strat) {
                                    final isSelected = career.teamStrategy == strat;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF065F46) : const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isSelected ? Colors.greenAccent : Colors.white12),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        title: Text(strat.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                        subtitle: Text(strat.description, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                        trailing: Icon(
                                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                          color: isSelected ? Colors.greenAccent : Colors.white38,
                                        ),
                                        onTap: () => career.setTeamStrategy(strat),
                                      ),
                                    );
                                  }),
                                  const Divider(color: Colors.white24, height: 20),
                                  const Text(
                                    "👕 VOS MAILLOTS & POINTS CUMULÉS",
                                    style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        Column(
                                          children: [
                                            const Text("🟡 MAILLOT JAUNE", style: TextStyle(color: Colors.yellowAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                            Text("${career.playerLiveRankOnRoad}e Général", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            const Text("🔴⚪ MAILLOT À POIS", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                            Text("${career.playerKomPoints} pts GPM", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                          ],
                                        ),
                                        Column(
                                          children: [
                                            const Text("🟢 MAILLOT VERT", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                            Text("${career.playerSprintPoints} pts Sprint", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── 3. MODAL PLANS D'ENTRAÎNEMENT COACH STRAVOS + CHOIX DU LIEU + FILTRE INTENSITÉ ───
  void _openWorkoutSelectorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Consumer3<WorkoutProvider, BleSensorProvider, CareerRaceProvider>(
              builder: (context, workoutProv, bleProv, careerProv, _) {
                final filteredWorkouts = WorkoutCatalog.workouts.where((w) {
                  if (_selectedWorkoutIntensity == WorkoutIntensity.all) return true;
                  return w.intensity == _selectedWorkoutIntensity;
                }).toList();

                return DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.86,
                  maxChildSize: 0.95,
                  minChildSize: 0.5,
                  builder: (_, scrollController) {
                    return Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête + Réglage FTP
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "💪 PLANS & SÉANCES COACH STRAVOS",
                                      style: TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w900),
                                    ),
                                    Text(
                                      "Choisissez votre objectif, votre intensité et le lieu de la séance.",
                                      style: TextStyle(color: Colors.white60, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                      icon: const Icon(Icons.remove, size: 15, color: Colors.white),
                                      onPressed: () => workoutProv.setUserFtp(workoutProv.userFtp - 10, bleProv),
                                    ),
                                    Column(
                                      children: [
                                        const Text("FTP", style: TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                        Text("${workoutProv.userFtp}W", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.add, size: 15, color: Colors.white),
                                      onPressed: () => workoutProv.setUserFtp(workoutProv.userFtp + 10, bleProv),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Choix du Lieu / Parcours pour l'entraînement
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    "📍 Lieu de séance : ${careerProv.activeRoute.countryFlag} ${careerProv.activeRoute.name}",
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _openRouteSelectorModal(context);
                                  },
                                  child: const Text("CHANGER DE LIEU", style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Filtre par Intensité
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: WorkoutIntensity.values.map((inten) {
                                final isSelected = _selectedWorkoutIntensity == inten;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(
                                      inten.label,
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedColor: Colors.cyanAccent,
                                    backgroundColor: const Color(0xFF334155),
                                    onSelected: (_) {
                                      setModalState(() => _selectedWorkoutIntensity = inten);
                                      setState(() => _selectedWorkoutIntensity = inten);
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 10),

                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              itemCount: filteredWorkouts.length,
                              itemBuilder: (context, idx) {
                                final plan = filteredWorkouts[idx];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "${plan.category} • ${plan.goalObjective}",
                                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            "⏱️ ${plan.formattedTotalDuration}",
                                            style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(plan.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                                      Text(plan.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 34,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: plan.segments.map((seg) {
                                            final h = (seg.ftpFactor / 1.4).clamp(0.25, 1.0);
                                            return Expanded(
                                              flex: seg.durationSeconds,
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                                height: 34 * h,
                                                decoration: BoxDecoration(
                                                  color: seg.zoneColor,
                                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0284C7),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                          icon: const Icon(Icons.play_arrow, size: 18),
                                          label: Text(
                                            "LANCER SUR ${careerProv.activeRoute.name.toUpperCase()}",
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
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
      },
    );
  }

  // ─── 4. MODAL EXPORT STRAVA (.TCX GARMIN AVEC TRACE GPS DU COL + WATTS) ───
  Future<void> _exportToStravaDialog(BuildContext context, CareerRaceProvider career) async {
    final avgW = _wattsSampleCount > 0 ? (_accumulatedWatts / _wattsSampleCount).round() : 185;
    final filePath = await career.exportRideToStravaTcx(
      averageWatts: avgW,
      elapsedSeconds: _elapsedSeconds > 0 ? _elapsedSeconds : 60,
    );

    final xmlPreview = StravaExporter.generateGarminTcx(
      activityTitle: "Fogcycling - ${career.activeRoute.name}",
      routeName: career.activeRoute.name,
      trackpoints: career.stravaTrackpoints,
      totalTimeSeconds: _elapsedSeconds > 0 ? _elapsedSeconds : 60,
      totalDistanceMeters: career.playerDistanceMeters,
      averageWatts: avgW,
      maxWatts: avgW + 45,
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload, color: Colors.deepOrangeAccent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Activité Strava Prête (.TCX GPS + Watts)",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "📍 Parcours GPS : ${career.activeRoute.countryFlag} ${career.activeRoute.name}",
              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              "📏 Distance : ${(career.playerDistanceMeters / 1000).toStringAsFixed(2)} km  •  ⚡ Moy : $avgW W  •  🛰️ ${career.stravaTrackpoints.length} pts GPS",
              style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Text(
              "Fichier généré :\n$filePath",
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 8),
            const Text(
              "Ce fichier Garmin .TCX contient la vraie trace GPS du col, l'altitude, vos Watts, votre Cadence et vos BPM pour un affichage complet sur Strava.",
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16, color: Colors.cyanAccent),
            label: const Text("COPIER LE TCX", style: TextStyle(color: Colors.cyanAccent)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: xmlPreview));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("✅ Trace .TCX Strava copiée dans le presse-papiers !")),
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleSensorProvider>();
    final workout = context.watch<WorkoutProvider>();
    final career = context.watch<CareerRaceProvider>();
    final profileProv = context.watch<AthleteProfileProvider>();
    final mp = context.watch<MultiplayerProvider>();

    final activeWatts = _isDemoMode
        ? (workout.isWorkoutActive ? workout.currentTargetWatts : _demoWatts)
        : ble.powerWatts;
    final activeCadence = _isDemoMode
        ? (workout.isWorkoutActive && workout.currentSegment != null
            ? workout.currentSegment!.targetCadenceRpm.toDouble()
            : _demoCadence)
        : ble.cadenceRpm;
    final activeSpeed = _isDemoMode ? _demoSpeed : ble.speedKmh;
    final activeSlope = career.activeRoute.getSlopeAtDistance(career.playerDistanceMeters);
    final activeGear = ble.currentVirtualGear;
    final avgWatts = _wattsSampleCount > 0 ? (_accumulatedWatts / _wattsSampleCount).round() : 0;
    final distanceKm = (career.playerDistanceMeters / 1000.0).toStringAsFixed(2);
    final zoneColor = _getPowerZoneColor(activeWatts, workout.userFtp);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          // Boutons "+" (Volume +, Flèche Haut/Droite, Page Up, Piste Suivante) -> Vitesse + Dure
          if (key == LogicalKeyboardKey.audioVolumeUp ||
              key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.pageUp ||
              key == LogicalKeyboardKey.mediaTrackNext ||
              key == LogicalKeyboardKey.numpadAdd) {
            ble.shiftUp();
            return KeyEventResult.handled;
          }
          // Boutons "-" (Volume -, Flèche Bas/Gauche, Page Down, Piste Précédente) -> Vitesse + Souple
          if (key == LogicalKeyboardKey.audioVolumeDown ||
              key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.pageDown ||
              key == LogicalKeyboardKey.mediaTrackPrevious ||
              key == LogicalKeyboardKey.numpadSubtract) {
            ble.shiftDown();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
        children: [
          // ─── 1. MOTEUR 3D CARTOON WEBGL v2 (AVEC PELOTON IA, THÈMES, GARAGE & MULTIJOUEUR) ───
          Positioned.fill(
            child: Cycling3dView(
              watts: activeWatts,
              cadenceRpm: activeCadence,
              speedKmh: activeSpeed,
              slopePercent: activeSlope,
              gear: activeGear,
              themeKey: career.activeRoute.visualTheme.jsKey,
              bikeHexColor: profileProv.selectedBike.displayColor.toARGB32(),
              jerseyHexColor: profileProv.selectedJersey.displayColor.toARGB32(),
              multiplayerRidersJson: mp.relativeRidersJsonFor3d,
              graphicsQualityKey: profileProv.graphicsQuality.jsKey,
            ),
          ),

          // ─── 2. HUD SUPÉRIEUR : NAVIGATION, TÉLÉMÉTRIE, TACTIQUE & INTERVALLES ─
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Column(
                  children: [
                    // Barre de menu supérieure (Scrollable horizontalement sur petit écran)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // 1. Statut HT BLE
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const HardwareTestScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: ble.connectedTrainer != null ? Colors.greenAccent : Colors.amber,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    ble.connectedTrainer != null ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                                    color: ble.connectedTrainer != null ? Colors.greenAccent : Colors.amber,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    ble.connectedTrainer != null ? "HT OK" : "BLE",
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),

                          // 2. Choix du Lieu / Col Mythique
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: Colors.amberAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.terrain, size: 14),
                            label: Text(
                              "${career.activeRoute.countryFlag} ${career.activeRoute.name.split(' ').take(2).join(' ')}",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                            onPressed: () => _openRouteSelectorModal(context),
                          ),
                          const SizedBox(width: 5),

                          // 3. Carrière : Grands Tours, Classiques & IA 10 niveaux
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.emoji_events, size: 14),
                            label: Text(
                              "Courses (IA ${career.aiLevel.averageWatts}W)",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                            onPressed: () => _openCareerAndStrategyModal(context),
                          ),
                          const SizedBox(width: 5),

                          // 4. Multijoueur en Ligne & Salons Live (Phase 6)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.public, size: 14),
                            label: Text(
                              "Live (${mp.playerRankInRoom}/${mp.roomRiders.length})",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: const Color(0xFF0F172A),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (_) => const MultiplayerLobbyModal(),
                              );
                            },
                          ),
                          const SizedBox(width: 5),

                          // 5. Coach Stravos IA Sur Mesure, Batterie W', PDC & Nutrition (Phase 7)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.psychology, size: 14),
                            label: Text(
                              "Coach IA (W' ${profileProv.stravosEngine.wPrimePercentage.round()}%)",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: const Color(0xFF0F172A),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (_) => CoachStravosAiModal(
                                  currentRideDurationSeconds: _elapsedSeconds,
                                  currentRideAvgWatts: avgWatts,
                                  currentRideCadenceRpm: activeCadence,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 5),

                          // 6. Catalogue Séances & Plans Coach Stravos
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: workout.isWorkoutActive ? Colors.amberAccent : const Color(0xFF0284C7),
                              foregroundColor: workout.isWorkoutActive ? Colors.black : Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.fitness_center, size: 14),
                            label: Text(
                              workout.isWorkoutActive ? "ERG Actif" : "Séances",
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                            onPressed: () => _openWorkoutSelectorModal(context),
                          ),
                          const SizedBox(width: 5),

                          // 5. Espace Membre, Garage 3D, Charge CTL/ATL/TSB & Admin (Phase 5)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.person_pin, size: 14),
                            label: const Text("Profil & Garage", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MemberAndAdminScreen()),
                              );
                            },
                          ),
                          const SizedBox(width: 5),

                          // 6. Sauvegarder la Sortie dans l'Historique Membre (TSS / WKO5)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.save_alt, size: 14),
                            label: const Text("Sauver", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                            onPressed: () {
                              final savedW = avgWatts > 0 ? avgWatts : (activeWatts > 0 ? activeWatts : 195);
                              profileProv.recordCompletedRide(
                                title: workout.isWorkoutActive && workout.activeWorkout != null
                                    ? "Séance ${workout.activeWorkout!.title}"
                                    : "Ascension ${career.activeRoute.name}",
                                routeName: career.activeRoute.name,
                                durationSeconds: _elapsedSeconds > 30 ? _elapsedSeconds : 1800,
                                distanceKm: career.playerDistanceMeters > 100
                                    ? career.playerDistanceMeters / 1000.0
                                    : 12.5,
                                elevationGainMeters: (career.playerDistanceMeters * (activeSlope.clamp(1.0, 20.0) / 100.0)).round().clamp(120, 2500),
                                avgWatts: savedW,
                                avgCadenceRpm: activeCadence > 0 ? activeCadence.round() : 86,
                                avgHeartRateBpm: ble.heartRateBpm ?? 148,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.green.shade800,
                                  content: Text(
                                    "✅ Sortie enregistrée dans votre Espace Membre (${career.activeRoute.name} • $savedW W moy. • TSS calculé) !",
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 5),

                          // 7. Export Strava (.TCX)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.share_location, size: 14),
                            label: const Text("Strava", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                            onPressed: () => _exportToStravaDialog(context, career),
                          ),
                          const SizedBox(width: 4),

                          // 8. Mode Démo
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              _isDemoMode ? Icons.videogame_asset : Icons.videogame_asset_outlined,
                              color: _isDemoMode ? Colors.amberAccent : Colors.white70,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _isDemoMode = !_isDemoMode),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Carte Télémétrie Principale
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          // 1. Watts
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getPowerZoneLabel(activeWatts, workout.userFtp),
                                  style: TextStyle(color: zoneColor, fontSize: 9, fontWeight: FontWeight.w900),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      "$activeWatts",
                                      style: TextStyle(
                                        color: zoneColor,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      workout.isWorkoutActive ? "/${workout.currentTargetWatts}W" : "W",
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text("Moy : $avgWatts W", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),

                          Container(width: 1, height: 38, color: Colors.white24),
                          const SizedBox(width: 8),

                          // 2. Cadence & Cardio
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "🔄 ${activeCadence.round()} RPM",
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "❤️ ${ble.heartRateBpm ?? '--'} BPM",
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),

                          Container(width: 1, height: 38, color: Colors.white24),
                          const SizedBox(width: 8),

                          // 3. Vitesse, Pente du Col & Distance
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "${activeSpeed.toStringAsFixed(1)} km/h",
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                                Text(
                                  "$distanceKm / ${career.activeRoute.distanceKm} km • ${_formatDuration(_elapsedSeconds)}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "⛰️ Pente ${activeSlope >= 0 ? '+' : ''}${activeSlope.toStringAsFixed(1)}% (${career.activeRoute.komCategory.name.toUpperCase()})",
                                  style: TextStyle(
                                    color: activeSlope >= 7.0 ? Colors.redAccent : Colors.orangeAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ─── 3. BARRE TACTIQUE : ASPIRATION (DRAFTING), MAILLOTS & RADIO ÉQUIPE ───
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: career.currentDraftSavingPercent >= 25 ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Indicateur d'Aspiration (Drafting)
                              Text(
                                career.draftStatusLabel,
                                style: TextStyle(
                                  color: career.currentDraftSavingPercent >= 25 ? Colors.greenAccent : Colors.orangeAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              // Classement en direct & Maillots
                              Text(
                                "🟡 ${career.playerLiveRankOnRoad}e/13  •  🔴⚪ ${career.playerKomPoints}pts  •  🟢 ${career.playerSprintPoints}pts",
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          // Message Radio Directeur Sportif
                          Text(
                            career.raceRadioBannerMessage,
                            style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // ─── 4. BANDEAU D'INTERVALLE WORKOUT (SI SÉANCE ACTIVE) ───
                    if (workout.isWorkoutActive && workout.currentSegment != null) ...[
                      const SizedBox(height: 4),
                      _buildActiveWorkoutBanner(context, workout, ble),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ─── 5. COCKPIT INFÉRIEUR : ORDRES RADIO ÉQUIPIERS & ZWIFT COG ──────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Boutons Tactiques Radio Équipiers & Ride On ! Multijoueur (1-Clic)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Bouton rapide Ride On ! (Phase 6)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: InkWell(
                              onTap: () => mp.sendLiveEmote(LiveRaceEmote.rideOn),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.cyanAccent),
                                ),
                                child: Text(
                                  "👍 Ride On ! (${mp.rideOnsReceivedCount})",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ...TeammateRadioOrder.values.map((order) {
                            final isSelected = career.activeRadioOrder == order;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => career.sendRadioOrder(order),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.amberAccent
                                        : Colors.black.withValues(alpha: 0.78),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.cyanAccent.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    order.label,
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Panneau Zwift Cog Virtual Shifter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(16),
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
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.remove, size: 20, color: Colors.cyanAccent),
                              label: const Text("SOUPLE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                              onPressed: () => ble.shiftDown(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
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
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add, size: 20, color: Colors.orangeAccent),
                              label: const Text("DUR", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
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
    ),
    );
  }

  Widget _buildActiveWorkoutBanner(
    BuildContext context,
    WorkoutProvider workout,
    BleSensorProvider ble,
  ) {
    final seg = workout.currentSegment!;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: seg.zoneColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${seg.name} • Cible ${workout.currentTargetWatts}W (${seg.targetCadenceRpm} RPM)",
                  style: TextStyle(color: seg.zoneColor, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                _formatDuration(workout.segmentRemainingSeconds),
                style: TextStyle(color: seg.zoneColor, fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => workout.skipToNextSegment(ble),
                child: const Icon(Icons.skip_next, color: Colors.cyanAccent, size: 18),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => workout.stopWorkout(ble),
                child: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 18),
              ),
            ],
          ),
          Text(
            seg.coachAdvice,
            style: const TextStyle(color: Colors.white70, fontSize: 10, fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

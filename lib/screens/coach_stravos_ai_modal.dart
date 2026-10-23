import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/coach/coach_stravos_ai_engine.dart';
import '../core/settings/device_performance_and_storage.dart';
import '../providers/athlete_profile_provider.dart';
import '../providers/ble_sensor_provider.dart';
import '../providers/workout_provider.dart';

/// Fenêtre modale des Phases 7 & 8 :
/// - Générateur IA de Séances Sur Mesure par Coach Stravos (adapté au TSB & exécutable en 1 clic sur Zwift Hub One)
/// - Laboratoire WKO5 : Batterie anaérobie W' Balance (kJ), Courbe Puissance-Temps (PDC 5s/1m/5m/20m) & Quadrant Analysis
/// - Débriefing Post-Sortie, Nutrition Cycliste (g/h glucides ratio 2:1, hydratation, sodium) & Réglages Batterie/Qualité 3D
class CoachStravosAiModal extends StatefulWidget {
  final int currentRideDurationSeconds;
  final int currentRideAvgWatts;
  final double currentRideCadenceRpm;

  const CoachStravosAiModal({
    super.key,
    required this.currentRideDurationSeconds,
    required this.currentRideAvgWatts,
    required this.currentRideCadenceRpm,
  });

  @override
  State<CoachStravosAiModal> createState() => _CoachStravosAiModalState();
}

class _CoachStravosAiModalState extends State<CoachStravosAiModal> {
  int _selectedDurationMinutes = 45;
  StravosTrainingGoal _selectedGoal = StravosTrainingGoal.climbingThreshold;

  @override
  Widget build(BuildContext context) {
    return Consumer3<AthleteProfileProvider, WorkoutProvider, BleSensorProvider>(
      builder: (context, profile, workoutProv, bleProv, _) {
        final engine = profile.stravosEngine;
        final previewPlan = engine.generateCustomWorkout(
          durationMinutes: _selectedDurationMinutes,
          goal: _selectedGoal,
          currentTsbForm: profile.tsbFormBalance,
          athleteFtp: profile.ftpWatts,
        );
        final pdcPoints = engine.getPowerDurationCurve(
          ftpWatts: profile.ftpWatts,
          weightKg: profile.weightKg,
        );
        final debrief = engine.generatePostRideDebrief(
          durationSeconds: widget.currentRideDurationSeconds > 60
              ? widget.currentRideDurationSeconds
              : 2400,
          avgWatts: widget.currentRideAvgWatts > 50
              ? widget.currentRideAvgWatts
              : (profile.ftpWatts * 0.88).round(),
          targetOrFtpWatts: workoutProv.isWorkoutActive
              ? workoutProv.currentTargetWatts
              : profile.ftpWatts,
          cadenceRpm: widget.currentRideCadenceRpm > 30
              ? widget.currentRideCadenceRpm
              : 88.0,
          weightKg: profile.weightKg,
          avgHeartRateBpm: bleProv.heartRateBpm ?? 151,
        );

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          maxChildSize: 0.96,
          minChildSize: 0.55,
          builder: (_, scrollController) {
            return DefaultTabController(
              length: 3,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête Coach Stravos IA + Jauge W' Balance en direct
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "🧠 COACH STRAVOS IA — LABO WKO5 & NUTRITION",
                                style: TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                "Génération ERG sur mesure, Réserve W' (Skiba), Courbe PDC & Nutrition.",
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: engine.wPrimePercentage > 35
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                "BATTERIE W'",
                                style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                "${engine.currentWPrimeBalanceKj} kJ (${engine.wPrimePercentage.round()}%)",
                                style: TextStyle(
                                  color: engine.wPrimePercentage > 35
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    const TabBar(
                      indicatorColor: Colors.amberAccent,
                      labelColor: Colors.amberAccent,
                      unselectedLabelColor: Colors.white60,
                      labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      tabs: [
                        Tab(text: "IA SUR MESURE"),
                        Tab(text: "W' & PDC + 3D"),
                        Tab(text: "DÉBRIEF & NUTRI"),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: TabBarView(
                        children: [
                          // ─── ONGLET 1 : GÉNÉRATEUR IA DE SÉANCE SUR MESURE (1-CLIC -> ERG) ───
                          ListView(
                            controller: scrollController,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "⏱️ 1. DURÉE DISPONIBLE",
                                          style: TextStyle(
                                            color: Colors.cyanAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          "Fraîcheur TSB : ${profile.tsbFormBalance >= 0 ? '+' : ''}${profile.tsbFormBalance}",
                                          style: const TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [20, 30, 45, 60, 90].map((mins) {
                                          final isSel = _selectedDurationMinutes == mins;
                                          return Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: ChoiceChip(
                                              label: Text(
                                                "$mins min",
                                                style: TextStyle(
                                                  color: isSel ? Colors.black : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              selected: isSel,
                                              selectedColor: Colors.amberAccent,
                                              backgroundColor: const Color(0xFF334155),
                                              onSelected: (_) =>
                                                  setState(() => _selectedDurationMinutes = mins),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      "🎯 2. OBJECTIF PHYSIOLOGIQUE CIBLÉ",
                                      style: TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...StravosTrainingGoal.values.map((g) {
                                      final isSel = _selectedGoal == g;
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        decoration: BoxDecoration(
                                          color: isSel
                                              ? const Color(0xFF1E3A8A)
                                              : const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSel ? Colors.amberAccent : Colors.white12,
                                          ),
                                        ),
                                        child: ListTile(
                                          dense: true,
                                          title: Text(
                                            g.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          subtitle: Text(
                                            g.description,
                                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                                          ),
                                          trailing: Icon(
                                            isSel ? Icons.check_circle : Icons.circle_outlined,
                                            color: isSel ? Colors.amberAccent : Colors.white38,
                                            size: 18,
                                          ),
                                          onTap: () => setState(() => _selectedGoal = g),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Aperçu de la séance générée par Coach Stravos IA
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.amberAccent),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "📋 APERÇU : ${previewPlan.title}",
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      previewPlan.subtitle,
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 42,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: previewPlan.segments.map((seg) {
                                          final h = (seg.ftpFactor / 1.35).clamp(0.25, 1.0);
                                          return Expanded(
                                            flex: seg.durationSeconds,
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(horizontal: 1),
                                              height: 42 * h,
                                              decoration: BoxDecoration(
                                                color: seg.zoneColor,
                                                borderRadius:
                                                    const BorderRadius.vertical(top: Radius.circular(3)),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amberAccent,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.bolt, size: 20),
                                        label: const Text(
                                          "GÉNÉRER & LANCER EN MODE ERG SUR ZWIFT HUB",
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                        ),
                                        onPressed: () {
                                          workoutProv.setUserFtp(profile.ftpWatts, bleProv);
                                          workoutProv.startWorkout(previewPlan, bleProv);
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // ─── ONGLET 2 : COURBE PUISSANCE-TEMPS (PDC), W' BALANCE & QUALITÉ 3D (PHASE 8) ───
                          ListView(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "📈 COURBE PUISSANCE-TEMPS (PDC / RECORDS MMP)",
                                      style: TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...pdcPoints.map((pt) {
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F172A),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    pt.label,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    pt.physiologicalSystem,
                                                    style: const TextStyle(
                                                      color: Colors.white60,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  "${pt.bestWatts} W",
                                                  style: const TextStyle(
                                                    color: Colors.amberAccent,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                Text(
                                                  "${pt.wattsPerKg} W/kg",
                                                  style: const TextStyle(
                                                    color: Colors.cyanAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Réglage Qualité Graphique WebGL & Économie Batterie (Phase 8)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "📱 OPTIMISATION MOBILE : QUALITÉ 3D & BATTERIE (PHASE 8)",
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...GraphicsQualityPreset.values.map((preset) {
                                      final isSel = profile.graphicsQuality == preset;
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          preset.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        subtitle: Text(
                                          preset.description,
                                          style: const TextStyle(color: Colors.white60, fontSize: 10),
                                        ),
                                        trailing: Icon(
                                          isSel ? Icons.radio_button_checked : Icons.radio_button_off,
                                          color: isSel ? Colors.greenAccent : Colors.white38,
                                        ),
                                        onTap: () => profile.setGraphicsQuality(preset),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // ─── ONGLET 3 : DÉBRIEFING POST-SÉANCE & PLAN NUTRITIONNEL / HYDRATATION ───
                          ListView(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.amberAccent),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "🏅 ${debrief.coachHeadline}",
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      debrief.physiologicalAnalysis,
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "🍌 PLAN NUTRITIONNEL & HYDRATATION (SCIENCE POST-2022)",
                                      style: TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildMetricBox(
                                          "Dépense",
                                          "${debrief.nutrition.estimatedCaloriesKcal} kcal",
                                          Colors.orangeAccent,
                                        ),
                                        _buildMetricBox(
                                          "Glucides/h",
                                          "${debrief.nutrition.carbsGramsPerHour} g/h",
                                          Colors.amberAccent,
                                        ),
                                        _buildMetricBox(
                                          "Hydratation",
                                          "${debrief.nutrition.hydrationMlPerHour} ml/h",
                                          Colors.cyanAccent,
                                        ),
                                        _buildMetricBox(
                                          "Sodium",
                                          "${debrief.nutrition.sodiumMgPerHour} mg/h",
                                          Colors.greenAccent,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "🚴 Pendant l'effort : ${debrief.nutrition.inRideAdvice}",
                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "🥤 Récupération immédiate : ${debrief.nutrition.recoveryMealAdvice}",
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
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
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

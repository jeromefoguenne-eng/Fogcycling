import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/profile/athlete_profile_models.dart';
import '../providers/athlete_profile_provider.dart';
import '../providers/ble_sensor_provider.dart';
import '../providers/workout_provider.dart';

/// Écran de la Phase 5 : Espace Membre, Historique Physiologique, Garage 3D & Administration.
class MemberAndAdminScreen extends StatelessWidget {
  const MemberAndAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AthleteProfileProvider>();
    final workoutProv = context.watch<WorkoutProvider>();
    final bleProv = context.watch<BleSensorProvider>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B132B),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C2541),
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: profile.selectedJersey.displayColor,
                child: const Icon(Icons.directions_bike, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${profile.displayName} (Niv. ${profile.athleteLevel})",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      "FTP : ${profile.ftpWatts} W (${profile.wattsPerKgAtFtp} W/kg) • ${profile.xpPoints} XP",
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.amberAccent,
            labelColor: Colors.amberAccent,
            unselectedLabelColor: Colors.white60,
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            tabs: [
              Tab(icon: Icon(Icons.person, size: 18), text: "PROFIL & ZONES"),
              Tab(icon: Icon(Icons.analytics, size: 18), text: "HISTORIQUE & CHARGE"),
              Tab(icon: Icon(Icons.pedal_bike, size: 18), text: "GARAGE 3D"),
              Tab(icon: Icon(Icons.admin_panel_settings, size: 18), text: "ADMIN & SÉCURITÉ"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ─── ONGLET 1 : PROFIL ATHLÈTE & 7 ZONES COGGAN ───────────────────
            _buildProfileAndZonesTab(context, profile, workoutProv, bleProv),

            // ─── ONGLET 2 : HISTORIQUE DES SORTIES & CHARGE CTL/ATL/TSB ───────
            _buildHistoryAndPmcTab(context, profile),

            // ─── ONGLET 3 : GARAGE VÉLOS & MAILLOTS 3D ────────────────────────
            _buildGarageTab(context, profile),

            // ─── ONGLET 4 : ESPACE ADMINISTRATEUR & SÉCURITÉ RLS ──────────────
            _buildAdminSecurityTab(context, profile),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAndZonesTab(
    BuildContext context,
    AthleteProfileProvider profile,
    WorkoutProvider workoutProv,
    BleSensorProvider bleProv,
  ) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Carte Réglages Physiologiques
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "🧬 PARAMÈTRES PHYSIOLOGIQUES DE L'ATHLÈTE",
                style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              // FTP
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Puissance au Seuil (FTP) :", style: TextStyle(color: Colors.white, fontSize: 13)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.cyanAccent),
                        onPressed: () {
                          final newFtp = profile.ftpWatts - 5;
                          profile.updateProfile(ftpWatts: newFtp);
                          workoutProv.setUserFtp(newFtp, bleProv);
                        },
                      ),
                      Text(
                        "${profile.ftpWatts} W",
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
                        onPressed: () {
                          final newFtp = profile.ftpWatts + 5;
                          profile.updateProfile(ftpWatts: newFtp);
                          workoutProv.setUserFtp(newFtp, bleProv);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              // Poids
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Poids du cycliste :", style: TextStyle(color: Colors.white, fontSize: 13)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.cyanAccent),
                        onPressed: () => profile.updateProfile(weightKg: profile.weightKg - 1.0),
                      ),
                      Text(
                        "${profile.weightKg.toStringAsFixed(1)} kg",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.cyanAccent),
                        onPressed: () => profile.updateProfile(weightKg: profile.weightKg + 1.0),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Rapport Poids / Puissance au Seuil :", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    "${profile.wattsPerKgAtFtp} W/kg",
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          "⚡ VOS 7 ZONES DE PUISSANCE (CALCUL AUTOMATIQUE COGGAN)",
          style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),

        ...profile.powerZones.map((z) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: z.color.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    z.name,
                    style: TextStyle(color: z.color, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  z.zoneNumber == 7 ? "> ${z.minWatts} W" : "${z.minWatts} — ${z.maxWatts} W",
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHistoryAndPmcTab(BuildContext context, AthleteProfileProvider profile) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Bandeau Bilan de Charge WKO5 : CTL / ATL / TSB
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "📈 SUIVI DE CHARGE & FORME (MODÈLE BANISTER / WKO5)",
                style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricPill("CTL (Forme)", "${profile.ctlFitness}", Colors.cyanAccent),
                  _buildMetricPill("ATL (Fatigue)", "${profile.atlFatigue}", Colors.orangeAccent),
                  _buildMetricPill(
                    "TSB (Fraîcheur)",
                    "${profile.tsbFormBalance >= 0 ? '+' : ''}${profile.tsbFormBalance}",
                    profile.tsbFormBalance >= -10 ? Colors.greenAccent : Colors.redAccent,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                profile.tsbFormBalance >= 0
                    ? "💡 Diagnostic Coach Stravos : Fraîcheur optimale (TSB positif). Idéal pour tenter un record au Mont Ventoux ou disputer une étape Reine !"
                    : "💡 Diagnostic Coach Stravos : Charge d'entraînement productive. Prévoyez une séance Z1/Z2 si le TSB descend sous -20.",
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          "🗓️ HISTORIQUE DES SORTIES (${profile.rideHistory.length} activités sauvegardées)",
          style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),

        ...profile.rideHistory.map((ride) {
          final mins = (ride.durationSeconds / 60).round();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
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
                        ride.title,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "TSS ${ride.trainingStressScore}",
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "📍 ${ride.routeName}  •  ⏱️ $mins min  •  📏 ${ride.distanceKm.toStringAsFixed(1)} km (+${ride.elevationGainMeters}m)",
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "⚡ Moy: ${ride.avgWatts}W (NP: ${ride.normalizedPowerWatts}W • IF: ${ride.intensityFactor})",
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      "🔄 ${ride.avgCadenceRpm} RPM",
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGarageTab(BuildContext context, AthleteProfileProvider profile) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text(
          "🚲 CHOISIR VOTRE VÉLO DE COURSE 3D",
          style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...GarageBikeModel.catalog.map((bike) {
          final isSelected = profile.selectedBike.id == bike.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white12, width: isSelected ? 2 : 1),
            ),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: bike.displayColor, radius: 14),
              title: Text(bike.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
              subtitle: Text("${bike.specialty} • Poids : ${bike.weightKg} kg", style: const TextStyle(color: Colors.white70, fontSize: 11)),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.amberAccent)
                  : ElevatedButton(
                      onPressed: () => profile.equipBike(bike),
                      child: const Text("ÉQUIPER", style: TextStyle(fontSize: 11)),
                    ),
            ),
          );
        }),

        const SizedBox(height: 16),

        const Text(
          "👕 CHOISIR VOTRE MAILLOT DISTINCTIF 3D",
          style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...GarageJerseyModel.catalog.map((jersey) {
          final isSelected = profile.selectedJersey.id == jersey.id;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? Colors.amberAccent : Colors.white12, width: isSelected ? 2 : 1),
            ),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: jersey.displayColor, radius: 14),
              title: Text(jersey.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
              trailing: isSelected
                  ? const Icon(Icons.check_circle, color: Colors.amberAccent)
                  : ElevatedButton(
                      onPressed: () => profile.equipJersey(jersey),
                      child: const Text("PORTER", style: TextStyle(fontSize: 11)),
                    ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAdminSecurityTab(BuildContext context, AthleteProfileProvider profile) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Statut du Rôle & Contrôle d'Accès RBAC
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: profile.isAdmin ? Colors.greenAccent : Colors.orangeAccent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "RÔLE ACTIF : ${profile.role.toUpperCase()}",
                    style: TextStyle(
                      color: profile.isAdmin ? Colors.greenAccent : Colors.orangeAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    "Contrôle d'accès RBAC & Politiques RLS PostgreSQL actives.",
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: () => profile.toggleRoleForTesting(),
                child: const Text("SIMULER RÔLE", style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (!profile.isAdmin)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.redAccent),
            ),
            child: const Column(
              children: [
                Icon(Icons.lock, color: Colors.redAccent, size: 36),
                SizedBox(height: 8),
                Text(
                  "ACCÈS RESTREINT (RÔLE ATHLETE)",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900),
                ),
                Text(
                  "Conformément à la politique Row Level Security (RLS), seuls les administrateurs peuvent modifier les plafonds matériels et consulter les journaux d'audit.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          )
        else ...[
          // Panneau de configuration de sécurité matérielle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🛡️ SÉCURITÉ MATÉRIELLE (SAFETY LIMITER FTMS)",
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Plafond absolu de puissance ERG :", style: TextStyle(color: Colors.white, fontSize: 12)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.cyanAccent),
                          onPressed: () => profile.setAdminSafetyMaxWattsCeiling(profile.adminSafetyMaxWattsCeiling - 25),
                        ),
                        Text(
                          "${profile.adminSafetyMaxWattsCeiling} W",
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.cyanAccent),
                          onPressed: () => profile.setAdminSafetyMaxWattsCeiling(profile.adminSafetyMaxWattsCeiling + 25),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            "📜 JOURNAL D'AUDIT DE SÉCURITÉ & MATÉRIEL",
            style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),

          ...profile.auditLogs.map((log) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: log.severity == 'WARN' ? Colors.orangeAccent : Colors.white12,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    log.severity == 'WARN' ? Icons.warning_amber : Icons.verified_user,
                    color: log.severity == 'WARN' ? Colors.orangeAccent : Colors.greenAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "[${log.category}] ${log.timestamp.toIso8601String().substring(11, 19)}",
                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        Text(log.message, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildMetricPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

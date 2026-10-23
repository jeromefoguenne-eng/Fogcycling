import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/rendering/cycling_3d_view.dart';
import '../providers/ble_sensor_provider.dart';
import 'hardware_test_screen.dart';

/// Écran principal de Ride en immersion 3D Cartoon (Fogcycling World).
/// Combine le moteur 3D Three.js avec un affichage tête haute (HUD) haute lisibilité,
/// le changement de braquet virtuel Zwift Cog et la gestion des profils de dénivelé.
class CyclingRideScreen extends StatefulWidget {
  const CyclingRideScreen({super.key});

  @override
  State<CyclingRideScreen> createState() => _CyclingRideScreenState();
}

class _CyclingRideScreenState extends State<CyclingRideScreen> {
  // Chronomètre de séance
  Timer? _rideTimer;
  int _elapsedSeconds = 0;
  double _totalDistanceMeters = 0.0;
  double _accumulatedWatts = 0.0;
  int _wattsSampleCount = 0;

  // Mode Simulation / Démo (permet de visualiser le monde 3D sans pédaler)
  bool _isDemoMode = false;
  final int _demoWatts = 165;
  final double _demoCadence = 85.0;
  final double _demoSpeed = 29.5;
  double _demoSlope = 2.5;

  @override
  void initState() {
    super.initState();
    // Boucle de mise à jour des statistiques de course (1 Hz)
    _rideTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final ble = Provider.of<BleSensorProvider>(context, listen: false);
      final currentSpeedKmh = _isDemoMode ? _demoSpeed : ble.speedKmh;
      final currentWatts = _isDemoMode ? _demoWatts : ble.powerWatts;

      if (currentSpeedKmh > 0.5) {
        setState(() {
          _elapsedSeconds++;
          _totalDistanceMeters += (currentSpeedKmh / 3.6); // Conversion en mètres
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

  // Détermination de la zone Coggan de puissance (Z1 à Z6)
  Color _getPowerZoneColor(int watts) {
    if (watts < 130) return const Color(0xFF94A3B8); // Z1 Récupération (Gris bleuté)
    if (watts < 185) return const Color(0xFF22C55E); // Z2 Endurance (Vert)
    if (watts < 225) return const Color(0xFFEAB308); // Z3 Tempo (Jaune)
    if (watts < 265) return const Color(0xFFF97316); // Z4 Seuil (Orange)
    if (watts < 320) return const Color(0xFFEF4444); // Z5 PMA (Rouge)
    return const Color(0xFFA855F7); // Z6/Z7 Anaérobie (Violet)
  }

  String _getPowerZoneLabel(int watts) {
    if (watts < 130) return "Z1 RECUP";
    if (watts < 185) return "Z2 ENDURANCE";
    if (watts < 225) return "Z3 TEMPO";
    if (watts < 265) return "Z4 SEUIL";
    if (watts < 320) return "Z5 PMA";
    return "Z6 ANAÉROBIE";
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleSensorProvider>();

    // Données actives (réelles ou démo)
    final activeWatts = _isDemoMode ? _demoWatts : ble.powerWatts;
    final activeCadence = _isDemoMode ? _demoCadence : ble.cadenceRpm;
    final activeSpeed = _isDemoMode ? _demoSpeed : ble.speedKmh;
    final activeSlope = _isDemoMode ? _demoSlope : ble.simulatedSlopePercent;
    final activeGear = ble.currentVirtualGear;
    final avgWatts = _wattsSampleCount > 0 ? (_accumulatedWatts / _wattsSampleCount).round() : 0;
    final distanceKm = (_totalDistanceMeters / 1000.0).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── 1. MOTEUR 3D CARTOON WEBGL ─────────────────────────────────────
          Positioned.fill(
            child: Cycling3dView(
              watts: activeWatts,
              cadenceRpm: activeCadence,
              speedKmh: activeSpeed,
              slopePercent: activeSlope,
              gear: activeGear,
            ),
          ),

          // ─── 2. HUD SUPÉRIEUR : TÉLÉMÉTRIE & CHRONO ─────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  children: [
                    // Barre supérieure : Statut, Heure, Boutons d'accès
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge Statut Home Trainer
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
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
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                ble.connectedTrainer != null
                                    ? (ble.connectedTrainer!.platformName.isNotEmpty
                                        ? ble.connectedTrainer!.platformName
                                        : "Zwift Hub")
                                    : (_isDemoMode ? "Mode Démo Virtuel" : "Non Connecté"),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons : Démo / Banc d'essai / Roue Libre
                        Row(
                          children: [
                            // Bascule Mode Démo
                            IconButton(
                              tooltip: "Activer simulation sans vélo",
                              icon: Icon(
                                _isDemoMode ? Icons.videogame_asset : Icons.videogame_asset_outlined,
                                color: _isDemoMode ? Colors.amberAccent : Colors.white70,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isDemoMode = !_isDemoMode;
                                });
                              },
                            ),
                            // Bouton Banc d'essai / Scanner BLE
                            IconButton(
                              tooltip: "Ouvrir Banc d'essai / Diagnostics",
                              icon: const Icon(Icons.tune, color: Colors.cyanAccent),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const HardwareTestScreen()),
                                );
                              },
                            ),
                            // Arrêt d'urgence
                            IconButton(
                              tooltip: "Débrayer en Roue Libre",
                              icon: const Icon(Icons.power_settings_new, color: Colors.redAccent),
                              onPressed: () => ble.triggerEmergencyStop(),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Carte Télémétrie Flottante Principale
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          // 1. Jauge de Puissance (Watts)
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.bolt, color: _getPowerZoneColor(activeWatts), size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getPowerZoneLabel(activeWatts),
                                      style: TextStyle(
                                        color: _getPowerZoneColor(activeWatts),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
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
                                        color: _getPowerZoneColor(activeWatts),
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "W",
                                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text(
                                  "Moy : $avgWatts W",
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                          // Séparateur vertical
                          Container(width: 1, height: 45, color: Colors.white24),
                          const SizedBox(width: 12),

                          // 2. Cadence & Cardio
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.rotate_right, color: Colors.cyanAccent, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${activeCadence.round()}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text("RPM", style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      ble.heartRateBpm != null ? "${ble.heartRateBpm}" : "--",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text("BPM", style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Séparateur vertical
                          Container(width: 1, height: 45, color: Colors.white24),
                          const SizedBox(width: 12),

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
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Text("km/h", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  ],
                                ),
                                Text(
                                  "$distanceKm km  •  ${_formatDuration(_elapsedSeconds)}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
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

          // ─── 3. CARTE PENTE / PROFIL DU PARCOURS (EN HAUT À DROITE) ─────────
          Positioned(
            top: 155,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: activeSlope > 0 ? Colors.orangeAccent : Colors.tealAccent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    activeSlope >= 0 ? Icons.terrain : Icons.trending_down,
                    color: activeSlope > 0 ? Colors.orangeAccent : Colors.tealAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${activeSlope >= 0 ? '+' : ''}${activeSlope.toStringAsFixed(1)} %",
                    style: TextStyle(
                      color: activeSlope > 0 ? Colors.orangeAccent : Colors.tealAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── 4. COCKPIT INFERIEUR : ZWIFT COG VIRTUAL SHIFTER & PENTES ───────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sélecteur rapide de Pente pour tester le dénivelé interactif
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Pente col : ", style: TextStyle(color: Colors.white70, fontSize: 11)),
                          for (final s in [0.0, 3.0, 6.0, 9.0])
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () {
                                  if (_isDemoMode) {
                                    setState(() => _demoSlope = s);
                                  } else {
                                    ble.setSimulatedSlope(s);
                                  }
                                },
                                borderRadius: BorderRadius.circular(8),
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

                    const SizedBox(height: 8),

                    // Panneau Zwift Cog Virtual Shifter (Boutons tactiles géants)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Bouton Vitesse Inférieure (Plus Souple)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.remove, size: 26, color: Colors.cyanAccent),
                              label: const Text(
                                "SOUPLE",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                              ),
                              onPressed: () => ble.shiftDown(),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Indicateur central de braquet Zwift Cog
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "ZWIFT COG",
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  "Vitesse $activeGear / 24",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  "Ratio : ${ble.currentGearRatio.toStringAsFixed(2)}",
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Bouton Vitesse Supérieure (Plus Dur)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.add, size: 26, color: Colors.orangeAccent),
                              label: const Text(
                                "DUR",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                              ),
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
}

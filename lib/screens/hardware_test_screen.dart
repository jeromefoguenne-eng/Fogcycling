import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_sensor_provider.dart';
import 'cycling_ride_screen.dart';

class HardwareTestScreen extends StatefulWidget {
  const HardwareTestScreen({super.key});

  @override
  State<HardwareTestScreen> createState() => _HardwareTestScreenState();
}

class _HardwareTestScreenState extends State<HardwareTestScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getPowerZoneColor(int watts) {
    if (watts < 120) return const Color(0xFF64748B); // Z1 Récupération
    if (watts < 170) return const Color(0xFF0284C7); // Z2 Endurance
    if (watts < 220) return const Color(0xFF16A34A); // Z3 Tempo
    if (watts < 270) return const Color(0xFFEAB308); // Z4 Seuil
    if (watts < 320) return const Color(0xFFEA580C); // Z5 PMA
    return const Color(0xFFDC2626); // Z6/Z7 Anaérobie
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleSensorProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFF38BDF8), size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Fogcycling — Banc d'Essai Phase 1",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videogame_asset, color: Colors.amberAccent),
            tooltip: "Monde 3D Cartoon",
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const CyclingRideScreen()),
                );
              }
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ble.connectedTrainer != null ? const Color(0xFF065F46) : const Color(0xFF7F1D1D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: ble.connectedTrainer != null ? const Color(0xFF34D399) : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  ble.connectedTrainer != null ? "Trainer OK" : "Non appairé",
                  style: TextStyle(
                    color: ble.connectedTrainer != null ? const Color(0xFF34D399) : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (ble.connectedTrainer != null || ble.connectedHeartRateDevice != null)
            IconButton(
              icon: const Icon(Icons.link_off, color: Colors.redAccent, size: 22),
              tooltip: "Déconnecter tout",
              onPressed: () => ble.disconnectAll(),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: const Color(0xFF94A3B8),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.sports_motorsports, size: 20), text: "Cockpit & Frein"),
            Tab(icon: Icon(Icons.bluetooth_searching, size: 20), text: "Scanner BLE"),
            Tab(icon: Icon(Icons.terminal, size: 20), text: "Diagnostic"),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // ONGLET 1 : COCKPIT & CONTRÔLE DE RÉSISTANCE (Sans scroll excessif)
            _buildCockpitTab(ble),

            // ONGLET 2 : SCANNER BLUETOOTH
            _buildScannerTab(ble),

            // ONGLET 3 : CONSOLE DE LOGS
            _buildDiagnosticTab(ble),
          ],
        ),
      ),
    );
  }

  // ==============================================================================
  // ONGLET 1 : COCKPIT CYCLISTE & RÉSISTANCE (100% VISIBLE SUR UN SEUL ÉCRAN)
  // ==============================================================================
  Widget _buildCockpitTab(BleSensorProvider ble) {
    final powerColor = _getPowerZoneColor(ble.powerWatts);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── BANDEAU ARRÊT D'URGENCE ──────────────────────────────────────────
          _buildEmergencyBanner(ble),
          const SizedBox(height: 8),

          // ─── BLOC TÉLÉMÉTRIE COMPACT HAUTE LISIBILITÉ ─────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3A506B)),
            ),
            child: Row(
              children: [
                // Jauge Watts Géante
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(
                      color: powerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: powerColor, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("PUISSANCE", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "${ble.powerWatts}",
                            style: TextStyle(color: powerColor, fontSize: 44, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const Text("WATTS", style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Cadence, Cardio, Vitesse
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildMiniMetric(Icons.sync, const Color(0xFF38BDF8), "Cadence", "${ble.cadenceRpm.toStringAsFixed(0)} RPM"),
                      const SizedBox(height: 4),
                      _buildMiniMetric(Icons.favorite, const Color(0xFFF43F5E), "Cardio", ble.heartRateBpm != null ? "${ble.heartRateBpm} BPM" : "--"),
                      const SizedBox(height: 4),
                      _buildMiniMetric(Icons.speed, const Color(0xFFA855F7), "Vitesse", "${ble.speedKmh.toStringAsFixed(1)} km/h"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── MODULE ZWIFT COG & SHIFTING VIRTUEL ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TRANSMISSION VIRTUELLE — ZWIFT COG",
                      style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    Text(
                      "Frein: ${ble.directResistancePercent}%",
                      style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Bouton Souple
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.arrow_downward, size: 20),
                        label: const Text("SOUPLE\n(Côte)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => ble.shiftDown(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Indicateur Rapport
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B132B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Column(
                          children: [
                            const Text("VITESSE", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.bold)),
                            Text(
                              "${ble.currentVirtualGear}/24",
                              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            Text("Ratio ${ble.currentGearRatio.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white70, fontSize: 9)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Bouton Dur
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.arrow_upward, size: 20),
                        label: const Text("DUR\n(Plat)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => ble.shiftUp(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── TESTS DE RÉSISTANCE RAPIDES ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF3A506B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "TEST DE FREINAGE PHYSIQUE DIRECT (Opcode 0x04)",
                  style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildPillBtn(ble, "20%", () => ble.setDirectResistance(20), ble.targetPowerWatts == 0 && ble.simulatedSlopePercent == 0.0 && ble.directResistancePercent == 20),
                    const SizedBox(width: 6),
                    _buildPillBtn(ble, "40%", () => ble.setDirectResistance(40), ble.targetPowerWatts == 0 && ble.simulatedSlopePercent == 0.0 && ble.directResistancePercent == 40),
                    const SizedBox(width: 6),
                    _buildPillBtn(ble, "60%", () => ble.setDirectResistance(60), ble.targetPowerWatts == 0 && ble.simulatedSlopePercent == 0.0 && ble.directResistancePercent == 60),
                    const SizedBox(width: 6),
                    _buildPillBtn(ble, "80%", () => ble.setDirectResistance(80), ble.targetPowerWatts == 0 && ble.simulatedSlopePercent == 0.0 && ble.directResistancePercent == 80),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "MODE ERG — PUISSANCE CIBLE (Opcode 0x05)",
                  style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildPillBtn(ble, "100W", () => ble.setTargetPower(100), ble.targetPowerWatts == 100),
                    const SizedBox(width: 6),
                    _buildPillBtn(ble, "130W", () => ble.setTargetPower(130), ble.targetPowerWatts == 130),
                    const SizedBox(width: 6),
                    _buildPillBtn(ble, "160W", () => ble.setTargetPower(160), ble.targetPowerWatts == 160),
                    const SizedBox(width: 6),
                    _buildPillBtn(ble, "200W", () => ble.setTargetPower(200), ble.targetPowerWatts == 200),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "SIMULATION DE PENTE (Opcode 0x11)",
                  style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildPillBtn(ble, "Plat 0%", () => ble.setSimulatedSlope(0.0), ble.simulatedSlopePercent == 0.0 && ble.targetPowerWatts == 0),
                    const SizedBox(width: 6),
                    _buildPillBtn(ble, "Côte +3%", () => ble.setSimulatedSlope(3.0), ble.simulatedSlopePercent == 3.0),
                    const SizedBox(width: 6),
                    _buildPillBtn(ble, "Col +6%", () => ble.setSimulatedSlope(6.0), ble.simulatedSlopePercent == 6.0),
                    const SizedBox(width: 6),
                    _buildPillBtn(ble, "Mur +9%", () => ble.setSimulatedSlope(9.0), ble.simulatedSlopePercent == 9.0),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ],
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPillBtn(BleSensorProvider ble, String label, VoidCallback onPressed, bool isSelected) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          foregroundColor: isSelected ? Colors.white : const Color(0xFF38BDF8),
          side: BorderSide(color: isSelected ? Colors.white : const Color(0xFF0284C7)),
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: ble.connectedTrainer != null ? onPressed : null,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    );
  }

  Widget _buildEmergencyBanner(BleSensorProvider ble) {
    if (ble.isEmergencyStopped) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Icon(Icons.warning, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text("ARRÊT D'URGENCE ACTIF (Roue libre)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
              onPressed: () => ble.resetEmergencyStop(),
              child: const Text("Réarmer", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.stop_circle, size: 18),
      label: const Text("ARRÊT D'URGENCE (1-TAP)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      onPressed: () => ble.triggerEmergencyStop(),
    );
  }

  // ==============================================================================
  // ONGLET 2 : SCANNER BLUETOOTH
  // ==============================================================================
  Widget _buildScannerTab(BleSensorProvider ble) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("PÉRIPHÉRIQUES DÉTECTÉS", style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: ble.isScanning ? Colors.redAccent : const Color(0xFF0284C7)),
                icon: ble.isScanning
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search, size: 16),
                label: Text(ble.isScanning ? "Arrêter" : "Scanner"),
                onPressed: ble.isScanning ? () => ble.stopScan() : () => ble.startScan(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ble.scanResults.isEmpty
                ? Center(
                    child: Text(
                      ble.isScanning ? "Recherche de votre Zwift Hub..." : "Appuyez sur Scanner pour détecter vos appareils",
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  )
                : ListView.separated(
                    itemCount: ble.scanResults.length,
                    separatorBuilder: (context, index) => const Divider(color: Color(0xFF334155)),
                    itemBuilder: (context, index) {
                      final result = ble.scanResults[index];
                      final name = result.device.platformName.isNotEmpty ? result.device.platformName : "Appareil (${result.device.remoteId})";
                      final isZwift = name.toLowerCase().contains("zwift") || name.toLowerCase().contains("hub");

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isZwift ? Icons.directions_bike : Icons.bluetooth,
                          color: isZwift ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                        ),
                        title: Text(name, style: TextStyle(color: isZwift ? const Color(0xFFF59E0B) : Colors.white, fontWeight: isZwift ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text("ID: ${result.device.remoteId} | ${result.rssi} dBm", style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                              onPressed: () {
                                ble.connectTrainer(result.device);
                                _tabController.animateTo(0); // Basculer automatiquement sur le cockpit
                              },
                              child: const Text("Trainer", style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF43F5E), side: const BorderSide(color: Color(0xFFF43F5E)), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                              onPressed: () => ble.connectHeartRate(result.device),
                              child: const Text("Cardio", style: TextStyle(fontSize: 12)),
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
  }

  // ==============================================================================
  // ONGLET 3 : DIAGNOSTIC & CONSOLE DE LOGS
  // ==============================================================================
  Widget _buildDiagnosticTab(BleSensorProvider ble) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("LOGS TECHNIQUES BLE & FTMS", style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF38BDF8)),
                tooltip: "Forcer Request Control",
                onPressed: ble.connectedTrainer != null ? () => ble.requestTrainerControl() : null,
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E293B)),
          Expanded(
            child: ListView.builder(
              itemCount: ble.logs.length,
              itemBuilder: (context, index) {
                final log = ble.logs[index];
                Color logColor = const Color(0xFF94A3B8);
                if (log.contains("✅") || log.contains("🎉")) logColor = const Color(0xFF34D399);
                if (log.contains("❌") || log.contains("🛑")) logColor = const Color(0xFFF87171);
                if (log.contains("⚠️")) logColor = const Color(0xFFFBBF24);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    log,
                    style: TextStyle(color: logColor, fontSize: 11, fontFamily: 'monospace'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

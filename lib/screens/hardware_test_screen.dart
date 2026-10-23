import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_sensor_provider.dart';

class HardwareTestScreen extends StatefulWidget {
  const HardwareTestScreen({super.key});

  @override
  State<HardwareTestScreen> createState() => _HardwareTestScreenState();
}

class _HardwareTestScreenState extends State<HardwareTestScreen> {
  Color _getPowerZoneColor(int watts) {
    if (watts < 120) return const Color(0xFF64748B); // Z1 Récupération (Gris ardoise)
    if (watts < 170) return const Color(0xFF0284C7); // Z2 Endurance (Bleu ciel)
    if (watts < 220) return const Color(0xFF16A34A); // Z3 Tempo (Vert vif)
    if (watts < 270) return const Color(0xFFEAB308); // Z4 Seuil (Jaune or)
    if (watts < 320) return const Color(0xFFEA580C); // Z5 PMA (Orange vif)
    return const Color(0xFFDC2626); // Z6/Z7 Anaérobie (Rouge écarlate)
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleSensorProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        title: Row(
          children: [
            const Icon(Icons.bolt, color: Color(0xFF38BDF8), size: 28),
            const SizedBox(width: 8),
            const Text(
              "Fogcycling — Banc d'Essai Phase 1",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (ble.connectedTrainer != null || ble.connectedHeartRateDevice != null)
            IconButton(
              icon: const Icon(Icons.link_off, color: Colors.redAccent),
              tooltip: "Déconnecter tout",
              onPressed: () => ble.disconnectAll(),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── BANDEAU ARRÊT D'URGENCE ──────────────────────────────────────────
              _buildEmergencyStopBanner(ble),
              const SizedBox(height: 16),

              // ─── TÉLÉMÉTRIE EN TEMPS RÉEL (HUD) ──────────────────────────────────
              _buildTelemetryHUD(ble),
              const SizedBox(height: 16),

              // ─── MODULE SHIFTING VIRTUEL (ZWIFT COG) ─────────────────────────────
              _buildVirtualShiftingCard(ble),
              const SizedBox(height: 16),

              // ─── CONTRÔLE DE RÉSISTANCE (MODE ERG & PENTE) ───────────────────────
              _buildResistanceControlCard(ble),
              const SizedBox(height: 16),

              // ─── SCANNER BLUETOOTH ───────────────────────────────────────────────
              _buildScannerCard(ble),
              const SizedBox(height: 16),

              // ─── CONSOLE DE LOGS EN DIRECT ───────────────────────────────────────
              _buildDebugConsole(ble),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BANDEAU D'ARRÊT D'URGENCE ─────────────────────────────────────────────
  Widget _buildEmergencyStopBanner(BleSensorProvider ble) {
    if (ble.isEmergencyStopped) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 36),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "ARRÊT D'URGENCE ACTIF !\nTrainer débrayé en roue libre.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: () => ble.resetEmergencyStop(),
              child: const Text("Réarmer"),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      icon: const Icon(Icons.stop_circle, size: 28),
      label: const Text(
        "ARRÊT D'URGENCE (1-TAP)",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
      onPressed: () => ble.triggerEmergencyStop(),
    );
  }

  // ─── TÉLÉMÉTRIE HUD ────────────────────────────────────────────────────────
  Widget _buildTelemetryHUD(BleSensorProvider ble) {
    final powerColor = _getPowerZoneColor(ble.powerWatts);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A506B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TÉLÉMÉTRIE EN DIRECT",
                style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
              ),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: ble.connectedTrainer != null ? const Color(0xFF22C55E) : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ble.connectedTrainer != null ? "Trainer Connecté" : "Hors ligne",
                    style: TextStyle(
                      color: ble.connectedTrainer != null ? const Color(0xFF22C55E) : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Jauge Puissance (Watts)
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: powerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: powerColor, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text("PUISSANCE", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        "${ble.powerWatts}",
                        style: TextStyle(color: powerColor, fontSize: 48, fontWeight: FontWeight.w900),
                      ),
                      const Text("WATTS", style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Cadence, Cardio & Vitesse
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    // Cadence (RPM)
                    _buildMetricRow(
                      icon: Icons.sync,
                      iconColor: const Color(0xFF38BDF8),
                      label: "Cadence",
                      value: "${ble.cadenceRpm.toStringAsFixed(0)} RPM",
                    ),
                    const SizedBox(height: 8),
                    // Cardio (BPM)
                    _buildMetricRow(
                      icon: Icons.favorite,
                      iconColor: const Color(0xFFF43F5E),
                      label: "Fréquence Cardiaque",
                      value: ble.heartRateBpm != null ? "${ble.heartRateBpm} BPM" : "-- BPM",
                    ),
                    const SizedBox(height: 8),
                    // Vitesse
                    _buildMetricRow(
                      icon: Icons.speed,
                      iconColor: const Color(0xFFA855F7),
                      label: "Vitesse Calculée",
                      value: "${ble.speedKmh.toStringAsFixed(1)} km/h",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3A506B)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  // ─── MODULE CHANGEMENT DE BRAQUET VIRTUEL (ZWIFT COG) ───────────────────────
  Widget _buildVirtualShiftingCard(BleSensorProvider ble) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.settings, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 8),
              Text(
                "TRANSMISSION VIRTUELLE — ZWIFT COG",
                style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Pignon unique 14T physique : la démultiplication est gérée à 100% par l'application.",
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Bouton descendre vitesse (plus souple)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_downward, size: 24),
                  label: const Text("SOUPLE\n(Côte)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => ble.shiftDown(),
                ),
              ),
              const SizedBox(width: 16),
              // Indicateur de vitesse
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B132B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                ),
                child: Column(
                  children: [
                    const Text("RAPPORT", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                    Text(
                      "${ble.currentVirtualGear} / ${ble.totalVirtualGears}",
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      "Ratio: ${ble.currentGearRatio.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Bouton monter vitesse (plus dur)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_upward, size: 24),
                  label: const Text("DUR\n(Plat)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => ble.shiftUp(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── CONTRÔLE DE RÉSISTANCE (MODE ERG & PENTE) ─────────────────────────────
  Widget _buildResistanceControlCard(BleSensorProvider ble) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A506B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TEST DE RÉSISTANCE PHYSIQUE",
                style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
              ),
              if (!ble.hasTrainerControl)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text("Prendre Contrôle"),
                  onPressed: ble.connectedTrainer != null ? () => ble.requestTrainerControl() : null,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF065F46),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text("Contrôle Actif (FTMS)", style: TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text("Mode ERG (Watts cibles avec rampe sécurisée max 20W/s) :", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPowerTargetBtn(ble, 100),
              const SizedBox(width: 8),
              _buildPowerTargetBtn(ble, 130),
              const SizedBox(width: 8),
              _buildPowerTargetBtn(ble, 160),
              const SizedBox(width: 8),
              _buildPowerTargetBtn(ble, 200),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Mode Simulation de Pente :", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildSlopeTargetBtn(ble, 0.0),
              const SizedBox(width: 8),
              _buildSlopeTargetBtn(ble, 3.0),
              const SizedBox(width: 8),
              _buildSlopeTargetBtn(ble, 6.0),
              const SizedBox(width: 8),
              _buildSlopeTargetBtn(ble, 9.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerTargetBtn(BleSensorProvider ble, int watts) {
    final isSelected = ble.targetPowerWatts == watts;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
          foregroundColor: isSelected ? Colors.white : const Color(0xFF38BDF8),
          side: const BorderSide(color: Color(0xFF0284C7)),
        ),
        onPressed: ble.hasTrainerControl ? () => ble.setTargetPower(watts) : null,
        child: Text("${watts}W", style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSlopeTargetBtn(BleSensorProvider ble, double slope) {
    final isSelected = ble.simulatedSlopePercent == slope;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFFF59E0B) : Colors.transparent,
          foregroundColor: isSelected ? Colors.white : const Color(0xFFF59E0B),
          side: const BorderSide(color: Color(0xFFF59E0B)),
        ),
        onPressed: ble.hasTrainerControl ? () => ble.setSimulatedSlope(slope) : null,
        child: Text("${slope.toStringAsFixed(0)}%", style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── SCANNER BLUETOOTH ─────────────────────────────────────────────────────
  Widget _buildScannerCard(BleSensorProvider ble) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A506B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "PÉRIPHÉRIQUES BLUETOOTH DÉTECTÉS",
                style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ble.isScanning ? Colors.redAccent : const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
                icon: ble.isScanning
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search, size: 18),
                label: Text(ble.isScanning ? "Arrêter" : "Scanner"),
                onPressed: ble.isScanning ? () => ble.stopScan() : () => ble.startScan(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (ble.scanResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  ble.isScanning ? "Recherche de votre Zwift Hub et capteurs en cours..." : "Appuyez sur Scanner pour détecter vos équipements",
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ble.scanResults.length,
              separatorBuilder: (context, index) => const Divider(color: Color(0xFF334155)),
              itemBuilder: (context, index) {
                final result = ble.scanResults[index];
                final name = result.device.platformName.isNotEmpty ? result.device.platformName : "Appareil sans nom (${result.device.remoteId})";
                final isZwift = name.toLowerCase().contains("zwift") || name.toLowerCase().contains("hub");

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isZwift ? Icons.directions_bike : Icons.bluetooth,
                    color: isZwift ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      color: isZwift ? const Color(0xFFF59E0B) : Colors.white,
                      fontWeight: isZwift ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    "ID: ${result.device.remoteId} | RSSI: ${result.rssi} dBm",
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                        onPressed: () => ble.connectTrainer(result.device),
                        child: const Text("Trainer"),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF43F5E), side: const BorderSide(color: Color(0xFFF43F5E))),
                        onPressed: () => ble.connectHeartRate(result.device),
                        child: const Text("Cardio"),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── CONSOLE DE DÉBOGAGE EN DIRECT ─────────────────────────────────────────
  Widget _buildDebugConsole(BleSensorProvider ble) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF020617),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "JOURNAL TECHNIQUE GATT / ÉVÉNEMENTS BLE",
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              Icon(Icons.terminal, color: Color(0xFF64748B), size: 16),
            ],
          ),
          const Divider(color: Color(0xFF1E293B)),
          Expanded(
            child: ListView.builder(
              itemCount: ble.logs.length,
              itemBuilder: (context, index) {
                return Text(
                  ble.logs[index],
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontFamily: 'monospace',
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

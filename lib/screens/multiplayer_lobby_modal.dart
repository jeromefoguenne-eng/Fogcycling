import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/multiplayer/multiplayer_models.dart';
import '../core/routes/mythical_routes.dart';
import '../providers/ble_sensor_provider.dart';
import '../providers/career_race_provider.dart';
import '../providers/multiplayer_provider.dart';

/// Fenêtre modale de la Phase 6 — Multijoueur en Ligne, Salons Live, Classement W/kg & Ride On !
class MultiplayerLobbyModal extends StatefulWidget {
  const MultiplayerLobbyModal({super.key});

  @override
  State<MultiplayerLobbyModal> createState() => _MultiplayerLobbyModalState();
}

class _MultiplayerLobbyModalState extends State<MultiplayerLobbyModal> {
  final TextEditingController _roomTitleController =
      TextEditingController(text: "Sortie Club Fogcycling");
  final TextEditingController _pinCodeController =
      TextEditingController(text: "2026");
  final TextEditingController _wsUrlController =
      TextEditingController(text: "ws://192.168.1.100:2567");

  MythicalRoute _selectedRouteForPrivateRoom = MythicalRoutesCatalog.routes.first;

  @override
  void dispose() {
    _roomTitleController.dispose();
    _pinCodeController.dispose();
    _wsUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<MultiplayerProvider, CareerRaceProvider, BleSensorProvider>(
      builder: (context, mp, career, ble, _) {
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
                    // En-tête avec statut réseau, ping et compteur Ride On !
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            "🌐 MULTIJOUEUR EN LIGNE & SALONS LIVE",
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_tethering, color: Colors.greenAccent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "${mp.networkPingMs}ms • 👍 ${mp.rideOnsReceivedCount}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Bandeau Salon Actif
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "📡 Salon actif : ${mp.activeRoom.title}",
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "Rang ${mp.playerRankInRoom}/${mp.roomRiders.length}",
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Barre d'interactions rapides 1-Clic ("Ride On !", "Relais", "Attaque")
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: LiveRaceEmote.values.map((emote) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: emote.badgeColor.withValues(alpha: 0.2),
                                foregroundColor: emote.badgeColor,
                                side: BorderSide(color: emote.badgeColor),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => mp.sendLiveEmote(emote),
                              child: Text(
                                emote.label,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const TabBar(
                      indicatorColor: Colors.amberAccent,
                      labelColor: Colors.amberAccent,
                      unselectedLabelColor: Colors.white60,
                      labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                      tabs: [
                        Tab(text: "CLASSEMENT LIVE"),
                        Tab(text: "SALONS PUBLICS"),
                        Tab(text: "SALON PRIVÉ & WS"),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Expanded(
                      child: TabBarView(
                        children: [
                          // ─── ONGLET 1 : CLASSEMENT LIVE (W/KG & ÉCARTS) + CHAT RAPIDE ───
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: ListView.builder(
                                  controller: scrollController,
                                  itemCount: mp.roomRiders.length,
                                  itemBuilder: (ctx, i) {
                                    final r = mp.roomRiders[i];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: r.isPlayer
                                            ? const Color(0xFF1E3A8A)
                                            : const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: r.isAttacking
                                              ? Colors.redAccent
                                              : (r.isPlayer ? Colors.amberAccent : Colors.white12),
                                          width: r.isPlayer || r.isAttacking ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Position
                                          SizedBox(
                                            width: 24,
                                            child: Text(
                                              "${i + 1}.",
                                              style: TextStyle(
                                                color: i == 0 ? Colors.yellowAccent : Colors.white70,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          // Nom + Drapeau + Club + Emote active
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        "${r.countryFlag} ${r.displayName} [${r.clubTag}]",
                                                        style: TextStyle(
                                                          color: r.isPlayer ? Colors.amberAccent : Colors.white,
                                                          fontWeight: FontWeight.w900,
                                                          fontSize: 12,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (r.isAttacking) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.redAccent,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: const Text(
                                                          "⚡ ATTAQUE",
                                                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                                                        ),
                                                      ),
                                                    ],
                                                    if (r.activeEmote != null) ...[
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        r.activeEmote!.label,
                                                        style: TextStyle(
                                                          color: r.activeEmote!.badgeColor,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                Text(
                                                  "${r.speedKmh.toStringAsFixed(1)} km/h • ${r.cadenceRpm} RPM • ${(r.distanceMeters / 1000).toStringAsFixed(2)} km",
                                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Watts & W/kg
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                "${r.wattsPerKg} W/kg",
                                                style: TextStyle(
                                                  color: r.wattsPerKg >= 3.5 ? Colors.orangeAccent : Colors.cyanAccent,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                "${r.currentWatts} W",
                                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 12),
                                          // Écart chronométrique
                                          Container(
                                            width: 52,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              r.formattedGap,
                                              style: TextStyle(
                                                color: r.isPlayer
                                                    ? Colors.amberAccent
                                                    : (r.gapSecondsToPlayer < 0 ? Colors.redAccent : Colors.greenAccent),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(color: Colors.white24, height: 12),
                              const Text(
                                "💬 FIL D'ACTIVITÉ & RÉACTIONS EN DIRECT",
                                style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0B132B),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: ListView.builder(
                                    itemCount: mp.liveFeed.length,
                                    itemBuilder: (ctx, idx) {
                                      final msg = mp.liveFeed[idx];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(fontSize: 11),
                                            children: [
                                              TextSpan(
                                                text: "${msg.countryFlag} ${msg.senderName} : ",
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                              TextSpan(
                                                text: msg.message,
                                                style: TextStyle(color: msg.accentColor),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ─── ONGLET 2 : SALONS PUBLICS EN LIGNE ───
                          ListView.builder(
                            itemCount: mp.availableRooms.length,
                            itemBuilder: (ctx, idx) {
                              final room = mp.availableRooms[idx];
                              final isCurrent = mp.activeRoom.roomId == room.roomId;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCurrent ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isCurrent ? Colors.amberAccent : Colors.white12,
                                    width: isCurrent ? 2 : 1,
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
                                            room.title,
                                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            "👥 ${room.onlineRidersCount} en ligne",
                                            style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${room.eventType.label} • Allure cible : ${room.targetPaceWkgMin}-${room.targetPaceWkgMax} W/kg",
                                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isCurrent ? Colors.greenAccent : Colors.amberAccent,
                                          foregroundColor: Colors.black,
                                        ),
                                        icon: Icon(isCurrent ? Icons.check_circle : Icons.login, size: 16),
                                        label: Text(
                                          isCurrent ? "SALON ACTUELLEMENT REJOINT" : "REJOINDRE CE SALON EN DIRECT",
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                        ),
                                        onPressed: () {
                                          mp.joinLobbyRoom(room, careerProv: career, bleProv: ble);
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // ─── ONGLET 3 : CRÉER UN SALON PRIVÉ (CODE PIN) & SERVEUR WEBSOCKET ───
                          ListView(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "🔒 CRÉER UN SALON PRIVÉ ENTRE AMIS (CODE PIN)",
                                      style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _roomTitleController,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: const InputDecoration(
                                        labelText: "Nom du Salon Privé",
                                        labelStyle: TextStyle(color: Colors.white70),
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<MythicalRoute>(
                                      initialValue: _selectedRouteForPrivateRoom,
                                      dropdownColor: const Color(0xFF0F172A),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      decoration: const InputDecoration(
                                        labelText: "Col / Parcours du Salon",
                                        labelStyle: TextStyle(color: Colors.white70),
                                        isDense: true,
                                      ),
                                      items: MythicalRoutesCatalog.routes.map((r) {
                                        return DropdownMenuItem(
                                          value: r,
                                          child: Text("${r.countryFlag} ${r.name} (${r.distanceKm} km)"),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _selectedRouteForPrivateRoom = val);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _pinCodeController,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        labelText: "Code PIN d'accès (4 chiffres)",
                                        labelStyle: TextStyle(color: Colors.white70),
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amberAccent,
                                          foregroundColor: Colors.black,
                                        ),
                                        icon: const Icon(Icons.add_circle_outline, size: 16),
                                        label: const Text(
                                          "CRÉER & LANCER LE SALON PRIVÉ",
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                                        ),
                                        onPressed: () {
                                          mp.createAndJoinPrivateRoom(
                                            roomTitle: _roomTitleController.text,
                                            route: _selectedRouteForPrivateRoom,
                                            pinCode: _pinCodeController.text,
                                            careerProv: career,
                                            bleProv: ble,
                                          );
                                          Navigator.of(context).pop();
                                        },
                                      ),
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
                                  border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "🖧 SERVEUR WEBSOCKET LAN / CLOUD (COLYSEUS / NODE.JS)",
                                      style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w900),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Pour synchroniser plusieurs smartphones sur votre réseau local, lancez `node server/multiplayer_ws_server.js` sur votre PC.",
                                      style: TextStyle(color: Colors.white60, fontSize: 11),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _wsUrlController,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                                      decoration: const InputDecoration(
                                        labelText: "URL Serveur WebSocket",
                                        labelStyle: TextStyle(color: Colors.white70),
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0284C7),
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: const Icon(Icons.sync, size: 16),
                                        label: Text(
                                          mp.isRealWebSocketConnected
                                              ? "CONNECTÉ AU SERVEUR WEBSOCKET"
                                              : "CONNECTER AU SERVEUR WEBSOCKET",
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                                        ),
                                        onPressed: () => mp.connectToWebSocketServer(_wsUrlController.text),
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
}

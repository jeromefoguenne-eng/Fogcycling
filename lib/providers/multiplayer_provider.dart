import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/multiplayer/multiplayer_models.dart';
import '../core/routes/mythical_routes.dart';
import 'ble_sensor_provider.dart';
import 'career_race_provider.dart';

/// Contrôleur de la Phase 6 — Multijoueur Temps Réel, Salons en Ligne & Synchronisation WebSockets
/// Implémente :
/// - Connexion WebSocket temps réel (Colyseus / Node.js WS) avec bascule transparente en Simulation Hybride Live
/// - Salons publics (Group Rides, Courses Cat. B/C, Défis Grimpeur) et Salons Privés par Code PIN à 4 chiffres
/// - Interpolation Dead Reckoning, calcul des écarts chronométriques au centième et W/kg en direct
/// - Système d'interactions rapides ("👍 Ride On !", "🔄 Relais !", "⚡ ATTAQUE !") et fil d'événements live
class MultiplayerProvider extends ChangeNotifier {
  final math.Random _rng = math.Random(42);

  bool _isConnectedToRoom = true;
  bool _isRealWebSocketConnected = false;
  String _serverUrl = "ws://192.168.1.100:2567";
  int _networkPingMs = 24;
  int _rideOnsReceivedCount = 3;

  MultiplayerLobbyRoom _activeRoom = MultiplayerLobbyRoom.defaultPublicRooms.first;
  final List<MultiplayerLobbyRoom> _availableRooms = List.from(MultiplayerLobbyRoom.defaultPublicRooms);
  final List<OnlinePeerRider> _roomRiders = [];
  final List<MultiplayerFeedMessage> _liveFeed = [];

  WebSocket? _wsChannel;
  LiveRaceEmote? _playerActiveEmote;
  int _playerEmoteTimer = 0;

  MultiplayerProvider() {
    _initializeRoomRiders(_activeRoom);
    _addFeedMessage(
      senderName: "Système Live",
      countryFlag: "🌐",
      message: "Connecté au salon '${_activeRoom.title}' (Ping ${_networkPingMs}ms • Dead Reckoning 60 FPS actif).",
      color: Colors.cyanAccent,
    );
  }

  // Getters
  bool get isConnectedToRoom => _isConnectedToRoom;
  bool get isRealWebSocketConnected => _isRealWebSocketConnected;
  String get serverUrl => _serverUrl;
  int get networkPingMs => _networkPingMs;
  int get rideOnsReceivedCount => _rideOnsReceivedCount;
  MultiplayerLobbyRoom get activeRoom => _activeRoom;
  List<MultiplayerLobbyRoom> get availableRooms => List.unmodifiable(_availableRooms);
  List<OnlinePeerRider> get roomRiders => List.unmodifiable(_roomRiders);
  List<MultiplayerFeedMessage> get liveFeed => List.unmodifiable(_liveFeed);
  LiveRaceEmote? get playerActiveEmote => _playerActiveEmote;

  /// Position actuelle du joueur dans le classement temps réel du salon
  int get playerRankInRoom {
    final idx = _roomRiders.indexWhere((r) => r.isPlayer);
    return idx >= 0 ? idx + 1 : 1;
  }

  /// Initialisation des coureurs connectés dans le salon sélectionné
  void _initializeRoomRiders(MultiplayerLobbyRoom room) {
    _roomRiders.clear();

    final baseWatts = ((room.targetPaceWkgMin + room.targetPaceWkgMax) / 2.0 * 71.0).round();

    // Le Joueur (Vous)
    _roomRiders.add(
      OnlinePeerRider(
        riderId: 'player_local',
        displayName: 'Jérôme F. (Vous)',
        countryFlag: '🇧🇪',
        clubTag: 'FOG',
        weightKg: 72.0,
        basePowerWatts: baseWatts,
        jerseyHexColor: 0xFF0284C7,
        bikeHexColor: 0xFFF97316,
        isPlayer: true,
        distanceMeters: 0.0,
        lateralOffsetX: 0.0,
        currentWatts: baseWatts,
      ),
    );

    // Pairs connectés dans le salon
    final peerProfiles = [
      ('peer_1', 'Maxime V.', '🇧🇪', 'LIEGE', 68.0, baseWatts + 12, 0xFFFACC15, 0xFFF8FAFC, 4.5, -0.40),
      ('peer_2', 'Lucas D.', '🇫🇷', 'ALPE', 71.0, baseWatts + 5, 0xFF22C55E, 0xFF38BDF8, 2.2, 0.45),
      ('peer_3', 'Thibaut P.', '🇫🇷', 'FDJ', 65.0, baseWatts + 18, 0xFFEF4444, 0xFFF97316, 8.0, 0.15),
      ('peer_4', 'Wout V.A.', '🇧🇪', 'VISMA', 76.0, baseWatts + 22, 0xFFFACC15, 0xFF0F172A, 11.5, -0.60),
      ('peer_5', 'Matteo T.', '🇮🇹', 'UAE', 69.0, baseWatts - 4, 0xFFF472B6, 0xFFE2E8F0, -3.5, 0.50),
      ('peer_6', 'Lotte K.', '🇧🇪', 'SDW', 61.0, baseWatts - 14, 0xFFA855F7, 0xFF38BDF8, -7.0, -0.35),
      ('peer_7', 'Jonas V.', '🇩🇰', 'VLAB', 60.0, baseWatts + 8, 0xFF0284C7, 0xFFFACC15, 6.0, -0.75),
      ('peer_8', 'Carlos R.', '🇪🇸', 'INEOS', 67.0, baseWatts - 8, 0xFFEF4444, 0xFF0F172A, -12.0, 0.25),
    ];

    for (final p in peerProfiles) {
      _roomRiders.add(
        OnlinePeerRider(
          riderId: p.$1,
          displayName: p.$2,
          countryFlag: p.$3,
          clubTag: p.$4,
          weightKg: p.$5,
          basePowerWatts: p.$6,
          jerseyHexColor: p.$7,
          bikeHexColor: p.$8,
          distanceMeters: p.$9,
          lateralOffsetX: p.$10,
          currentWatts: p.$6,
        ),
      );
    }

    _sortRoomRidersAndComputeGaps(1.5);
  }

  /// Rejoindre un salon public ou privé et synchroniser automatiquement le parcours 3D
  void joinLobbyRoom(
    MultiplayerLobbyRoom room, {
    CareerRaceProvider? careerProv,
    BleSensorProvider? bleProv,
  }) {
    _activeRoom = room;
    _isConnectedToRoom = true;
    _initializeRoomRiders(room);

    if (careerProv != null && bleProv != null) {
      final route = MythicalRoutesCatalog.getById(room.routeId);
      careerProv.selectRoute(route, bleProv);
    }

    _addFeedMessage(
      senderName: "Salon Live",
      countryFlag: room.countryFlag,
      message: "Vous avez rejoint '${room.title}' (${_roomRiders.length} coureurs synchronisés sur ${room.routeName}).",
      color: Colors.amberAccent,
    );
    notifyListeners();
  }

  /// Créer un Salon Privé avec Code PIN à 4 chiffres pour rouler entre amis
  MultiplayerLobbyRoom createAndJoinPrivateRoom({
    required String roomTitle,
    required MythicalRoute route,
    required String pinCode,
    CareerRaceProvider? careerProv,
    BleSensorProvider? bleProv,
  }) {
    final cleanPin = pinCode.trim().isEmpty ? "2026" : pinCode.trim();
    final newRoom = MultiplayerLobbyRoom(
      roomId: 'priv_${DateTime.now().millisecondsSinceEpoch}',
      title: '${route.countryFlag} $roomTitle (PIN: $cleanPin)',
      routeId: route.id,
      routeName: route.name,
      countryFlag: route.countryFlag,
      eventType: MultiplayerEventType.privateRoom,
      onlineRidersCount: 9,
      targetPaceWkgMin: 2.2,
      targetPaceWkgMax: 3.4,
      pinCode: cleanPin,
    );

    _availableRooms.insert(0, newRoom);
    joinLobbyRoom(newRoom, careerProv: careerProv, bleProv: bleProv);
    return newRoom;
  }

  /// Connexion optionnelle à un serveur WebSocket LAN / Cloud (Colyseus ou Node.js WS)
  Future<void> connectToWebSocketServer(String url) async {
    _serverUrl = url.trim();
    try {
      await _wsChannel?.close();
      final ws = await WebSocket.connect(_serverUrl).timeout(const Duration(seconds: 2));
      _wsChannel = ws;
      _isRealWebSocketConnected = true;

      ws.listen(
        (dynamic data) {
          _handleIncomingWebSocketPacket(data.toString());
        },
        onDone: () {
          _isRealWebSocketConnected = false;
          notifyListeners();
        },
        onError: (_) {
          _isRealWebSocketConnected = false;
          notifyListeners();
        },
      );

      _addFeedMessage(
        senderName: "Serveur WebSocket",
        countryFlag: "🟢",
        message: "Connecté au serveur temps réel $_serverUrl !",
        color: Colors.greenAccent,
      );
    } catch (_) {
      _isRealWebSocketConnected = false;
      _addFeedMessage(
        senderName: "Relais Hybride",
        countryFlag: "⚡",
        message: "Serveur $_serverUrl hors ligne — Simulation Réseau Hybride 60 FPS maintenue sans coupure.",
        color: Colors.amberAccent,
      );
    }
    notifyListeners();
  }

  void _handleIncomingWebSocketPacket(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
      if (decoded['type'] == 'rider_sync') {
        final packet = RiderSyncPacket.fromJson(decoded['payload'] as Map<String, dynamic>);
        final existingIdx = _roomRiders.indexWhere((r) => r.riderId == packet.riderId);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (existingIdx >= 0 && !_roomRiders[existingIdx].isPlayer) {
          final r = _roomRiders[existingIdx];
          r.distanceMeters = packet.extrapolateDistanceAt(nowMs);
          r.lateralOffsetX = packet.lateralOffsetX;
          r.speedKmh = packet.speedMps * 3.6;
          r.currentWatts = packet.watts;
          r.cadenceRpm = packet.cadenceRpm;
          r.isAttacking = packet.isAttacking;
        }
      }
    } catch (_) {}
  }

  /// Envoyer une réaction rapide ("👍 Ride On !", "🔄 Relais !", "⚡ ATTAQUE !") au peloton en ligne
  void sendLiveEmote(LiveRaceEmote emote) {
    _playerActiveEmote = emote;
    _playerEmoteTimer = 5;

    final playerIdx = _roomRiders.indexWhere((r) => r.isPlayer);
    if (playerIdx >= 0) {
      _roomRiders[playerIdx].activeEmote = emote;
      _roomRiders[playerIdx].emoteRemainingSeconds = 5;
      if (emote == LiveRaceEmote.attack) {
        _roomRiders[playerIdx].isAttacking = true;
      }
    }

    _addFeedMessage(
      senderName: "Jérôme F. (Vous)",
      countryFlag: "🇧🇪",
      message: emote.label,
      color: emote.badgeColor,
    );

    // Si connecté à un serveur WS, diffuser le paquet
    if (_isRealWebSocketConnected && _wsChannel != null) {
      _wsChannel!.add(jsonEncode({
        'type': 'emote',
        'emote': emote.label,
        'sender': 'Jérôme F.',
      }));
    }

    // Réponse interactive réaliste d'un cycliste du peloton à proximité
    Future.delayed(const Duration(milliseconds: 900), () {
      final peers = _roomRiders.where((r) => !r.isPlayer).toList();
      if (peers.isEmpty) return;
      final responder = peers[_rng.nextInt(peers.length)];

      if (emote == LiveRaceEmote.rideOn) {
        _rideOnsReceivedCount++;
        responder.activeEmote = LiveRaceEmote.rideOn;
        responder.emoteRemainingSeconds = 4;
        _addFeedMessage(
          senderName: "${responder.displayName} [${responder.clubTag}]",
          countryFlag: responder.countryFlag,
          message: "👍 Ride On Jérôme ! Super rythme !",
          color: Colors.cyanAccent,
        );
      } else if (emote == LiveRaceEmote.takePull) {
        responder.activeEmote = LiveRaceEmote.allezAllez;
        responder.emoteRemainingSeconds = 4;
        responder.distanceMeters = _roomRiders.firstWhere((r) => r.isPlayer).distanceMeters + 2.4;
        _addFeedMessage(
          senderName: "${responder.displayName} [${responder.clubTag}]",
          countryFlag: responder.countryFlag,
          message: "🔄 Je prends le relais devant toi (-34% de vent) !",
          color: Colors.amberAccent,
        );
      } else if (emote == LiveRaceEmote.attack) {
        responder.isAttacking = true;
        responder.activeEmote = LiveRaceEmote.attack;
        responder.emoteRemainingSeconds = 4;
        _addFeedMessage(
          senderName: "${responder.displayName} [${responder.clubTag}]",
          countryFlag: responder.countryFlag,
          message: "⚡ Attention, ça attaque fort en tête de groupe !",
          color: Colors.redAccent,
        );
      }
      notifyListeners();
    });

    notifyListeners();
  }

  /// Boucle de synchronisation 1 Hz appelée par l'écran principal de course
  void tickMultiplayer({
    required int playerWatts,
    required double playerCadenceRpm,
    required double playerSpeedKmh,
    required double playerDistanceMeters,
    required double currentSlopePercent,
    int? playerHeartRateBpm,
  }) {
    if (!_isConnectedToRoom || _roomRiders.isEmpty) return;

    // Légère fluctuation réaliste du ping réseau (20ms - 34ms)
    _networkPingMs = 20 + _rng.nextInt(15);

    if (_playerEmoteTimer > 0) {
      _playerEmoteTimer--;
      if (_playerEmoteTimer == 0) {
        _playerActiveEmote = null;
      }
    }

    final isMoving = playerSpeedKmh > 0.5 || playerWatts > 10;
    final slopeFactor = 1.0 + (currentSlopePercent.clamp(0.0, 20.0) * 0.085);

    for (final rider in _roomRiders) {
      if (rider.emoteRemainingSeconds > 0) {
        rider.emoteRemainingSeconds--;
        if (rider.emoteRemainingSeconds == 0) {
          rider.activeEmote = null;
        }
      }

      if (rider.isPlayer) {
        rider.distanceMeters = playerDistanceMeters;
        rider.currentWatts = playerWatts;
        rider.cadenceRpm = playerCadenceRpm.round();
        rider.speedKmh = playerSpeedKmh;
        rider.heartRateBpm = playerHeartRateBpm ?? 145;
        rider.isAttacking = playerWatts >= 270;
      } else if (isMoving) {
        // Simulation réseau Dead Reckoning des coureurs du salon
        final noise = (_rng.nextDouble() - 0.5) * 18.0;
        double rubberBand = 0.0;
        final gapMeters = playerDistanceMeters - rider.distanceMeters;

        // En mode Group Ride, le peloton reste relativement groupé autour de l'allure cible
        if (_activeRoom.eventType == MultiplayerEventType.groupRide) {
          rubberBand = (gapMeters * 1.4).clamp(-22.0, 25.0);
        } else {
          rubberBand = (gapMeters * 0.45).clamp(-15.0, 18.0);
        }

        // Gestion des attaques spontanées en course
        if (_rng.nextDouble() < 0.03) {
          rider.isAttacking = !rider.isAttacking;
          if (rider.isAttacking) {
            rider.activeEmote = LiveRaceEmote.attack;
            rider.emoteRemainingSeconds = 4;
          }
        }

        final attackBonus = rider.isAttacking ? 38.0 : 0.0;
        rider.currentWatts = (rider.basePowerWatts + noise + rubberBand + attackBonus).round().clamp(110, 460);
        rider.cadenceRpm = (84 + (_rng.nextInt(14) - 7)).clamp(65, 112);

        // Effet d'aspiration si le coureur est dans le sillage d'un autre
        final hasDraft = _roomRiders.any((other) {
          if (identical(other, rider)) return false;
          final d = other.distanceMeters - rider.distanceMeters;
          return d > 0.6 && d < 8.5;
        });
        final draftBoost = hasDraft ? 1.12 : 1.0;

        final speedMps = (((rider.currentWatts * draftBoost) / 21.5) / slopeFactor).clamp(2.5, 16.5);
        rider.speedKmh = speedMps * 3.6;
        rider.distanceMeters += speedMps * 1.0;
      }
    }

    final refSpeedMps = math.max(playerSpeedKmh / 3.6, 5.5);
    _sortRoomRidersAndComputeGaps(refSpeedMps);
    notifyListeners();
  }

  void _sortRoomRidersAndComputeGaps(double referenceSpeedMps) {
    _roomRiders.sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters));
    final player = _roomRiders.firstWhere((r) => r.isPlayer, orElse: () => _roomRiders.first);

    for (final r in _roomRiders) {
      if (r.isPlayer) {
        r.gapSecondsToPlayer = 0.0;
      } else {
        // Si r est devant le joueur (r.distance > player.distance), l'écart est négatif (-0:04)
        final deltaMeters = player.distanceMeters - r.distanceMeters;
        r.gapSecondsToPlayer = deltaMeters / math.max(referenceSpeedMps, 4.0);
      }
    }
  }

  /// Génère le tableau JSON des 6 coureurs en ligne les plus proches du joueur
  /// pour affichage temps réel dans le moteur WebGL Three.js (`window.updateMultiplayerRiders`)
  String get relativeRidersJsonFor3d {
    if (_roomRiders.isEmpty) return "[]";
    final player = _roomRiders.firstWhere((r) => r.isPlayer, orElse: () => _roomRiders.first);
    final peers = _roomRiders.where((r) => !r.isPlayer).toList();

    // Trier par proximité avec le joueur pour afficher les coureurs visibles autour de lui
    peers.sort((a, b) =>
        (a.distanceMeters - player.distanceMeters).abs().compareTo((b.distanceMeters - player.distanceMeters).abs()));

    final closest = peers.take(6).map((p) {
      final relZ = (p.distanceMeters - player.distanceMeters).clamp(-14.0, 28.0);
      return {
        'id': p.riderId,
        'name': p.displayName,
        'zOffset': double.parse(relZ.toStringAsFixed(2)),
        'xOffset': double.parse(p.lateralOffsetX.toStringAsFixed(2)),
        'jersey': p.jerseyHexColor & 0xFFFFFF,
        'bike': p.bikeHexColor & 0xFFFFFF,
        'isAttacking': p.isAttacking,
      };
    }).toList();

    return jsonEncode(closest);
  }

  void _addFeedMessage({
    required String senderName,
    required String countryFlag,
    required String message,
    required Color color,
  }) {
    _liveFeed.insert(
      0,
      MultiplayerFeedMessage(
        timestamp: DateTime.now(),
        senderName: senderName,
        countryFlag: countryFlag,
        message: message,
        accentColor: color,
      ),
    );
    if (_liveFeed.length > 25) {
      _liveFeed.removeLast();
    }
  }

  @override
  void dispose() {
    _wsChannel?.close();
    super.dispose();
  }
}

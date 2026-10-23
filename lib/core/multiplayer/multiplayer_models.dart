import 'package:flutter/material.dart';

/// Réactions rapides ("Emotes" / "Ride On!") échangeables en 1 clic dans le peloton multijoueur
enum LiveRaceEmote {
  rideOn("👍 Ride On !", Color(0xFF38BDF8)),
  takePull("🔄 Relais SVP !", Color(0xFFFACC15)),
  attack("⚡ ATTAQUE !", Color(0xFFEF4444)),
  allezAllez("🔥 Allez Allez !", Color(0xFFF97316)),
  thanksWheel("🫡 Merci pr la roue !", Color(0xFF22C55E));

  final String label;
  final Color badgeColor;
  const LiveRaceEmote(this.label, this.badgeColor);
}

/// Type d'événement multijoueur en ligne
enum MultiplayerEventType {
  groupRide("Sortie Groupe (Allure Sociale)"),
  raceCatB("Course Officielle (Cat. B - 2.8 à 3.5 W/kg)"),
  raceCatC("Course Officielle (Cat. C - 2.0 à 2.7 W/kg)"),
  komChallenge("Défi Grimpeur Chrono (GPM)"),
  privateRoom("Salon Privé entre Amis (Code PIN)");

  final String label;
  const MultiplayerEventType(this.label);
}

/// Salon multijoueur en ligne (Lobby Room)
class MultiplayerLobbyRoom {
  final String roomId;
  final String title;
  final String routeId;
  final String routeName;
  final String countryFlag;
  final MultiplayerEventType eventType;
  final int onlineRidersCount;
  final double targetPaceWkgMin;
  final double targetPaceWkgMax;
  final String? pinCode;

  const MultiplayerLobbyRoom({
    required this.roomId,
    required this.title,
    required this.routeId,
    required this.routeName,
    required this.countryFlag,
    required this.eventType,
    required this.onlineRidersCount,
    required this.targetPaceWkgMin,
    required this.targetPaceWkgMax,
    this.pinCode,
  });

  static const List<MultiplayerLobbyRoom> defaultPublicRooms = [
    MultiplayerLobbyRoom(
      roomId: 'room_ardennaise_live',
      title: '🇧🇪 Group Ride Wallonie — Huy & Roche-aux-Faucons',
      routeId: 'mur_de_huy',
      routeName: 'Mur de Huy',
      countryFlag: '🇧🇪',
      eventType: MultiplayerEventType.groupRide,
      onlineRidersCount: 18,
      targetPaceWkgMin: 2.2,
      targetPaceWkgMax: 3.0,
    ),
    MultiplayerLobbyRoom(
      roomId: 'room_ventoux_kom',
      title: '🇫🇷 Défi Grimpeur Géant de Provence (Mont Ventoux)',
      routeId: 'mont_ventoux',
      routeName: 'Mont Ventoux',
      countryFlag: '🇫🇷',
      eventType: MultiplayerEventType.komChallenge,
      onlineRidersCount: 24,
      targetPaceWkgMin: 2.5,
      targetPaceWkgMax: 3.8,
    ),
    MultiplayerLobbyRoom(
      roomId: 'room_flanders_cobbles',
      title: '🇧🇪 Classique des Flandres — Vieux Quaremont & Grammont',
      routeId: 'vieux_quaremont',
      routeName: 'Vieux Quaremont',
      countryFlag: '🇧🇪',
      eventType: MultiplayerEventType.raceCatB,
      onlineRidersCount: 15,
      targetPaceWkgMin: 2.8,
      targetPaceWkgMax: 3.6,
    ),
    MultiplayerLobbyRoom(
      roomId: 'room_poggio_crit',
      title: '🇮🇹 Final Explosif Milan-San Remo (Poggio)',
      routeId: 'poggio_sanremo',
      routeName: 'Poggio di Sanremo',
      countryFlag: '🇮🇹',
      eventType: MultiplayerEventType.raceCatC,
      onlineRidersCount: 12,
      targetPaceWkgMin: 2.0,
      targetPaceWkgMax: 2.8,
    ),
    MultiplayerLobbyRoom(
      roomId: 'room_galibier_hc',
      title: '🇫🇷 Haute Montagne — Col du Galibier 2642m',
      routeId: 'col_du_galibier',
      routeName: 'Col du Galibier',
      countryFlag: '🇫🇷',
      eventType: MultiplayerEventType.raceCatB,
      onlineRidersCount: 9,
      targetPaceWkgMin: 2.6,
      targetPaceWkgMax: 3.5,
    ),
  ];
}

/// Paquet réseau standardisé (WebSockets / Colyseus / Supabase Realtime)
/// avec interpolation cinématique Dead Reckoning à 60 FPS
class RiderSyncPacket {
  final String riderId;
  final String displayName;
  final String countryFlag;
  final String clubTag;
  final double distanceMeters;
  final double lateralOffsetX;
  final double speedMps;
  final int watts;
  final double weightKg;
  final int cadenceRpm;
  final int? heartRateBpm;
  final int jerseyHexColor;
  final int bikeHexColor;
  final bool isAttacking;
  final String? activeEmoteLabel;
  final int timestampMs;

  const RiderSyncPacket({
    required this.riderId,
    required this.displayName,
    required this.countryFlag,
    required this.clubTag,
    required this.distanceMeters,
    required this.lateralOffsetX,
    required this.speedMps,
    required this.watts,
    required this.weightKg,
    required this.cadenceRpm,
    this.heartRateBpm,
    required this.jerseyHexColor,
    required this.bikeHexColor,
    this.isAttacking = false,
    this.activeEmoteLabel,
    required this.timestampMs,
  });

  double get wattsPerKg => weightKg > 0 ? double.parse((watts / weightKg).toStringAsFixed(1)) : 0.0;

  /// Interpolation Dead Reckoning : extrapole la position longitudinale exacte entre 2 trames réseau
  double extrapolateDistanceAt(int currentTimestampMs) {
    final deltaSec = ((currentTimestampMs - timestampMs).clamp(0, 2000)) / 1000.0;
    return distanceMeters + (speedMps * deltaSec);
  }

  Map<String, dynamic> toJson() => {
        'riderId': riderId,
        'displayName': displayName,
        'countryFlag': countryFlag,
        'clubTag': clubTag,
        'distanceMeters': double.parse(distanceMeters.toStringAsFixed(2)),
        'lateralOffsetX': double.parse(lateralOffsetX.toStringAsFixed(2)),
        'speedMps': double.parse(speedMps.toStringAsFixed(2)),
        'watts': watts,
        'weightKg': weightKg,
        'wPerKg': wattsPerKg,
        'cadenceRpm': cadenceRpm,
        'heartRateBpm': heartRateBpm,
        'jerseyHexColor': jerseyHexColor,
        'bikeHexColor': bikeHexColor,
        'isAttacking': isAttacking,
        'activeEmoteLabel': activeEmoteLabel,
        'timestampMs': timestampMs,
      };

  factory RiderSyncPacket.fromJson(Map<String, dynamic> json) {
    return RiderSyncPacket(
      riderId: json['riderId'] as String? ?? 'peer_unknown',
      displayName: json['displayName'] as String? ?? 'Cycliste',
      countryFlag: json['countryFlag'] as String? ?? '🇪🇺',
      clubTag: json['clubTag'] as String? ?? 'FOG',
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      lateralOffsetX: (json['lateralOffsetX'] as num?)?.toDouble() ?? 0.0,
      speedMps: (json['speedMps'] as num?)?.toDouble() ?? 0.0,
      watts: (json['watts'] as num?)?.toInt() ?? 180,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 72.0,
      cadenceRpm: (json['cadenceRpm'] as num?)?.toInt() ?? 85,
      heartRateBpm: (json['heartRateBpm'] as num?)?.toInt(),
      jerseyHexColor: (json['jerseyHexColor'] as num?)?.toInt() ?? 0xFF0284C7,
      bikeHexColor: (json['bikeHexColor'] as num?)?.toInt() ?? 0xFFF97316,
      isAttacking: json['isAttacking'] as bool? ?? false,
      activeEmoteLabel: json['activeEmoteLabel'] as String?,
      timestampMs: (json['timestampMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Cycliste connecté en temps réel dans le salon multijoueur (avec calcul d'écart chronométrique)
class OnlinePeerRider {
  final String riderId;
  final String displayName;
  final String countryFlag;
  final String clubTag;
  final double weightKg;
  final int basePowerWatts;
  final int jerseyHexColor;
  final int bikeHexColor;
  final bool isPlayer;

  double distanceMeters;
  double lateralOffsetX;
  double speedKmh;
  int currentWatts;
  int cadenceRpm;
  int heartRateBpm;
  bool isAttacking;
  LiveRaceEmote? activeEmote;
  int emoteRemainingSeconds;

  /// Écart chronométrique avec le joueur (négatif = devant le joueur, positif = derrière le joueur)
  double gapSecondsToPlayer;

  OnlinePeerRider({
    required this.riderId,
    required this.displayName,
    required this.countryFlag,
    required this.clubTag,
    required this.weightKg,
    required this.basePowerWatts,
    required this.jerseyHexColor,
    required this.bikeHexColor,
    this.isPlayer = false,
    this.distanceMeters = 0.0,
    this.lateralOffsetX = 0.0,
    this.speedKmh = 30.0,
    this.currentWatts = 190,
    this.cadenceRpm = 88,
    this.heartRateBpm = 148,
    this.isAttacking = false,
    this.activeEmote,
    this.emoteRemainingSeconds = 0,
    this.gapSecondsToPlayer = 0.0,
  });

  double get wattsPerKg => weightKg > 0 ? double.parse((currentWatts / weightKg).toStringAsFixed(1)) : 0.0;

  /// Formate l'écart en secondes au format cyclisme TV (ex: "-0:04", "LEADER", "+0:12")
  String get formattedGap {
    if (isPlayer) return "VOUS";
    final absGap = gapSecondsToPlayer.abs();
    if (absGap < 0.6) return "m.t.";
    final sign = gapSecondsToPlayer < 0 ? "-" : "+";
    final mins = absGap ~/ 60;
    final secs = (absGap % 60).round().toString().padLeft(2, '0');
    if (mins > 0) {
      return "$sign$mins:$secs";
    }
    return "${sign}0:$secs";
  }
}

/// Message dans le fil d'activité / chat rapide du salon multijoueur
class MultiplayerFeedMessage {
  final DateTime timestamp;
  final String senderName;
  final String countryFlag;
  final String message;
  final Color accentColor;

  const MultiplayerFeedMessage({
    required this.timestamp,
    required this.senderName,
    required this.countryFlag,
    required this.message,
    required this.accentColor,
  });
}

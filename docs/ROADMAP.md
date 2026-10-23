# Feuille de Route et Plan de Développement Progressif (Roadmap)

Le développement de Fogcycling suit une méthodologie rigoureuse en 8 phases séquentielles. Chaque phase dispose de critères d'acceptation formels et de tests de validation obligatoires avant le passage à la phase suivante.

---

## Phase 1 — Prototype Matériel & Validation Bluetooth (Zwift Hub One) — [VALIDÉ EN PHYSIQUE ✅]
- **Statut** : **100% Validé sur matériel réel le 23/10/2026**.
- **Objectif** : Établir la liaison de contrôle Bluetooth basse énergie fiable entre l'application et le Zwift Hub One (2023) équipé du Zwift Cog, ainsi que le capteur cardio BLE.
- **Résultats obtenus & prouvés** :
  - Connexion BLE FTMS & HRS 100% opérationnelle.
  - Télémétrie en direct validée : Watts (0 à 250W+), Cadence (RPM), Vitesse (km/h).
  - Contrôle effectif du frein validé : Mode direct 20% à 80%, braquets virtuels Cog 1 à 24, simulation de pente 3% à 6%, mode ERG 100W à 200W.
  - Preuves physiques : 9 captures d'écran archivées dans `test/Appli home trainer/`.

---

## Phase 2 — Prototype de Cyclisme & Rendu 3D Stylisé — [IMPLÉMENTÉ & LIVRÉ ✅]
- **Statut** : **Livré dans Fogcycling.apk le 23/10/2026**.
- **Objectif** : Offrir la première expérience visuelle de cyclisme virtuel avec un avatar animé réagissant à l'effort réel.
- **Tâches Clés Réalisées** :
  1. Intégration du moteur 3D Three.js WebGL autonome dans `assets/3d_world/index.html`.
  2. Modélisation de la route alpine sinueuse, sapins low-poly, massifs montagneux et ciel cartoon.
  3. Avatar cycliste cartoon 3D procédural avec cinématique inverse des jambes verrouillée à la cadence réelle du Zwift Hub One.
  4. HUD sportif mobile flottant : Jauge de Watts dynamique avec zones Coggan (Z1 à Z6), Cadence, Cardio, Vitesse, Dénivelé, Chrono et Distance.
  5. Cockpit tactile Zwift Cog au pouce (+/- braquets virtuels 1 à 24) et sélecteur rapide de pentes.
  6. Mode Démo / Simulation intégré pour tester le monde 3D sans être sur le home trainer.
- **Livrable** : `CyclingRideScreen` et APK `Fogcycling.apk` généré et prêt sur le bureau.

---

## Phase 3 — Moteur d'Entraînement Structuré & Résistance Dynamique — [IMPLÉMENTÉ & LIVRÉ ✅]
- **Statut** : **Livré dans Fogcycling.apk le 23/10/2026**.
- **Objectif** : Permettre d'effectuer une séance d'entraînement complète par intervalles en mode ERG et en mode simulation de pente.
- **Tâches Clés Réalisées** :
  1. Création du moteur d'intervalles (`workout_models.dart` & `workout_provider.dart`) avec calcul dynamique des Watts selon la FTP de l'athlète (Échauffement, Sweet Spot, Seuil Z4, Récupération Z1, PMA Z5).
  2. Connexion de l'asservissement automatique du frein FTMS (`setTargetPower`) au franchissement de chaque bloc d'entraînement, sécurisé par le `SafetyLimiter`.
  3. Catalogue de 3 séances Coach Stravos intégrées (dont *Test Express ERG 5 min* pour validation rapide).
  4. Bandeau interactif d'intervalle dans le HUD avec graphe de progression, conseils en direct de Coach Stravos, compte à rebours et boutons saut de bloc (`|<`, `Pause`, `>|`).
  5. Correction géométrique complète des roues 3D (plan YZ avec jantes carbone, moyeux et 12 rayons) et du cadre dans le moteur Three.js v2.0 + portiques lumineux 3D sur la route.

---

## Phase 4 — Parcours Mythiques, Mode Carrière (Grands Tours & Classiques), IA 10 Niveaux & Export Strava — [IMPLÉMENTÉ & LIVRÉ ✅]
- **Statut** : **Livré dans Fogcycling.apk le 23/10/2026**.
- **Objectif** : Permettre de grimper 12 cols et côtes pavées mythiques, disputer des Grands Tours et Classiques avec équipiers et 10 niveaux d'IA, et exporter les sorties vers Strava.
- **Tâches Clés Réalisées** :
  1. Catalogue de **12 Parcours & Cols Mythiques** (`mythical_routes.dart`) avec vraies coordonnées GPS et profils de pente par secteur : *Mont Ventoux, Mur de Huy, La Roche-aux-Faucons, Vieux Quaremont, Mur de Grammont, Galibier, Stelvio, Poggio di Sanremo, Cauberg, Alpe d'Huez, Angliru, Trouée d'Arenberg (Paris-Roubaix)*.
  2. **Mode Carrière Complet** (`races_and_peloton_models.dart` & `career_race_provider.dart`) : 4 Grands Tours par étapes (*Mini Tour de France 10 étapes, Tour de Belgique 6 étapes, Giro 8 étapes, Vuelta 8 étapes*) et 6 Monuments d'environ 1 heure (*Liège-Bastogne-Liège, Tour des Flandres, Milan-San Remo, Paris-Roubaix, Tour de Lombardie, Classique des Alpes*).
  3. **Peloton IA à 10 Niveaux de Difficulté** réglables de **170 W à 260 W** de moyenne par paliers de 10 W.
  4. **3 Équipiers IA, Stratégies de Départ & Ordres Radio en Direct** + **Physique d'Aspiration (Drafting -0% à -40%)** + **Maillots Distinctifs (Jaune, Pois, Vert)**.
  5. **Exportateur Strava (.TCX Garmin enrichi)** (`strava_exporter.dart`) avec trace GPS réelle interpolée sur le col, altitude, Watts, Cadence et BPM.

---

## Phase 5 — Comptes Utilisateurs, Espace Membre, Garage 3D & Espace Administrateur — [IMPLÉMENTÉ & LIVRÉ ✅]
- **Statut** : **Livré dans Fogcycling.apk le 23/10/2026**.
- **Objectif** : Dotée d'une architecture PostgreSQL/Supabase sécurisée (RLS), d'un suivi de charge WKO5, d'un Garage 3D et d'un tableau de bord d'administration protégé par RBAC.
- **Tâches Clés Réalisées** :
  1. Schéma SQL PostgreSQL complet avec **Row Level Security (RLS)** et table immuable `security_audit_logs` (`supabase/schema_rls.sql`).
  2. **Espace Membre & Zones Coggan** (`athlete_profile_models.dart`, `athlete_profile_provider.dart`, `member_and_admin_screen.dart`) : réglage du profil (FTP, Poids, FC Max/Repos), calcul automatique des 7 zones de puissance Dr. Andrew Coggan et W/kg.
  3. **Suivi Physiologique WKO5 & Historique des Sorties** : calcul automatique du NP, IF, TSS et modélisation Banister **CTL (Fitness 42j), ATL (Fatigue 7j) et TSB (Forme du jour)** avec diagnostic automatique de Coach Stravos.
  4. **Garage 3D Interactif** : sélection de 5 cadres carbone (Aero, Montagne, Pavés, CLM) et 6 maillots officiels synchronisés en temps réel avec l'avatar 3D WebGL.
  5. **Espace Administrateur Protégé (RBAC)** : contrôle du plafond matériel `SafetyLimiter`, gestion des comptes et journal d'audit de sécurité horodaté (avec blocage et journalisation `RBAC_DENIED` si rôle non-admin).

---

## Phase 6 — Multijoueur en Ligne & Courses Virtuelles Temps Réel — [IMPLÉMENTÉ & LIVRÉ ✅]
- **Statut** : **Livré dans Fogcycling.apk le 23/10/2026**.
- **Objectif** : Permettre à plusieurs cyclistes de rouler et de concourir simultanément sur le même parcours virtuel avec synchronisation temps réel.
- **Tâches Clés Réalisées** :
  1. Serveur WebSocket temps réel autonome (`server/multiplayer_ws_server.js`) + Client WebSocket avec bascule automatique en **Simulation Réseau Hybride 60 FPS** (`multiplayer_provider.dart`).
  2. Protocole réseau `RiderSyncPacket` avec interpolation cinématique **Dead Reckoning** (`extrapolateDistanceAt`) et synchronisation WebGL 3D (`window.updateMultiplayerRiders`) avec halo lumineux d'attaque au sol.
  3. **5 Salons Publics en Direct** (*Group Ride Wallonie, Défi Grimpeur Ventoux, Classique des Flandres, Poggio Critérium, Galibier HC*) + **Créateur de Salons Privés protégés par Code PIN à 4 chiffres**.
  4. **Classement Temps Réel (W/kg & Écarts chronométriques au centième)** + **Système d'interactions 1-Clic ("👍 Ride On !", "🔄 Relais SVP !", "⚡ ATTAQUE !")** et fil d'activité live (`multiplayer_lobby_modal.dart`).

---

## Phase 7 — Intégration Native de Coach Stravos
- **Objectif** : Brancher le coach IA pour analyser la forme du cycliste et concevoir des entraînements sur mesure exécutables en 1 clic.
- **Tâches Clés** :
  1. Relier le service d'inférence (Groq Llama 3.3 70B / Gemini Flash) avec le profil sportif du cycliste.
  2. Adapter les sorties du coach au format de schéma d'entraînement structuré (`WorkoutDefinition`).
  3. Fournir des débriefings personnalisés post-séance (analyse de l'adhérence aux watts cibles et conseils physiologiques).
- **Livrable** : Recommandation IA transformée en séance exécutable sur le Zwift Hub One.

---

## Phase 8 — Stabilisation, Optimisation Mobile & Déploiement
- **Objectif** : Atteindre un niveau de qualité de production, auditer la sécurité et préparer les packages de distribution.
- **Tâches Clés** :
  1. Profiling des performances graphiques et de la consommation de batterie sur smartphone.
  2. Audit de cybersécurité méthodique selon le framework Cloudflare en 6 phases.
  3. Compilation des bundles de production Android (.apk / .aab) et documentation utilisateur.
- **Livrable** : Version Bêta finale installable prête pour tests utilisateurs réels.

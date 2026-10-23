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

## Phase 3 — Moteur d'Entraînement Structuré & Résistance Dynamique
- **Objectif** : Permettre d'effectuer une séance d'entraînement complète par intervalles en mode ERG et en mode simulation de pente.
- **Tâches Clés** :
  1. Créer le moteur d'exécution d'intervalles (Échauffement, Seuil, Récupération, PMA).
  2. Connecter l'asservissement automatique du frein au franchissement de chaque bloc d'entraînement.
  3. Implémenter les commandes de changement de braquet virtuel pour le Zwift Cog (touches tactiles + / - et raccourcis clavier/gamepad BLE).
- **Livrable** : Séance d'entraînement de 20 minutes exécutable de bout en bout sur le Zwift Hub One.

---

## Phase 4 — Parcours Réels & Modélisation des Côtes
- **Objectif** : Permettre de grimper un col réel célèbre (ex: Alpe d'Huez, Mur de Huy, Mont Ventoux) fidèlement reproduit en dénivelé.
- **Tâches Clés** :
  1. Implémenter l'importateur de traces GPS (fichiers `.gpx`).
  2. Intégrer le calcul altimétrique et le lissage de pente (formule de Haversine + moyennes mobiles).
  3. Construire le générateur procédural de ruban de route 3D suivant le profil altimétrique réel.
  4. Relier la pente du terrain à la consigne de résistance envoyée au Zwift Hub One.
- **Livrable** : Parcours d'une montée réelle jouable avec profil d'élévation dynamique et résistance physique synchronisée.

---

## Phase 5 — Comptes Utilisateurs, Espace Membre & Espace Administrateur
- **Objectif** : Dotée d'une persistance cloud sécurisée, l'application sauvegarde les séances et permet l'administration de la plateforme.
- **Tâches Clés** :
  1. Configurer Supabase (Auth + PostgreSQL + RLS).
  2. Créer l'espace membre (profil, calcul automatique des zones de puissance selon la FTP, historique des sorties).
  3. Développer le tableau de bord d'administration protégé (rôle `admin` vérifié côté serveur).
- **Livrable** : Authentification et synchronisation cloud des activités sportives.

---

## Phase 6 — Multijoueur en Ligne & Courses Virtuelles
- **Objectif** : Permettre à plusieurs cyclistes de rouler et de concourir simultanément sur le même parcours virtuel.
- **Tâches Clés** :
  1. Déployer le serveur multijoueur temps réel Colyseus (WebSockets).
  2. Synchroniser les positions et les avatars dans la scène 3D avec interpolation Dead Reckoning.
  3. Implémenter le classement de course en temps réel (serveur autoritaire) et détection des écarts chronométriques.
- **Livrable** : Course multijoueur testée avec au moins 2 coureurs en réseau local puis en ligne.

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

# Feuille de Route et Plan de Développement Progressif (Roadmap)

Le développement de Fogcycling suit une méthodologie rigoureuse en 8 phases séquentielles. Chaque phase dispose de critères d'acceptation formels et de tests de validation obligatoires avant le passage à la phase suivante.

---

## Phase 1 — Prototype Matériel & Validation Bluetooth (Zwift Hub One)
- **Objectif** : Établir la liaison de contrôle Bluetooth basse énergie fiable entre l'application et le Zwift Hub One (2023) équipé du Zwift Cog, ainsi que le capteur cardio BLE.
- **Tâches Clés** :
  1. Initialiser le squelette de l'application mobile de test.
  2. Implémenter le scanner BLE avec filtre sur le service FTMS (`0x1826`) et HRS (`0x180D`).
  3. Développer le décodeur de trames télémétriques `Indoor Bike Data` (Watts, Cadence, Vitesse).
  4. Implémenter la prise de contrôle (`Request Control`) et l'asservissement en puissance (Mode ERG `Set Target Power`).
  5. Implémenter le contrôleur de sécurité matérielle (rampe max 20W/s et arrêt d'urgence 1-tap).
- **Livrable** : Démonstrateur mobile fonctionnel testé en direct sur le home trainer physique de l'utilisateur.
- **Critère de Sortie de Phase** : Validation physique documentée dans `docs/COMPATIBILITY_MATRIX.md` (puissance lue en direct et résistance ressentie sous la pédale).

---

## Phase 2 — Prototype de Cyclisme & Rendu 3D Stylisé
- **Objectif** : Offrir la première expérience visuelle de cyclisme virtuel avec un avatar animé réagissant à l'effort réel.
- **Tâches Clés** :
  1. Intégrer le viewport 3D stylisé (direction artistique cartoon / low-poly coloré).
  2. Charger le modèle 3D du cycliste et son vélo.
  3. Lier l'animation de pédalage à la cadence réelle reçue du Zwift Hub One.
  4. Générer une première boucle de route 3D avec décors (arbres, relief, ciel animé).
  5. Afficher le HUD sportif superposé (Watts, Cadence, BPM, Vitesse).
- **Livrable** : Scène 3D jouable à 60 FPS sur smartphone pilotée par le pédalage réel.

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

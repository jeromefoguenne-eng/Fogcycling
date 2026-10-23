# Registre des Décisions Architecturales (Architectural Decision Records - ADR)

Ce document consigne de manière formelle et traçable l'ensemble des choix techniques majeurs présidant à la conception de **Fogcycling**.

---

### ADR-001 : Choix du Framework Mobile & Moteur Graphique 3D
- **Date** : 23 Octobre 2026
- **Statut** : **Validé**
- **Contexte** : Le projet nécessite un rendu 3D fluide (60 FPS) de style dessin animé, une gestion Bluetooth BLE temps réel irréprochable (sans latence ni crash de thread) et une intégration directe avec l'IA Coach Stravos déjà codée en Dart/Flutter.
- **Décision** : Retenir **Flutter** pour le socle applicatif mobile, couplé à **`flutter_blue_plus`** pour le sous-système Bluetooth natif et à **Google Filament / SceneView (ou WebGL Three.js ultra-optimisé)** pour le viewport 3D stylisé.
- **Conséquences** :
  - *Positives* : Réutilisation immédiate des modules existants de Coach Stravos, binaire léger (< 25 Mo), stabilité Bluetooth éprouvée, interface HUD sportive ultra-fluide.
  - *Négatives* : Nécessite une optimisation soignée des shaders et des polygones dans Filament/Three.js pour conserver 60 FPS constants sur smartphones d'entrée de gamme.

---

### ADR-002 : Gestion du Changement de Vitesse Virtuel pour le Zwift Cog
- **Date** : 23 Octobre 2026
- **Statut** : **Validé**
- **Contexte** : Le Zwift Hub One 2023 utilise un pignon unique mécanique (Zwift Cog) sans aucun composant électronique. La manette Zwift Click utilise des protocoles fermés.
- **Décision** : Implémenter un **système de braquet virtuel 100% logiciel dans le moteur physique**. Les changements de vitesse sont commandés via deux boutons tactiles à l'écran (+ / -) et supportent nativement toute télécommande Bluetooth standard (profil HID). L'application recalcule instantanément la consigne de pente/résistance équivalente et la transmet au trainer via le protocole standard FTMS `0x2AD9`.
- **Conséquences** :
  - *Positives* : Indépendance technologique totale, fonctionnement garanti sur tout matériel, zéro coût additionnel pour l'utilisateur.
  - *Négatives* : L'utilisateur n'utilise pas la manette physique Zwift Click dans un premier temps (réservée à l'étude passive en Phase 3).

---

### ADR-003 : Fournisseur de Données Cartographiques et d'Altitude
- **Date** : 23 Octobre 2026
- **Statut** : **Validé**
- **Contexte** : L'utilisation de Google Elevation API est juridiquement incompatible avec le rendu 3D dans un moteur tiers et financièrement risquée ($5/1000 requêtes).
- **Décision** : Adopter **OpenStreetMap (OSM)** pour la géométrie des routes et les modèles numériques de terrain publics (**NASA SRTM 30m / Copernicus DEM / Open-Elevation**) pour le profil d'altitude, complétés par l'importation directe de fichiers standards `.gpx`.
- **Conséquences** :
  - *Positives* : Coût d'API nul (0,00 €), aucun risque de suspension juridique par Google, liberté totale de mise en cache et de modélisation 3D du relief.
  - *Négatives* : Nécessite un algorithme de lissage de pente (filtre passe-bas) pour éliminer les micro-artefacts du relief brut.

---

### ADR-004 : Isolation Étéanche de l'IA Coach Stravos
- **Date** : 23 Octobre 2026
- **Statut** : **Validé**
- **Contexte** : Coach Stravos génère des recommandations d'entraînement complexes. Un modèle de langage (LLM) est probabiliste et peut halluciner des valeurs aberrantes ou dangereuses.
- **Décision** : **Interdiction formelle pour le LLM d'adresser des commandes directes au bus Bluetooth ou au pilote FTMS**. L'IA émet uniquement un schéma JSON standardisé (`WorkoutDefinition`). Un validateur matériel déterministe (`WorkoutSafetyValidator`) vérifie les watts cibles, applique une rampe maximale de 20W/s et autorise à tout moment l'interruption par arrêt d'urgence.
- **Conséquences** :
  - *Positives* : Sécurité biomécanique totale du cycliste, aucune hallucination ne peut bloquer le frein du home trainer.
  - *Négatives* : Nécessite une étape de validation formelle des schémas JSON retournés par l'IA.

---

### ADR-005 : Architecture Réseau Multijoueur Autoritaire
- **Date** : 23 Octobre 2026
- **Statut** : **Validé**
- **Contexte** : Les courses virtuelles nécessitent une synchronisation temps réel fluide des positions et une garantie d'équité sportive (anti-triche).
- **Décision** : Adopter **Colyseus** (WebSockets temps réel en Node.js/TypeScript) avec un modèle de **serveur autoritaire**. Le client transmet ses métriques physiques réelles (puissance, cadence, timestamp) et le serveur calcule la progression officielle sur le tracé de course en appliquant les lois physiques du cyclisme.
- **Conséquences** :
  - *Positives* : Triche impossible par simple altération du client mobile, classements officiels certifiés, très faible consommation de bande passante.
  - *Négatives* : Nécessite un algorithme de prédiction côté client (Dead Reckoning) pour afficher les coureurs de manière fluide en cas de gigue réseau.

---

### ADR-006 : Base de Données et Sécurité d'Accès Cloud
- **Date** : 23 Octobre 2026
- **Statut** : **Validé**
- **Contexte** : Stockage sécurisé des profils utilisateurs, séances réalisées (.FIT), statistiques de puissance (PDC, FTP) et espace d'administration.
- **Décision** : Utiliser **Supabase (PostgreSQL managé)** avec authentification JWT et politiques obligatoires **Row Level Security (RLS)** pour chaque table.
- **Conséquences** :
  - *Positives* : Sécurité éprouvée au niveau du moteur de base de données, conformité RGPD native, hébergement gratuit dans les quotas Free Tier.
  - *Négatives* : Requiert une écriture rigoureuse des règles de sécurité SQL RLS.

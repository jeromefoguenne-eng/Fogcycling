# Inventaire des Dépendances, Licences & Modèle Économique Prévisionnel

## 1. Inventaire des Licences Logicielles

L'ensemble de la pile technologique sélectionnée pour Fogcycling repose sur des licences libres et permissives, éliminant tout risque de redevance ou de contamination restrictive (type GPL strict) :

| Composant | Technologie Retenue | Licence | Conformité Commerciale & Distribution |
| :--- | :--- | :--- | :--- |
| **Framework Mobile UI** | Flutter SDK (Google) | BSD 3-Clause | 100% Libre, sans royalties |
| **Sous-système Bluetooth** | `flutter_blue_plus` | BSD 3-Clause | 100% Libre, usage commercial autorisé |
| **Moteur Graphique 3D** | Google Filament / SceneView | Apache 2.0 | 100% Libre, très permissif |
| **Moteur Multijoueur** | Colyseus (Node.js/TypeScript) | MIT | 100% Libre, auto-hébergeable sans coût de licence |
| **Base de Données & Auth** | Supabase (PostgreSQL) | Apache 2.0 / PostgreSQL | 100% Open source, hébergement local ou cloud managé |
| **Parseur GPX / Altimétrie** | `gpx` (Dart package) | MIT | 100% Libre |
| **Modèle IA Coach Stravos** | Groq (Llama 3.3 70B) & Gemini Flash | API Cloud Free Tier | Gratuit dans les quotas alloués |

---

## 2. Analyse Juridique et Financière des Données Cartographiques & Altimétriques

### 2.1 Le Piège Juridique de Google Maps Platform (Elevation API)
L'utilisation de Google Elevation API présente deux obstacles majeurs :
1. **Restrictions contractuelles strictes (CGU Google Maps)** : La section 3.2.4 des conditions de Google interdit formellement de stocker de manière permanente (pre-fetching ou caching au-delà de 30 jours) les données d'élévation, et impose que toute donnée extraite de l'API soit visualisée exclusivement sur une carte Google Maps officielle. Son utilisation pour générer un monde 3D virtuel temps réel dans un moteur de jeu constitue une infraction directe aux CGU.
2. **Coût financier prohibitif** : 5,00 $ par tranche de 1 000 requêtes d'élévation après épuisement du crédit mensuel offert. Pour une trace GPS de 50 km échantillonnée tous les 10 mètres (5 000 points), chaque import de parcours coûterait environ 0,025 $ à 0,05 $.

### 2.2 Solution Recommandée : Données Ouvertes & Gratuites (Conformité 100% Légale)
Fogcycling adopte une architecture de données géographiques 100% libre et souveraine :
1. **Tracés Géographiques** : **OpenStreetMap (OSM)** via l'API Overpass et format standard **GPX** généré par les compteurs vélo (Garmin, Wahoo, Strava). Licence : Open Database License (ODbL) — Utilisation gratuite avec simple mention d'attribution légale.
2. **Données Altimétriques (MNT - Modèle Numérique de Terrain)** :
   - Fichiers **NASA SRTM 30m** ou **Copernicus DEM 30m** (résolution spatiale de 30 mètres à l'échelle du globe). Données publiques gratuites.
   - Serveur d'élévation open-source **Open-Elevation** : API REST auto-hébergeable en conteneur Docker ou interrogeable gratuitement, sans aucune restriction d'affichage ou de mise en cache 3D.

---

## 3. Modèle Économique et Coûts Prévisionnels

### Phase 1 à 4 : Développement, Prototypes & Tests Matériels
- **Dépenses d'Infrastructure** : **0,00 € / mois**.
  - Supabase : Free Tier (jusqu'à 50 000 utilisateurs actifs mensuels, 500 Mo de base relationnelle, 1 Go de stockage).
  - Groq / Gemini API : Free Tier (très largement suffisant pour les tests de génération de séances d'entraînement de Coach Stravos).
  - Git / GitHub : Hébergement du code gratuit sur `jeromefoguenne-eng/Fogcycling`.
  - Machine de build et d'entraînement locale : PC Fixe Windows (GPU RTX 4070 Ti) sans coût cloud.

### Phase 5 à 7 : Bêta Privée & Multijoueur en Ligne (100 - 500 coureurs simultanés)
- **Serveur Multijoueur Colyseus** : ~5,00 € à 10,00 € / mois (VPS Hetzner ou DigitalOcean 2 vCPU / 4 Go RAM suffisant pour orchestrer 500 connexions WebSockets légères à 10 Hz).
- **Supabase Cloud** : 0,00 € (maintien dans le Free Tier) ou 25,00 $ / mois si la base dépasse 500 Mo.
- **Domaine & SSL** : ~12,00 € / an.

### Phase 8 : Distribution Mobile Grand Public
- **Compte Développeur Google Play (Android)** : 25,00 $ (frais unique à vie).
- **Compte Apple Developer Program (iOS)** : 99,00 $ / an (requis uniquement lors du portage iOS).

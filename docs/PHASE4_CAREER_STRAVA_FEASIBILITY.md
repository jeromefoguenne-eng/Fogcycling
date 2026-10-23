# Rapport de Faisabilité Technique — Parcours Mythiques, Mode Carrière (Grands Tours & Classiques), IA Tactique & Synchronisation Strava

**Date** : 23 Octobre 2026  
**Projet** : Fogcycling  
**Statut** : Étude d'architecture préalable aux Phases 4 et 5

---

## 1. Synthèse Exécutive

L'introduction de la synchronisation **Strava**, des **cols et côtes mythiques réels**, d'un **Mode Carrière complet (Grands Tours par étapes & Monuments d'une heure)**, d'un **peloton IA calibré sur 10 niveaux (170W à 260W)** et de la **physique d'aspiration (drafting)** est **100% faisable** au sein de l'architecture Flutter + Three.js actuelle, sans aucun coût d'abonnement cloud obligatoire.

---

## 2. Synchronisation & Visualisation des Sorties sur Strava

### 2.1 Fonctionnement Technique (Comme sur Zwift)
Pour qu'une sortie sur home trainer apparaisse sur Strava avec **une vraie carte GPS**, **le profil d'altitude**, **les Watts**, **la Cadence (RPM)** et **la Fréquence Cardiaque (BPM)**, l'application génère une trace géolocalisée horodatée seconde par seconde.

1. **Projection Virtuelle sur Trace GPS Réelle** :
   - Lorsque le cycliste avance de $d$ mètres dans Fogcycling (calculé par la physique à partir de ses Watts réels), le moteur déplace son curseur de $d$ mètres le long de la polyligne GPS réelle du col ou de la classique (ex: *Mont Ventoux par Bédoin* ou *La Roche-aux-Faucons*).
   - Chaque seconde, un point d'enregistrement (`Trackpoint`) est sauvegardé contenant : `Timestamp UTC`, `Latitude`, `Longitude`, `Altitude (m)`, `Distance (m)`, `Power (Watts)`, `Cadence (RPM)`, `HeartRate (BPM)`.
2. **Double Méthode d'Export Strava** :
   - **Méthode 1 — Upload Direct via API Strava OAuth2 (`POST /api/v3/uploads`)** : L'utilisateur connecte son compte Strava une seule fois. À la fin de la sortie, l'activité est envoyée automatiquement en arrière-plan (titre auto-généré ex: *"Fogcycling - Étape 6 : Mont Ventoux (Maillot Jaune)"*).
   - **Méthode 2 — Export Fichier `.TCX` / `.GPX` Enrichi (Zéro configuration API)** : Génération locale immédiate d'un fichier standard Garmin `.tcx` (Training Center XML incluant les balises `<Watts>`, `<Cadence>`, `<HeartRateBpm>`) partageable en 1 clic depuis le smartphone ou téléchargeable sur Strava.

---

## 3. Modélisation des Cols, Côtes et Secteurs Pavés Mythiques

### 3.1 Architecture de Données Géographiques Légère
Au lieu d'alourdir l'application avec des gigaoctets de tuiles cartographiques, chaque ascension ou classique est encodée sous forme de **Vecteur Topographique Haute Précision** (points kilométriques tous les 100m avec coordonnées GPS réelles, pente exacte en %, type de revêtement et décor 3D associé) :

| Catégorie | Parcours Inclus | Spécificités Physiques & Visuelles 3D |
| :--- | :--- | :--- |
| **Côtes Belges & Ardennaises** | **Mur de Huy** (1.3 km à 9.6%, max 19%), **La Roche-aux-Faucons** (1.3 km à 11%), **Côte de La Redoute** (1.6 km à 9.4%) | Rampes abruptes nécessitant les petits braquets du Zwift Cog ; décors vallonnés mosans et ardennais. |
| **Monts Flandriens & Pavés** | **Mur de Grammont** (9.2%, max 19.8%), **Vieux Quaremont** (2.2 km pavés), **Paterberg** (12.9%, max 20%), **Carrefour de l'Arbre** | **Coefficient de roulement pavé ($C_{rr} = 0.013$)** majorant la résistance ; texture de route pavée en 3D et micro-secousses caméra. |
| **Cols Français Mythiques** | **Mont Ventoux** (21.5 km à 7.5%), **Col du Galibier** (18.1 km à 6.9%, 2642m), **Alpe d'Huez** (13.8 km à 8.1%, 21 virages) | Transition écologique du décor 3D selon l'altitude : forêt jusqu'à 1400m, puis désert de calcaire blanc lunaire au sommet du Ventoux ou neige au Galibier. |
| **Cols Italiens & Espagnols** | **Passo dello Stelvio** (48 lacets, 2758m), **Poggio di Sanremo** (3.7 km à 3.7% + descente), **Muro di Sormano**, **Alto de l'Angliru** (max 23.5%) | Lacets serrés, tunnels alpins et pentes extrêmes. |
| **Classiques Néerlandaises** | **Cauberg** (1.2 km à 5.8%, max 12% - Amstel) | Punch final idéal pour les attaques de puncheurs. |

---

## 4. Courses par Étapes (Grands Tours) & Grandes Classiques (~1h)

### 4.1 Calibrage Temporel Intelligent (« Format Condensé Dynamique »)
Pour permettre de vivre une étape de Grand Tour en **30 min à 1h30** ou une Grande Classique en **~1h00** (soit 25 à 38 km), les longues portions de plaine monotones de 150 km sont condensées pour conserver **100% des moments stratégiques** (Sprints intermédiaires, approche nerveuse des secteurs clés et intégralité des côtes/cols à l'échelle 1:1) :

1. **Mini Tour de France (10 Étapes)** :
   - *Étape 1* : Prologue Contre-la-Montre Individuel (~30 min, vélo CLM sans aspiration).
   - *Étape 2* : Plaine & Bordures vers la Côte d'Opale (~45 min, 2 sprints intermédiaires).
   - *Étape 3* : Enfer des Pavés du Nord - Arenberg & Carrefour de l'Arbre (~55 min).
   - *Étape 4* : Puncheurs en Normandie & Mur de Bretagne (~45 min).
   - *Étape 5* : Vosges - Planche des Belles Filles (~1h00).
   - *Étape 6* : Le Géant de Provence - Ascension complète du **Mont Ventoux** (~1h15-1h30).
   - *Étape 7* : Transition vallonnée et Sprint Massif (~45 min).
   - *Étape 8 (Étape Reine)* : Enchaînement Télégraphe + **Col du Galibier** (~1h30).
   - *Étape 9* : Les 21 Virages de l'**Alpe d'Huez** (~1h00).
   - *Étape 10* : Contre-la-montre / Circuit final des Champs-Élysées (~40 min).
2. **Giro d'Italia (8 Étapes)** : Prologue italien, Strade Bianche, Cipressa & Poggio, Apennins, Muro di Sormano, **Passo dello Stelvio** (Étape Reine), Dolomites, Finale Milan.
3. **Vuelta a España (8 Étapes)** : CLM inaugural, Pays Basque, Mur de Valdepeñas, Lagos de Covadonga, Pyrénées, **Alto de l'Angliru** (Étape Reine), Guadarrama, Madrid.
4. **Tour de Belgique (6 Étapes)** :
   - *Étape 1* : Sprint côtier en Flandre Occidentale (Bordures de vent).
   - *Étape 2* : Ronde van Vlaanderen Stage (**Vieux Quaremont + Paterberg + Mur de Grammont**).
   - *Étape 3* : Contre-la-montre individuel de Namur (Citadelle, ~30 min).
   - *Étape 4* : La Flèche Wallonne (Double ascension du **Mur de Huy**).
   - *Étape 5 (Étape Reine)* : Ardennaise (**Côte de La Redoute + La Roche-aux-Faucons**).
   - *Étape 6* : Circuit royal final à Bruxelles.
5. **Les 6 Grandes Classiques d'Un Jour (~1h00 chacune)** :
   - *Liège-Bastogne-Liège* (Redoute + Roche-aux-Faucons + Saint-Nicolas)
   - *Tour des Flandres* (Koppenberg + Vieux Quaremont + Paterberg + Grammont)
   - *Milan-San Remo* (Capo Berta + Cipressa + Poggio + Descente Via Roma)
   - *Paris-Roubaix* (Troisvilles + Trouée d'Arenberg + Mons-en-Pévèle + Carrefour de l'Arbre + Vélodrome)
   - *Tour de Lombardie* (Madonna del Ghisallo + Muro di Sormano + Civiglio)
   - *La Classique des Alpes* (Col de la Croix de Fer + Alpe d'Huez)

---

## 5. Intelligence Artificielle Adverse (10 Niveaux : 170W à 260W)

### 5.1 Échelle de Difficulté Paramétrable
Le joueur choisit son niveau d'IA avant le départ ou entre deux étapes :
$$\text{Puissance Moyenne IA}(\text{Niveau } N) = 170\text{ W} + (N - 1) \times 10\text{ W} \quad \text{pour } N \in \{1..10\}$$
- **Niveau 1** : `170 W` | **Niveau 2** : `180 W` | **Niveau 3** : `190 W` | **Niveau 4** : `200 W` | **Niveau 5** : `210 W`
- **Niveau 6** : `220 W` | **Niveau 7** : `230 W` | **Niveau 8** : `240 W` | **Niveau 9** : `250 W` | **Niveau 10** : `260 W`

### 5.2 Archétypes et Comportements Tactiques du Peloton (24 Coureurs IA)
Chaque coureur IA possède un **budget énergétique anaérobie ($W'$)** et un **rôle tactique** :
1. **Baroudeurs (3 à 4 coureurs)** : Attaquent dès le départ (+25% de la puissance cible pendant 3 min) pour former l'échappée matinale et disputer les points des sprints intermédiaires et premiers cols.
2. **Équipiers de Peloton (10 coureurs)** : Assurent un tempo régulier en tête de peloton en se relayant toutes les 45 secondes.
3. **Grimpeurs Purs (5 coureurs, 59 kg)** : Restent cachés dans les roues sur le plat, puis haussent le rythme (+15% W/kg) dans les cols répertoriés (Ventoux, Stelvio, Galibier, Redoute) et sprintent aux arches de Grand Prix de la Montagne (GPM).
4. **Sprinteurs & Flandriens (5 coureurs, 76 kg)** : Protégés dans le peloton, ils déclenchent une accélération explosive (220% de leur puissance moyenne pendant 15 secondes) à 300 mètres des **Sprints Intermédiaires** et de la **Ligne d'Arrivée**.

---

## 6. Physique d'Aspiration (Drafting) & Tactique de Course

### 6.1 Modèle Aérodynamique Multi-Coureurs
À chaque cycle (10 Hz), la distance longitudinale ($\Delta z$) et latérale ($\Delta x$) entre le joueur et les coureurs IA situés devant lui est évaluée dans un cône d'aspiration de $1.5\text{ m}$ à $12\text{ m}$ :

$$\text{Gain d'Aspiration } \alpha_{draft} = \sum_{i \in \text{devant}} w_i(d_i) \quad \text{plafonné à } 42\%$$

| Position Tactique du Joueur | Réduction de Traînée ($\alpha_{draft}$) | Puissance Requise à 40 km/h (Plat) | Conséquence Tactique |
| :--- | :---: | :---: | :--- |
| **Seul en échappée ou en tête de peloton ("Nez au vent")** | **0 %** | **~295 W** | Épuisement rapide si l'effort est prolongé ; risque de se faire contrer dans le final. |
| **Dans la roue d'un coureur (File indienne / Échappée à 3)** | **25 %** | **~225 W** | Économie de ~70 Watts à vitesse identique. |
| **Au chaud au cœur du peloton (> 4 coureurs devant)** | **40 %** | **~185 W** | Économie de ~110 Watts ! Permet de récupérer en Z1/Z2 tout en roulant à 40 km/h avant le pied d'un col. |
| **En montée raide (> 7% : Mur de Huy, Ventoux)** | **< 5 %** | Gravité dominante | En côte raide, la vitesse baisse (< 18 km/h), l'aspiration devient négligeable : seul le rapport **Watts/kg** décide de la sélection ! |

---

## 7. Classements Généraux et Maillots Distinctifs

Chaque course par étapes maintient une base de données locale persistante (`StageRaceState`) calculant après chaque étape :
1. 🟡 **Maillot Jaune (Leader au Temps - GC)** : Temps cumulé + bonifications aux arrivées (-10s, -6s, -4s) et aux sprints intermédiaires (-3s, -2s, -1s).
2. 🔴⚪ **Maillot à Pois (Meilleur Grimpeur - KOM)** : Points attribués au passage des arches de côtes/cols répertoriés :
   - *4e Catégorie* (ex: Côte de 1 km à 5%) : 2, 1 pts.
   - *3e Catégorie* (ex: Poggio, Cauberg) : 5, 3, 2, 1 pts.
   - *2e Catégorie* (ex: Mur de Huy, Quaremont) : 10, 8, 6, 4, 2, 1 pts.
   - *1re Catégorie* (ex: Roche-aux-Faucons, Redoute) : 15, 12, 10, 8, 6, 4, 2, 1 pts.
   - *Hors Catégorie (HC)* (ex: Ventoux, Galibier, Stelvio, Angliru) : 25, 20, 16, 14, 12, 10, 8, 6, 4, 2 pts.
3. 🟢 **Maillot Vert (Meilleur Sprinteur - Points)** : Points aux Sprints Intermédiaires (20, 17, 15, 13, 11, 10...) et aux arrivées d'étapes.

---

## 8. Plan de Découpage Technique (Mise à jour de la Roadmap)

Afin de livrer cet ensemble ambitieux de manière propre, modulaire et testée :
- **Phase 4A — Moteur de Parcours Mythiques, Physique de Pente/Pavés & Export Strava (.TCX / API)** :
  - Catalogue des cols et côtes mythiques (Ventoux, Galibier, Stelvio, Mur de Huy, Roche-aux-Faucons, Quaremont, Grammont, Poggio, Cauberg, Angliru).
  - Asservissement automatique du frein du Zwift Hub One à la pente réelle du col et au revêtement (pavés).
  - Enregistreur GPS virtuel et exportateur Strava (`.tcx` enrichi Watts/RPM/BPM + connecteur Strava).
- **Phase 4B — Peloton IA (10 Niveaux 170W-260W), Physique d'Aspiration (Drafting) & Tactique** :
  - Rendu 3D du peloton de coureurs adverses autour du joueur.
  - Calcul temps réel du drafting (-0% à -40% de résistance aérodynamique) avec indicateur tactique HUD ("Plein Vent" vs "Au chaud dans le peloton").
- **Phase 4C — Mode Carrière : Grands Tours (TDF, Giro, Vuelta, Belgique), Classiques & Maillots (Jaune, Pois, Vert)** :
  - Arches 3D de Sprints Intermédiaires (Vertes) et de Grands Prix de la Montagne (À pois).
  - Tableaux de classement général après chaque étape et attribution des maillots distinctifs sur les avatars 3D.

# Audit Technique Préalable — Plateforme Fogcycling

## 1. Contexte et Objectifs du Projet
Le projet **Fogcycling** a pour ambition de concevoir et développer une plateforme mobile indépendante de cyclisme virtuel inspirée des fondamentaux ergonomiques de Zwift et Rouvy, tout en conservant une identité visuelle propre (style cartoon / cel-shaded stylisé), un code source 100% original, une interopérabilité étendue et l'intégration native d'un coach d'entraînement intelligent basé sur l'IA (**Coach Stravos**).

L'équipement matériel de référence de l'utilisateur est le **Zwift Hub One (acheté en 2023)** équipé du pignon unique mécanique **Zwift Cog**.

---

## 2. Audit de l'Environnement et Outils Disponibles
- **Système d'exploitation** : Windows 11 Pro 64-bit.
- **Accélération matérielle** : GPU NVIDIA GeForce RTX 4070 Ti (12 Go VRAM).
- **Outils système installés** :
  - Git version 2.54.0.windows.1.
  - Node.js & npm (supportant `npx`).
  - Python 3.10+ avec support des bibliothèques scientifiques et matérielles.
  - Dépôt GitHub officiel initialisé et synchronisé : `https://github.com/jeromefoguenne-eng/Fogcycling.git`.
  - Codebase existant identifié : `coach-stravos-app` (Flutter / Dart / Firebase / Groq / Gemini / Strava API / Intervals.icu API).

---

## 3. Analyse Approfondie de la Compétence « REA » (Reverse Engineering)

### 3.1 Identification Exacte
- **Nom du Skill** : `reverse-engineer-anything` (sigle officiel : **REA**).
- **Package source & CLI** : `rea-agents@latest` (registre npm) ou invocable via `npx -y rea-agents@latest`.
- **Rôle et Spécialisation** : Outil d'orchestration pour l'inspection passive d'artefacts compilés (APK Android via JADX, binaires natifs via Ghidra/Hopper, paquets Electron/ASAR, archives ZIP/MSIX, firmwares).

### 3.2 Capacités Réelles
- Inspection de structures d'APK Android (`inspect_android_package`) pour étudier les définitions de services GATT, les UUIDs Bluetooth et les structures de trames sérialisées.
- Analyse statique de code client sans exécution arbitraire.
- Analyse passive de traces réseau ou de captures Bluetooth (snoop logs HCI).

### 3.3 Cadre Légal et Déontologique Strict (Droit Européen & FWB)
Conformément à la Directive Européenne 2009/24/CE (Art. 6) transposée dans le Code de droit économique belge et le Code de la propriété intellectuelle :
- **Autorisé** : L'observation, l'étude et le test du fonctionnement d'un logiciel ainsi que la rétro-ingénierie passive des protocoles de communication sont strictement légaux **lorsqu'ils sont indispensables pour obtenir les informations nécessaires à l'interopérabilité d'un programme créé de façon indépendante avec d'autres programmes ou matériels**.
- **Strictement Interdit** :
  1. Toute copie, extraction ou injection d'éléments de code propriétaire de Zwift (shaders, textures, modèles 3D, binaires propriétaires, polices ou marques commerciales).
  2. La distribution d'un logiciel contournant des verrous de DRM ou des protections d'accès à des serveurs payants.
- **Règle d'or Fogcycling** : L'interopérabilité avec le Zwift Hub One repose sur les **standards industriels publics Bluetooth SIG (FTMS, CPS, CSCS, HRS)** et sur la simulation mathématique logicielle, sans aucune dépendance à des éléments protégés de Zwift.

---

## 4. Analyse Technique du Zwift Hub One & Zwift Cog (2023)

### 4.1 Architecture Matérielle du Zwift Hub One
Le Zwift Hub est un smart trainer à transmission directe conçu sur la base matérielle du fabricant australien **JetBlack Volt V2**. Il communique via Bluetooth Low Energy (BLE 5.0) et ANT+ FE-C.

### 4.2 Protocoles Bluetooth Standardisés Supportés
1. **FTMS (Fitness Machine Service - UUID `0x1826`)** :
   - *Fitness Machine Feature* (`0x2ACC`) : Déclare les capacités du trainer (contrôle de résistance, mode simulation, puissance cible, cadence).
   - *Indoor Bike Data* (`0x2AD2`) : Télémétrie en temps réel diffusée à 1-2 Hz : Puissance instantanée (Watts), Vitesse instantanée (km/h), Cadence de pédalage (RPM), Résistance actuelle.
   - *Fitness Machine Control Point* (`0x2AD9`) : Canal de commande bidirectionnel :
     - `0x00` : Request Control (prise de contrôle impérative avant toute commande).
     - `0x01` : Reset.
     - `0x05` : Set Target Power (Mode ERG pour entraînements et intervalles).
     - `0x11` : Set Indoor Bike Simulation Parameters (Mode Simulation de pente avec Wind Speed, Grade en 0.01%, Crr, CdA).
2. **CPS (Cycling Power Service - UUID `0x1818`)** :
   - *Cycling Power Measurement* (`0x2A63`) : Puissance instantanée et balance gauche/droite éventuelle.
3. **HRS (Heart Rate Service - UUID `0x180D`)** :
   - *Heart Rate Measurement* (`0x2A37`) : Fréquence cardiaque mesurée par toute ceinture ou brassard cardio standard (Garmin, Polar, Wahoo, Decathlon).

### 4.3 Le Cas Particulier du Zwift Cog et du Changement de Vitesse Virtuel
- **Nature du Zwift Cog** : Le Cog physique est un pignon unique mécanique de 14 dents fixé sur une cassette factice avec deux flasques de guidage plastique. **Il ne possède aucune puce, aucun capteur ni aucun composant électronique**.
- **Problématique du Virtual Shifting** : Le cycliste ne peut pas changer de vitesse mécaniquement avec son dérailleur. La démultiplication doit être entièrement émulée par voie logicielle ou électronique.
- **La Manette Zwift Click** : Sur l'écosystème Zwift, les changements de vitesse sont commandés par un petit boîtier sans fil (Zwift Click) communiquant en BLE.
- **Solutions Techniques Évaluées pour Fogcycling** :
  1. **Solution Universelle Applicative (Niveau 1 - Implémentation Garantie)** :
     L'application mobile gère une transmission virtuelle complète (ex: 24 vitesses séquentielles de 0.75 à 5.49, simulant un pédalier 50/34 avec cassette 11-34). 
     L'utilisateur change de braquet via :
     - Deux larges boutons tactiles à l'écran (+ / -) facilement accessibles sur support guidon.
     - Toute manette Bluetooth standard (mini-gamepad BLE, télécommande multimédia Bluetooth au guidon à 5 €, ou boutons volume du smartphone).
     Le moteur physique de l'application applique instantanément le braquet virtuel au calcul de force et met à jour dynamiquement la pente équivalente envoyée au Zwift Hub via le protocole standard FTMS `0x2AD9`.
  2. **Solution Rétro-ingénierie Passive du Zwift Click (Niveau 2 - Expérimentale)** :
     Si l'utilisateur possède un Zwift Click physique, l'application scannera ses services GATT BLE. Si les appuis boutons émettent des notifications standard (HID over GATT) ou des opcodes identifiables, ils seront mappés comme raccourcis d'entrée.

---

## 5. Comparaison des Architectures Mobiles et Moteurs 3D

| Critère d'Évaluation | Option A : Unity (C#) | Option B : Godot 4 (GDExtension C++) | Option C : Flutter + SceneView (Google Filament) | Option D : React Native + Three.js |
| :--- | :--- | :--- | :--- | :--- |
| **Fiabilité & Stabilité BLE** | Moyenne (ponts C#/Java instables, latence GC) | Faible à Moyenne (plugins BLE communautaires instables) | **Excellente** (`flutter_blue_plus` SOTA, gestion des threads natifs) | Bonne (`react-native-ble-plx`, bridge JS/natif) |
| **Rendu 3D Mobile** | Très Élevé (URP, lourd) | Élevé (Vulkan/OpenGL, 40 Mo) | **Élevé & Léger** (Filament Google, PBR, 60 FPS garanti) | Moyen (WebGL via WebView ou Expo-GL) |
| **UI Sportive & Tableaux de bord** | Rigide et complexe (uGUI lourd) | Moyenne (Control nodes) | **Native & Exceptionnelle** (Widgets réactifs, 120Hz) | Très bonne (React/Tailwind) |
| **Réutilisation Coach Stravos** | Nulle (réécriture complète) | Nulle (réécriture complète) | **100% Directe** (Codebase Dart/Firebase déjà prêt) | Partielle (réécriture de Dart vers TS) |
| **Poids de l'APK initial** | ~60 - 90 Mo | ~45 - 60 Mo | **~18 - 25 Mo** | ~35 - 50 Mo |
| **Licence & Coût** | Runtime Fee / Licence Pro payante | 100% MIT Libre | **100% BSD / Apache 2.0 Libre** | 100% MIT Libre |

### Arbitrage et Recommandation Technique
L'architecture **Flutter combinée à `flutter_blue_plus` pour le sous-système matériel et à Google Filament / SceneView (ou Three.js WebGL optimisé) pour la vue 3D stylisée** est l'option la plus robuste, la plus économe en ressources, la plus rapide à livrer et la seule offrant une intégration native directe avec les briques déjà existantes de **Coach Stravos**.

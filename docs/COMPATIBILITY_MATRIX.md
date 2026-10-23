# Matrice de Compatibilité Matérielle & Protocoles

> **Règle de Transparence Antigravity** : Un appareil ou une fonctionnalité n'est marqué comme **Validé Physiquement** qu'après un test réel d'appairage et de pilotage sur banc d'essai physique. Dans le cas contraire, son statut est documenté comme *Spécification Théorique Conforme* en attente de validation physique.

---

## 1. Home Trainers Intelligents (Smart Trainers)

| Modèle & Fabricant | Protocoles Déclarés | Puissance (CPS/FTMS) | Cadence | Contrôle Résistance ERG | Simulation de Pente | Shifting Virtuel (Zwift Cog) | Statut de Validation |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Zwift Hub One (2023)** *(Référence projet)* | BLE FTMS (`0x1826`), CPS (`0x1818`), ANT+ FE-C | Oui (FTMS / CPS) | Oui (estimée par volant) | Oui (Opcode `0x05`) | Oui (Opcode `0x11`) | **Oui (via Shifter Virtuel Applicatif)** | **Cible Prioritaire Phase 1 (Banc physique disponible)** |
| **Zwift Hub Classic** | BLE FTMS, CPS, ANT+ FE-C | Oui | Oui | Oui | Oui | Non requis (cassette mécanique) | Conforme aux spécifications FTMS standard |
| **Wahoo KICKR Core / v5 / v6** | BLE FTMS, CPS, ANT+ FE-C, Direct Connect | Oui | Oui | Oui | Oui | Compatible Shifter Virtuel | Conforme aux spécifications FTMS standard |
| **Tacx Neo 2T / Flux 2 / Flux S** | BLE FTMS, CPS, ANT+ FE-C | Oui | Oui | Oui | Oui | Compatible Shifter Virtuel | Conforme aux spécifications FTMS standard |
| **Elite Direto XR / Suito / Justo** | BLE FTMS, CPS, ANT+ FE-C | Oui | Oui | Oui | Oui | Compatible Shifter Virtuel | Conforme aux spécifications FTMS standard |
| **Saris H3** | BLE FTMS, CPS, ANT+ FE-C | Oui | Oui | Oui | Oui | Compatible Shifter Virtuel | Conforme aux spécifications FTMS standard |
| **Van Rysel D100 / D500 (Decathlon)** | BLE FTMS, CPS, CSCS | Oui | Oui | Oui | Oui (pente max limitée sur D100) | Compatible Shifter Virtuel | Conforme aux spécifications FTMS standard |

---

## 2. Capteurs de Fréquence Cardiaque (Moniteurs Cardio)

| Modèle & Fabricant | Profil Bluetooth | Caractéristique Détection | Taux de Rafraîchissement | Statut de Compatibilité |
| :--- | :--- | :--- | :--- | :--- |
| **Polar H10 / H9 / Verity Sense** | Heart Rate Service (`0x180D`) | Heart Rate Measurement (`0x2A37`) | 1 Hz | Conforme standard universel Bluetooth SIG |
| **Garmin HRM-Pro / HRM-Dual** | Heart Rate Service (`0x180D`) | Heart Rate Measurement (`0x2A37`) | 1 Hz | Conforme standard universel Bluetooth SIG |
| **Wahoo TICKR / TICKR X** | Heart Rate Service (`0x180D`) | Heart Rate Measurement (`0x2A37`) | 1 Hz | Conforme standard universel Bluetooth SIG |
| **Decathlon Dual Bluetooth/ANT+** | Heart Rate Service (`0x180D`) | Heart Rate Measurement (`0x2A37`) | 1 Hz | Conforme standard universel Bluetooth SIG |
| **Bracelets & Montres (Apple Watch / Garmin / Coros)** | BLE HRS / Re-diffusion | Heart Rate Measurement (`0x2A37`) | 0.5 - 1 Hz | Compatible si mode "Diffusion FC" activé |

---

## 3. Commandes de Changement de Vitesse Virtuel (Virtual Shifting)

| Dispositif de Commande | Type de Connexion | Précision & Latence | Robustesse | Statut d'Intégration |
| :--- | :--- | :--- | :--- | :--- |
| **Boutons Tactiles HUD (+ / -)** | Écran tactile smartphone | Immédiate (< 16 ms) | Maximale (aucune dépendance matérielle) | **Natif & Garanti 100% opérationnel** |
| **Télécommande Bluetooth multimédia au guidon** | Profil standard HID over GATT | Très faible (~20-50 ms) | Excellente (périphérique universel à 5 €) | **Supporté nativement via HID** |
| **Boutons Volume Smartphone (Hardware)** | Événement système Android/iOS | Immédiate | Haute (si smartphone fixé au guidon) | **Supporté nativement** |
| **Manette Zwift Click propriétaire** | BLE GATT Propriétaire Zwift | Non documentée publiquement | Soumis à reverse-engineering passif | **Recherche exploratoire (Sous réserve de faisabilité légale)** |

---

## 4. Protocole de Test Physique Étape par Étape (Phase 1)

1. **Test 1.1 — Découverte & Scan BLE** :
   - Démarrage du scan Bluetooth via `flutter_blue_plus`.
   - Vérification de l'apparition de l'identifiant public `Zwift Hub` dans le flux d'annonces advertising.
2. **Test 1.2 — Négociation GATT & Découverte des Services** :
   - Établissement de la connexion physique.
   - Inspection exhaustive des UUIDs exposés : confirmation de la présence du service `0x1826` (FTMS) et `0x1818` (CPS).
3. **Test 1.3 — Lecture Télémétrique en Continu (Mode Écoute Seule)** :
   - Souscription aux notifications sur la caractéristique Indoor Bike Data (`0x2AD2`).
   - Pédalage manuel sur le Zwift Cog : affichage en temps réel de la puissance (W) et de la cadence (RPM) sur l'écran de test.
4. **Test 1.4 — Prise de Contrôle Sécurisée (Control Point)** :
   - Émission de l'opcode `0x00` (Request Control) sur la caractéristique `0x2AD9`.
   - Attente de la confirmation de réussite (`Response Code: 0x01 = Success`).
5. **Test 1.5 — Contrôle de Résistance Progressif (Mode ERG)** :
   - Envoi d'une consigne palier : 100 Watts -> 130 Watts -> 100 Watts (rampe douce de 10W/seconde).
   - Validation physique de l'augmentation du frein électromagnétique sous le pédalage.

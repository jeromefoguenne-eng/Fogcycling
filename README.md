# Fogcycling 🚴‍♂️⚡

Plateforme mobile indépendante de cyclisme virtuel avec moteur physique déterministe, rendu 3D stylisé (cartoon) et coach intelligent IA (**Coach Stravos**).

Développé pour garantir une compatibilité et une interopérabilité optimales avec le **Zwift Hub One (acheté en 2023)** équipé du **Zwift Cog**, ainsi qu'avec l'ensemble des smart trainers conformes au standard Bluetooth SIG FTMS (`0x1826`) et CPS (`0x1818`), et les ceintures cardio BLE (`0x180D`).

---

## 📚 Documentation Technique Préalable
Les études d'ingénierie, audits de sécurité et spécifications d'architecture préalables sont disponibles dans le dossier `docs/` :

- [`docs/TECHNICAL_AUDIT.md`](docs/TECHNICAL_AUDIT.md) : Audit technique de faisabilité, analyse REA légale, étude détaillée du Zwift Hub One & Zwift Cog, comparaison comparative des moteurs 3D.
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) : Architecture globale modulaire (10 briques), flux de données et moteur physique mathématique.
- [`docs/COMPATIBILITY_MATRIX.md`](docs/COMPATIBILITY_MATRIX.md) : Matrice de compatibilité matérielle (smart trainers, cardio, shifting virtuel) et protocoles de tests de laboratoire.
- [`docs/SECURITY.md`](docs/SECURITY.md) : Garde-fous matériels (limiteur de rampe de puissance, arrêt d'urgence 1-tap, isolation de l'IA), sécurité backend et RGPD.
- [`docs/COSTS_AND_LICENCES.md`](docs/COSTS_AND_LICENCES.md) : Inventaire des licences open-source, analyse légale des données altimétriques (OpenStreetMap vs Google) et budget d'infrastructure à 0 €.
- [`docs/ROADMAP.md`](docs/ROADMAP.md) : Feuille de route progressive en 8 phases strictes avec critères d'acceptation.
- [`docs/DECISIONS.md`](docs/DECISIONS.md) : Registre des décisions architecturales (ADR-001 à ADR-006).

---

## 🚀 Phase Actuelle : Phase 1 (Audit & Planification)
Conformément au protocole, aucun développement coûteux n'est lancé avant la validation de l'architecture cible. Le premier jalon de développement sera le **Prototype Matériel de Phase 1** (connexion BLE et lecture télémétrique du Zwift Hub One).

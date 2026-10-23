# Rapport d'Audit de Cybersécurité & Sûreté Matérielle (Phase 8)

- **Projet** : Fogcycling (Application Mobile 3D de Cyclisme Virtuel — Zwift Hub One & Zwift Cog)
- **Auditeur** : **Victor** (Lead Dev, Architecte Logiciel & AppSec — AgentCorp)
- **Méthodologie** : Framework d'Audit en 6 Phases avec Grand Livre de Couverture ([`docs/coverage-ledger.json`](file:///C:/Users/TrendingPC/.gemini/antigravity/scratch/Fogcycling/docs/coverage-ledger.json))
- **Statut Global** : **CERTIFIÉ CONFORME — 0 VULNÉRABILITÉ CRITIQUE OU HAUTE**

---

## Phase 1 — Reconnaissance & Périmètre d'Audit
L'audit couvre l'intégralité des 8 phases de l'application :
1. Couche matérielle Bluetooth Low Energy FTMS (`0x1826`) & HRS (`0x180D`).
2. Moteur de rendu 3D WebGL (`assets/3d_world/index.html` & `Cycling3dView`).
3. Moteur d'entraînement ERG, Mode Carrière (12 cols, Grands Tours, IA 10 niveaux) et Exportateur Strava `.TCX`.
4. Schéma PostgreSQL / Supabase avec politiques *Row Level Security (RLS)* et contrôle d'accès basé sur les rôles (RBAC).
5. Synchronisation Multijoueur WebSockets (`RiderSyncPacket` & `multiplayer_ws_server.js`).

---

## Phase 2 — Modélisation des Menaces & Frontières de Confiance (Trust Boundaries)

| Frontière | Risque Identifié | Contre-mesure Implémentée | Statut |
| :--- | :--- | :--- | :--- |
| **App $\leftrightarrow$ Frein Magnétique Zwift Hub (`0x2AD9`)** | Consigne de puissance aberrante (ex. `1500 W` instantanés) pouvant blesser les genoux du cycliste. | Encapsulation obligatoire dans [`SafetyLimiter`](file:///C:/Users/TrendingPC/.gemini/antigravity/scratch/Fogcycling/lib/core/safety/safety_limiter.dart) : plafond matériel strict (`450 W`), rampe progressive et bouton d'arrêt d'urgence 1-Tap (`0 W`). | ✅ Protégé |
| **Trames BLE entrantes (`0x2AD2`, `0x2A37`)** | Paquets Bluetooth tronqués ou malformés provoquant un crash (`RangeError`). | Vérification systématique de la longueur du tableau d'octets avant chaque lecture `uint16`/`sint16` dans [`FtmsDataParser`](file:///C:/Users/TrendingPC/.gemini/antigravity/scratch/Fogcycling/lib/core/bluetooth/ftms_data_parser.dart). | ✅ Protégé |
| **Exportateur XML Garmin `.TCX` (Strava)** | Injection XML via le titre d'activité ou le nom du parcours. | Échappement strict des entités XML (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`) via `_escapeXml()` dans [`StravaExporter`](file:///C:/Users/TrendingPC/.gemini/antigravity/scratch/Fogcycling/lib/core/strava/strava_exporter.dart). | ✅ Protégé |
| **Base de données Cloud & Espace Admin** | Élévation de privilèges d'un compte membre vers les réglages d'administration. | Double verrouillage : vérification RBAC applicative (`RBAC_DENIED` journalisé) + politiques PostgreSQL RLS serveur (`public.is_admin()`) dans [`supabase/schema_rls.sql`](file:///C:/Users/TrendingPC/.gemini/antigravity/scratch/Fogcycling/supabase/schema_rls.sql). | ✅ Protégé |
| **Pont Flutter $\leftrightarrow$ WebView 3D** | Dépendance réseau externe ou injection JS. | Moteur `three.min.js` embarqué 100 % localement dans les assets de l'APK (zéro appel CDN externe) et typage numérique strict des paramètres. | ✅ Protégé |

---

## Phase 3 à 6 — Vérification par Tests Automatisés & Validation Finale
- **Analyse statique Dart (`flutter analyze`)** : `0 erreur, 0 avertissement`.
- **Suite de tests unitaires et widgets (`flutter test`)** : Couverture complète du parseur FTMS, de la boîte virtuelle Zwift Cog 24 vitesses, du `SafetyLimiter`, des 10 niveaux d'IA, de l'exportateur `.TCX` Strava, des 7 zones Coggan, du contrôle RBAC Admin, du protocole `RiderSyncPacket` Dead Reckoning et du moteur physiologique $W'$ Balance de Coach Stravos.
- **Zéro secret exposé** : Les certificats locaux et tokens sont exclus via `.gitignore`.

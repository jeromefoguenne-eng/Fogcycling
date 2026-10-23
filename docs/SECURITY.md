# Politique de Sécurité Matérielle, Cybersécurité & Protection des Données

## 1. Sécurité Matérielle et Intégrité Physique du Cycliste

Le pilotage d'un frein électromagnétique de home trainer capable d'exercer une résistance équivalente à plus de 1000 Watts présente un risque physique réel (tendinites, rupture de chaîne, chute ou blocage brutal du pédalage). Fogcycling met en œuvre une politique stricte de **Garde-fous Matériels Déterministes**.

### 1.1 Garde-fous du Contrôleur de Résistance (FTMS Driver)
1. **Limiteur de Rampe d'Accélération (Rate-Limiter)** :
   - Toute consigne de puissance (mode ERG) ou de pente (mode simulation) est lissée par une rampe temporelle.
   - **Plafond de variation : maximum 20 Watts par seconde**.
   - Interdiction formelle de sauts de puissance instantanés (ex: passer de 100W à 400W en 0 seconde est strictement impossible ; le contrôleur mettra 15 secondes pour y parvenir progressivement).
2. **Plafond Absolu de Sécurité Personnalisable** :
   - Par défaut bridé à 400 Watts pour un profil amateur standard, ajustable manuellement dans les paramètres de sécurité par le cycliste (max 1000W pour sprinteurs confirmés).
   - Toute consigne dépassant le plafond est automatiquement écrêtée.
3. **Bouton d'Arrêt d'Urgence Immédiat (1-Tap Emergency Stop)** :
   - Présent en permanence sur le HUD à l'écran, accessible d'un simple effleurement.
   - Action : Envoi immédiat de l'opcode FTMS `0x01` (Reset) et `0x04` (Set Target Resistance à 0%), libérant totalement la roue libre du home trainer.
4. **Surveillance du Signal & Heartbeat Bluetooth (Fail-Safe)** :
   - Si aucune trame de télémétrie ou si une perte de paquets BLE persiste plus de 2,5 secondes, le pilote bascule automatiquement le home trainer en état de sécurité passif (résistance minimale par défaut).
5. **Isolation Étéanche de l'IA (Coach Stravos)** :
   - **Règle absolue** : Le modèle LLM ne communique JAMAIS directement avec le pilote Bluetooth.
   - L'IA produit uniquement un plan textuel structuré (JSON).
   - Ce plan passe obligatoirement par le validateur logiciel `WorkoutSafetyValidator` qui contrôle les zones de fréquence cardiaque et les watts cibles avant d'alimenter la file d'attente du contrôleur.

---

## 2. Cybersécurité de l'Infrastructure et des API

### 2.1 Authentification et Gestion des Rôles (RBAC)
- Authentification gérée par **Supabase Auth** avec jetons JWT signés cryptographiquement (algorithme asymétrique EdDSA / RSA).
- Rôles distincts : `cyclist` (par défaut) et `admin`.
- **Règle d'or** : Aucun statut administrateur ne peut être accordé ou manipulé côté client. Toute tentative de modification du champ rôle dans une requête client est rejetée par les politiques de sécurité au niveau de la base de données.

### 2.2 Sécurité de la Base de Données (PostgreSQL RLS)
- Activation obligatoire du **Row Level Security (RLS)** sur l'ensemble des tables :
  - Table `profiles` : Un utilisateur ne peut lire et modifier que la ligne correspondant à son `auth.uid()`.
  - Table `activities` : Accès en écriture restreint au propriétaire de l'activité.
  - Table `admin_audit_logs` : Accessible uniquement aux utilisateurs vérifiés ayant le claim administrateur validé en base.

### 2.3 Gestion Stricte des Secrets et Clés API
- Aucune clé privée, aucun mot de passe de service et aucun jeton administrateur n'est injecté dans les sources de l'application mobile ou sur le dépôt GitHub public.
- Utilisation exclusive d'un fichier `.env` local pour le développement et de secrets d'environnement sécurisés pour les déploiements CI/CD.

### 2.4 Protection Anti-Triche en Multijoueur
- Dans les courses en ligne, le serveur Node.js / Colyseus est **autoritaire** sur le calcul des classements :
  - Vérification continue du ratio $W/kg$ déclaré : détection automatique des anomalies biomécaniques (ex: 8 W/kg maintenus pendant 20 minutes = exclusion de la course officielle).
  - Validation du profil d'élévation et de la distance parcourue côté serveur.

---

## 3. Confidentialité des Données Personnelles et de Santé (RGPD)
- **Minimisation des données** : Seules les métriques nécessaires au calcul de l'effort physique (poids, puissance, fréquence cardiaque, âge approximatif pour zones FC) sont enregistrées.
- **Droit à l'effacement (Art. 17 RGPD)** : Une option en 1 clic dans les paramètres de profil permet la purge complète et irréversible de l'historique de l'utilisateur et de ses données biométriques.
- **Chiffrement** : Chiffrement des communications en transit via TLS 1.3 obligatoire et chiffrement au repos via AES-256 sur Supabase.

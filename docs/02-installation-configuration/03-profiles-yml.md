# Configuration profiles.yml

## 📋 Table des matières
1. [Vue d'ensemble](#vue-densemble)
2. [Localisation du fichier](#localisation-du-fichier)
3. [Structure du fichier](#structure-du-fichier)
4. [Configuration par warehouse](#configuration-par-warehouse)
5. [Environnements multiples](#environnements-multiples)
6. [Sécurité et bonnes pratiques](#sécurité-et-bonnes-pratiques)
7. [Troubleshooting](#troubleshooting)

---

## Vue d'ensemble

### Qu'est-ce que profiles.yml ?

Le fichier `profiles.yml` contient les **informations de connexion** à votre data warehouse. Il fait le lien entre votre projet DBT et votre base de données.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RELATION PROJET ↔ PROFILES                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Projet DBT                         profiles.yml                    │
│   ┌──────────────────┐              ┌──────────────────────────┐   │
│   │ dbt_project.yml  │              │                          │   │
│   │                  │              │  my_profile:             │   │
│   │ profile:         │─────────────>│    outputs:              │   │
│   │   'my_profile'   │   référence  │      dev:                │   │
│   │                  │              │        type: snowflake   │   │
│   └──────────────────┘              │        account: ...      │   │
│                                      │        user: ...        │   │
│                                      │        password: ...    │   │
│                                      └──────────────────────────┘   │
│                                                  │                  │
│                                                  ▼                  │
│                                      ┌──────────────────────────┐   │
│                                      │     DATA WAREHOUSE       │   │
│                                      │   (Snowflake, BQ, etc.)  │   │
│                                      └──────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Pourquoi un fichier séparé ?

| Raison | Explication |
|--------|-------------|
| **Sécurité** | Contient des secrets (mots de passe, tokens) |
| **Portabilité** | Chaque développeur a ses propres credentials |
| **Git** | Ne doit JAMAIS être versionné (.gitignore) |
| **Multi-environnement** | Un fichier pour dev, staging, prod |

---

## Localisation du fichier

### Emplacement par défaut

Le fichier `profiles.yml` se trouve dans le **dossier home de l'utilisateur** :

| OS | Chemin |
|----|--------|
| **Windows** | `C:\Users\<username>\.dbt\profiles.yml` |
| **macOS** | `~/.dbt/profiles.yml` |
| **Linux** | `~/.dbt/profiles.yml` |

### Créer le dossier et le fichier

```bash
# Windows (PowerShell)
mkdir $HOME\.dbt
New-Item -Path $HOME\.dbt\profiles.yml -ItemType File

# macOS / Linux
mkdir -p ~/.dbt
touch ~/.dbt/profiles.yml
```

### Emplacement personnalisé

```bash
# Spécifier un chemin différent
dbt run --profiles-dir /path/to/profiles/

# Ou via variable d'environnement
export DBT_PROFILES_DIR=/path/to/profiles/
```

### Dans le projet (déconseillé)

```
my_project/
├── profiles.yml       # Possible mais à ajouter dans .gitignore
├── dbt_project.yml
└── models/
```

---

## Structure du fichier

### Anatomie

```yaml
# profiles.yml

<profile_name>:                    # Nom du profil (référencé dans dbt_project.yml)
  target: <default_target>         # Environnement par défaut
  outputs:                         # Liste des environnements
    <target_name_1>:               # Premier environnement
      type: <adapter_type>         # Type de warehouse
      <connection_params>          # Paramètres de connexion
    <target_name_2>:               # Deuxième environnement
      type: <adapter_type>
      <connection_params>
```

### Exemple minimal

```yaml
# profiles.yml

my_company:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: dbt_user
      password: secret123
      port: 5432
      dbname: analytics
      schema: dbt_dev
      threads: 4
```

---

## Configuration par warehouse

### Snowflake

```yaml
snowflake_profile:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: xy12345.us-east-1  # Identifiant du compte
      
      # Authentification
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      # OU avec key-pair
      # private_key_path: /path/to/private.key
      # private_key_passphrase: passphrase
      
      # Warehouse et database
      role: TRANSFORMER_ROLE
      warehouse: TRANSFORM_WH
      database: ANALYTICS
      schema: DBT_DEV
      
      # Options
      threads: 8
      client_session_keep_alive: true
      query_tag: dbt
      
    prod:
      type: snowflake
      account: xy12345.us-east-1
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: TRANSFORMER_ROLE
      warehouse: TRANSFORM_WH_LARGE
      database: ANALYTICS
      schema: DBT_PROD
      threads: 16
```

#### Paramètres Snowflake

| Paramètre | Requis | Description |
|-----------|--------|-------------|
| `account` | ✅ | Identifiant du compte (avec région) |
| `user` | ✅ | Nom d'utilisateur |
| `password` | ⚠️ | Mot de passe (ou key-pair) |
| `role` | ✅ | Rôle Snowflake |
| `warehouse` | ✅ | Virtual warehouse |
| `database` | ✅ | Base de données cible |
| `schema` | ✅ | Schéma par défaut |
| `threads` | ❌ | Parallélisme (défaut: 4) |

### BigQuery

```yaml
bigquery_profile:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth  # ou service-account
      project: my-gcp-project
      dataset: dbt_dev
      threads: 8
      timeout_seconds: 300
      location: US
      
      # Pour service account
      # method: service-account
      # keyfile: /path/to/keyfile.json
      
    prod:
      type: bigquery
      method: service-account
      project: my-gcp-project-prod
      dataset: analytics
      keyfile: "{{ env_var('GOOGLE_APPLICATION_CREDENTIALS') }}"
      threads: 16
      timeout_seconds: 600
      location: US
      priority: batch
```

#### Paramètres BigQuery

| Paramètre | Requis | Description |
|-----------|--------|-------------|
| `method` | ✅ | `oauth` ou `service-account` |
| `project` | ✅ | ID du projet GCP |
| `dataset` | ✅ | Dataset par défaut |
| `keyfile` | ⚠️ | Chemin vers le JSON (si service-account) |
| `location` | ❌ | Région (US, EU, etc.) |
| `threads` | ❌ | Parallélisme |

### Redshift

```yaml
redshift_profile:
  target: dev
  outputs:
    dev:
      type: redshift
      host: my-cluster.abc123.us-east-1.redshift.amazonaws.com
      port: 5439
      user: "{{ env_var('REDSHIFT_USER') }}"
      password: "{{ env_var('REDSHIFT_PASSWORD') }}"
      dbname: analytics
      schema: dbt_dev
      threads: 4
      
      # Options avancées
      ra3_node: true
      connect_timeout: 30
      sslmode: require
```

### PostgreSQL

```yaml
postgres_profile:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      port: 5432
      user: postgres
      password: "{{ env_var('POSTGRES_PASSWORD') }}"
      dbname: analytics
      schema: dbt_dev
      threads: 4
      
      # Options SSL
      # sslmode: require
      # sslcert: /path/to/client-cert.pem
      # sslkey: /path/to/client-key.pem
      # sslrootcert: /path/to/ca-cert.pem
      
    prod:
      type: postgres
      host: prod-db.company.com
      port: 5432
      user: dbt_prod
      password: "{{ env_var('POSTGRES_PROD_PASSWORD') }}"
      dbname: analytics
      schema: public
      threads: 8
```

### Databricks

```yaml
databricks_profile:
  target: dev
  outputs:
    dev:
      type: databricks
      catalog: analytics_catalog
      schema: dbt_dev
      host: "{{ env_var('DATABRICKS_HOST') }}"
      http_path: /sql/1.0/warehouses/abc123
      token: "{{ env_var('DATABRICKS_TOKEN') }}"
      threads: 4
```

---

## Environnements multiples

### Structure type

```yaml
# profiles.yml complet multi-environnement

my_company:
  target: dev  # Défaut
  
  outputs:
    # ═══════════════════════════════════════════
    # DÉVELOPPEMENT LOCAL
    # ═══════════════════════════════════════════
    dev:
      type: snowflake
      account: xy12345.us-east-1
      user: "{{ env_var('DEV_USER') }}"
      password: "{{ env_var('DEV_PASSWORD') }}"
      role: DEV_ROLE
      warehouse: DEV_WH_XS
      database: DEV_DB
      schema: "{{ env_var('DBT_SCHEMA', 'dbt_' ~ env_var('USER')) }}"
      threads: 4
    
    # ═══════════════════════════════════════════
    # CI/CD (Tests automatisés)
    # ═══════════════════════════════════════════
    ci:
      type: snowflake
      account: xy12345.us-east-1
      user: "{{ env_var('CI_USER') }}"
      password: "{{ env_var('CI_PASSWORD') }}"
      role: CI_ROLE
      warehouse: CI_WH_S
      database: CI_DB
      schema: "dbt_ci_{{ env_var('CI_JOB_ID', 'local') }}"
      threads: 8
    
    # ═══════════════════════════════════════════
    # STAGING (Pré-production)
    # ═══════════════════════════════════════════
    staging:
      type: snowflake
      account: xy12345.us-east-1
      user: "{{ env_var('STAGING_USER') }}"
      password: "{{ env_var('STAGING_PASSWORD') }}"
      role: STAGING_ROLE
      warehouse: STAGING_WH_M
      database: STAGING_DB
      schema: analytics
      threads: 8
    
    # ═══════════════════════════════════════════
    # PRODUCTION
    # ═══════════════════════════════════════════
    prod:
      type: snowflake
      account: xy12345.us-east-1
      user: "{{ env_var('PROD_USER') }}"
      password: "{{ env_var('PROD_PASSWORD') }}"
      role: PROD_ROLE
      warehouse: PROD_WH_L
      database: PROD_DB
      schema: analytics
      threads: 16
```

### Changer d'environnement

```bash
# Utiliser l'environnement par défaut (dev)
dbt run

# Utiliser un environnement spécifique
dbt run --target staging
dbt run --target prod
dbt run -t ci
```

### Schéma dynamique par développeur

```yaml
dev:
  type: snowflake
  # ...
  schema: "dbt_{{ env_var('USER') }}"  # dbt_john, dbt_jane, etc.
```

---

## Sécurité et bonnes pratiques

### ⚠️ Règle d'or : JAMAIS dans Git

```gitignore
# .gitignore
profiles.yml
*.env
.env*
```

### Variables d'environnement

```yaml
# Utiliser env_var() pour les secrets
user: "{{ env_var('DB_USER') }}"
password: "{{ env_var('DB_PASSWORD') }}"

# Avec valeur par défaut
schema: "{{ env_var('DBT_SCHEMA', 'default_schema') }}"
```

**Configuration des variables :**

```bash
# Windows (PowerShell)
$env:DB_USER = "my_user"
$env:DB_PASSWORD = "my_secret"

# macOS / Linux
export DB_USER="my_user"
export DB_PASSWORD="my_secret"

# Ou dans un fichier .env (non versionné)
# Charger avec: source .env
```

### Fichier .env (développement local)

```bash
# .env (à ajouter dans .gitignore)
export SNOWFLAKE_USER="john.doe@company.com"
export SNOWFLAKE_PASSWORD="super_secret_123"
export SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
```

### Authentification par clé (recommandé pour prod)

#### Snowflake Key-Pair

```yaml
prod:
  type: snowflake
  account: xy12345.us-east-1
  user: DBT_SERVICE_ACCOUNT
  private_key_path: "{{ env_var('SNOWFLAKE_PRIVATE_KEY_PATH') }}"
  private_key_passphrase: "{{ env_var('SNOWFLAKE_KEY_PASSPHRASE') }}"
  # ... autres paramètres
```

#### BigQuery Service Account

```yaml
prod:
  type: bigquery
  method: service-account
  project: my-prod-project
  keyfile: "{{ env_var('GOOGLE_APPLICATION_CREDENTIALS') }}"
  # ... autres paramètres
```

### Gestion des secrets en CI/CD

```yaml
# GitHub Actions
env:
  DBT_USER: ${{ secrets.DBT_USER }}
  DBT_PASSWORD: ${{ secrets.DBT_PASSWORD }}

# GitLab CI
variables:
  DBT_USER: $DBT_USER  # Variable protégée dans GitLab
  DBT_PASSWORD: $DBT_PASSWORD
```

---

## Troubleshooting

### Vérifier la configuration

```bash
# Diagnostic complet
dbt debug

# Sortie attendue
# Connection test: OK
# ...
```

### Erreurs courantes

#### 1. Profil non trouvé

```
ERROR: Could not find profile named 'my_profile'
```

**Solutions :**
```bash
# Vérifier le nom dans dbt_project.yml
cat dbt_project.yml | grep profile

# Vérifier profiles.yml
cat ~/.dbt/profiles.yml

# Vérifier le chemin
dbt debug --profiles-dir ~/.dbt
```

#### 2. Erreur d'authentification

```
ERROR: Authentication failed
```

**Solutions :**
```bash
# Vérifier les credentials
echo $DB_USER
echo $DB_PASSWORD

# Tester la connexion directement
# Snowflake : snowsql
# Postgres : psql
```

#### 3. Variable d'environnement manquante

```
ERROR: Env var required but not provided: 'DB_PASSWORD'
```

**Solution :**
```bash
# Définir la variable
export DB_PASSWORD="my_password"

# Vérifier
echo $DB_PASSWORD
```

#### 4. YAML invalide

```
ERROR: yaml.scanner.ScannerError: mapping values are not allowed here
```

**Solutions :**
- Utiliser des espaces (pas de tabs)
- Vérifier l'indentation (2 espaces par niveau)
- Utiliser un validateur YAML en ligne

### Template de debug

```yaml
# profiles.yml - Version debug
my_profile:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      port: 5432
      user: test_user
      password: test_password  # Valeur en dur pour tester
      dbname: test_db
      schema: test_schema
      threads: 1
```

---

## Résumé

| Aspect | Détail |
|--------|--------|
| **Localisation** | `~/.dbt/profiles.yml` |
| **Contenu** | Credentials, environnements |
| **Sécurité** | Variables d'environnement, JAMAIS dans Git |
| **Multi-env** | `outputs:` avec dev, staging, prod |
| **Sélection env** | `dbt run --target <env>` |

### Checklist

- [ ] Créer `~/.dbt/profiles.yml`
- [ ] Configurer au moins un environnement `dev`
- [ ] Utiliser `env_var()` pour les secrets
- [ ] Ajouter `profiles.yml` au `.gitignore`
- [ ] Tester avec `dbt debug`

---

## Prochaines étapes

→ [Variables d'environnement](./04-variables-environnement.md)


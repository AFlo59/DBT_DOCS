# Variables d'environnement dans DBT

## 📋 Table des matières
1. [Introduction](#introduction)
2. [La fonction env_var()](#la-fonction-env_var)
3. [Variables dans profiles.yml](#variables-dans-profilesyml)
4. [Variables dans dbt_project.yml](#variables-dans-dbt_projectyml)
5. [Variables dans les modèles](#variables-dans-les-modèles)
6. [Gestion par environnement](#gestion-par-environnement)
7. [CI/CD et secrets](#cicd-et-secrets)

---

## Introduction

### Pourquoi utiliser des variables d'environnement ?

Les variables d'environnement permettent de :

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AVANTAGES ENV VARS                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  🔐 SÉCURITÉ 🔐                                                    │
│     └── Pas de secrets dans le code                                 │
│     └── Pas de credentials dans Git                                 │
│                                                                     │
│  🔄 FLEXIBILITÉ 🔄                                                 │
│     └── Même code, différentes configurations                       │
│     └── Dev/Staging/Prod avec le même projet                        │
│                                                                     │
│  👥 COLLABORATION 👥                                               │
│     └── Chaque développeur a ses propres valeurs                    │
│     └── CI/CD avec ses propres secrets                              │
│                                                                     │
│  🔧 MAINTENANCE 🔧                                                 │
│     └── Changement de config sans modifier le code                  │
│     └── Rotation des secrets simplifiée                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Types de variables

| Type              | Usage                 | Exemple               |
|-------------------|-----------------------|-----------------------|
| **Secrets**       | Authentification      | Mots de passe, tokens |
| **Configuration** | Paramètres dynamiques | Schéma, database      |
| **Feature flags** | Activer/désactiver    | Debug mode            |
| **Contexte**      | Métadonnées           | User, CI job ID       |

---

## La fonction env_var()

### Syntaxe de base

```jinja
{{ env_var('VARIABLE_NAME') }}
```

### Avec valeur par défaut

```jinja
{{ env_var('VARIABLE_NAME', 'default_value') }}
```

### Exemples pratiques

```yaml
# profiles.yml
user: "{{ env_var('DB_USER') }}"
password: "{{ env_var('DB_PASSWORD') }}"

# Avec défaut
schema: "{{ env_var('DBT_SCHEMA', 'dev') }}"
threads: "{{ env_var('DBT_THREADS', '4') | int }}"
```

### Conversion de types

```jinja
# String (par défaut)
{{ env_var('MY_STRING') }}

# Integer
{{ env_var('MY_INT') | int }}

# Boolean (attention aux strings)
{% if env_var('MY_BOOL', 'false') | lower == 'true' %}
```

---

## Variables dans profiles.yml

### Configuration complète

```yaml
# profiles.yml

my_company:
  target: "{{ env_var('DBT_TARGET', 'dev') }}"
  
  outputs:
    dev:
      type: snowflake
      
      # ═══════════════════════════════════════════
      # COMPTE ET AUTHENTIFICATION
      # ═══════════════════════════════════════════
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      
      # ═══════════════════════════════════════════
      # CONFIGURATION WAREHOUSE
      # ═══════════════════════════════════════════
      role: "{{ env_var('SNOWFLAKE_ROLE', 'DEVELOPER') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE', 'DEV_WH') }}"
      database: "{{ env_var('SNOWFLAKE_DATABASE', 'DEV_DB') }}"
      
      # ═══════════════════════════════════════════
      # SCHÉMA DYNAMIQUE
      # ═══════════════════════════════════════════
      # Schéma par développeur : dbt_john, dbt_jane, etc.
      schema: "dbt_{{ env_var('USER', env_var('USERNAME', 'default')) }}"
      
      # ═══════════════════════════════════════════
      # PERFORMANCE
      # ═══════════════════════════════════════════
      threads: "{{ env_var('DBT_THREADS', '4') | int }}"
      
    prod:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_PROD_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PROD_PASSWORD') }}"
      role: "{{ env_var('SNOWFLAKE_PROD_ROLE') }}"
      warehouse: "{{ env_var('SNOWFLAKE_PROD_WAREHOUSE') }}"
      database: "{{ env_var('SNOWFLAKE_PROD_DATABASE') }}"
      schema: analytics
      threads: 16
```

### Variables requises vs optionnelles

```yaml
# Requise (erreur si absente)
password: "{{ env_var('DB_PASSWORD') }}"

# Optionnelle avec défaut
schema: "{{ env_var('DBT_SCHEMA', 'dbt_dev') }}"

# Optionnelle avec logique
schema: >
  {% if env_var('CI', 'false') == 'true' %}
    ci_{{ env_var('CI_JOB_ID', 'unknown') }}
  {% else %}
    dbt_{{ env_var('USER', 'default') }}
  {% endif %}
```

---

## Variables dans dbt_project.yml

### Variables de projet (vars)

```yaml
# dbt_project.yml

name: 'my_project'
version: '1.0.0'
config-version: 2
profile: 'my_company'

vars:
  # Variable simple avec env_var
  start_date: "{{ env_var('START_DATE', '2020-01-01') }}"
  
  # Feature flags
  enable_pii_masking: "{{ env_var('ENABLE_PII_MASKING', 'true') == 'true' }}"
  
  # Configuration par environnement
  environment: "{{ env_var('DBT_ENV', 'dev') }}"
  
  # Limites dynamiques
  max_rows: "{{ env_var('MAX_ROWS', '1000000') | int }}"
```

### Configuration conditionnelle

```yaml
# dbt_project.yml

models:
  my_project:
    # Matérialisation selon l'environnement
    +materialized: >
      {%- if env_var('DBT_ENV', 'dev') == 'prod' -%}
        table
      {%- else -%}
        view
      {%- endif -%}
    
    staging:
      +schema: "stg_{{ env_var('DBT_ENV', 'dev') }}"
```

---

## Variables dans les modèles

### Accès dans SQL

```sql
-- models/staging/stg_orders.sql

{% set environment = env_var('DBT_ENV', 'dev') %}

SELECT
    order_id,
    customer_id,
    amount,
    
    -- Masquage conditionnel
    {% if env_var('ENABLE_PII_MASKING', 'false') == 'true' %}
    MD5(email) AS email_hash,
    {% else %}
    email,
    {% endif %}
    
    created_at
FROM {{ source('raw', 'orders') }}

-- Limite en dev
{% if environment == 'dev' %}
LIMIT {{ env_var('DEV_ROW_LIMIT', '10000') }}
{% endif %}
```

### Via var()

```sql
-- Préférer var() avec env_var dans dbt_project.yml

-- dbt_project.yml
-- vars:
--   start_date: "{{ env_var('START_DATE', '2020-01-01') }}"

-- model.sql
SELECT *
FROM {{ ref('stg_orders') }}
WHERE created_at >= '{{ var("start_date") }}'
```

### Bonnes pratiques

```sql
-- ✅ BON : Centraliser dans dbt_project.yml
WHERE date >= '{{ var("start_date") }}'

-- ⚠️ ACCEPTABLE : env_var direct pour logique spécifique
{% if env_var('INCLUDE_DELETED', 'false') == 'true' %}
-- Inclure les enregistrements supprimés
{% endif %}

-- ❌ ÉVITER : Hardcoder des valeurs
WHERE date >= '2020-01-01'
```

---

## Gestion par environnement

### Fichier .env (développement local)

```bash
# .env (à ajouter dans .gitignore)

# ═══════════════════════════════════════════
# SNOWFLAKE
# ═══════════════════════════════════════════
export SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
export SNOWFLAKE_USER="john.doe@company.com"
export SNOWFLAKE_PASSWORD="super_secret_123"
export SNOWFLAKE_ROLE="DEVELOPER"
export SNOWFLAKE_WAREHOUSE="DEV_WH"
export SNOWFLAKE_DATABASE="DEV_DB"

# ═══════════════════════════════════════════
# DBT
# ═══════════════════════════════════════════
export DBT_TARGET="dev"
export DBT_THREADS="4"
export DBT_SCHEMA="dbt_john"

# ═══════════════════════════════════════════
# FEATURE FLAGS
# ═══════════════════════════════════════════
export ENABLE_PII_MASKING="false"
export DEV_ROW_LIMIT="10000"
```

### Charger les variables

```bash
# macOS / Linux
source .env

# Windows PowerShell
Get-Content .env | ForEach-Object {
    if ($_ -match '^export\s+(\w+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2].Trim('"'))
    }
}

# Ou utiliser un outil comme dotenv
pip install python-dotenv
```

### Structure recommandée

```
my_project/
├── .env.example      # Template (versionné)
├── .env              # Valeurs réelles (NON versionné)
├── .env.dev          # Valeurs dev (optionnel)
├── .env.staging      # Valeurs staging (optionnel)
├── .gitignore        # Contient .env*
└── ...
```

### Fichier .env.example

```bash
# .env.example (VERSIONNÉ - template)

# Snowflake
export SNOWFLAKE_ACCOUNT=""
export SNOWFLAKE_USER=""
export SNOWFLAKE_PASSWORD=""
export SNOWFLAKE_ROLE=""
export SNOWFLAKE_WAREHOUSE=""
export SNOWFLAKE_DATABASE=""

# DBT
export DBT_TARGET="dev"
export DBT_THREADS="4"

# Features
export ENABLE_PII_MASKING="false"
```

---

## CI/CD et secrets

### GitHub Actions

```yaml
# .github/workflows/dbt.yml

name: DBT CI

on:
  pull_request:
    branches: [main]

jobs:
  dbt-test:
    runs-on: ubuntu-latest
    
    env:
      # Variables depuis GitHub Secrets
      SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
      SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_CI_USER }}
      SNOWFLAKE_PASSWORD: ${{ secrets.SNOWFLAKE_CI_PASSWORD }}
      SNOWFLAKE_ROLE: CI_ROLE
      SNOWFLAKE_WAREHOUSE: CI_WH
      SNOWFLAKE_DATABASE: CI_DB
      DBT_TARGET: ci
      DBT_THREADS: 8
      
      # Schéma unique par run
      DBT_SCHEMA: ci_pr_${{ github.event.pull_request.number }}
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install dependencies
        run: pip install dbt-snowflake
      
      - name: Run dbt
        run: |
          dbt deps
          dbt build --target ci
```

### GitLab CI

```yaml
# .gitlab-ci.yml

stages:
  - test
  - deploy

variables:
  DBT_THREADS: "8"
  DBT_TARGET: ci

dbt-test:
  stage: test
  image: python:3.10
  
  variables:
    # Variables depuis GitLab CI/CD Settings
    SNOWFLAKE_ACCOUNT: $SNOWFLAKE_ACCOUNT
    SNOWFLAKE_USER: $SNOWFLAKE_CI_USER
    SNOWFLAKE_PASSWORD: $SNOWFLAKE_CI_PASSWORD
    DBT_SCHEMA: "ci_${CI_PIPELINE_ID}"
  
  script:
    - pip install dbt-snowflake
    - dbt deps
    - dbt build --target ci
  
  only:
    - merge_requests

dbt-deploy:
  stage: deploy
  image: python:3.10
  
  variables:
    SNOWFLAKE_USER: $SNOWFLAKE_PROD_USER
    SNOWFLAKE_PASSWORD: $SNOWFLAKE_PROD_PASSWORD
    DBT_TARGET: prod
  
  script:
    - pip install dbt-snowflake
    - dbt deps
    - dbt run --target prod
  
  only:
    - main
```

### Azure DevOps

```yaml
# azure-pipelines.yml

trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  - group: dbt-secrets  # Variable group dans Azure DevOps

stages:
  - stage: Test
    jobs:
      - job: DBTTest
        steps:
          - task: UsePythonVersion@0
            inputs:
              versionSpec: '3.10'
          
          - script: pip install dbt-snowflake
            displayName: 'Install dbt'
          
          - script: |
              export SNOWFLAKE_ACCOUNT=$(SNOWFLAKE_ACCOUNT)
              export SNOWFLAKE_USER=$(SNOWFLAKE_USER)
              export SNOWFLAKE_PASSWORD=$(SNOWFLAKE_PASSWORD)
              dbt deps
              dbt build --target ci
            displayName: 'Run dbt'
```

### Gestion des secrets

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HIÉRARCHIE DES SECRETS                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  PRODUCTION                                                         │
│  └── Vault (HashiCorp, AWS Secrets Manager, etc.)                   │
│      └── Rotation automatique                                       │
│      └── Audit trail                                                │
│                                                                     │
│  CI/CD                                                              │
│  └── Secrets natifs (GitHub Secrets, GitLab CI Variables)           │
│      └── Chiffrés au repos                                          │
│      └── Injectés à l'exécution                                     │
│                                                                     │
│  DÉVELOPPEMENT                                                      │
│  └── Fichier .env local                                             │
│      └── Jamais versionné                                           │
│      └── Credentials personnels                                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Résumé

### Syntaxe rapide

```jinja
# Basique
{{ env_var('VAR_NAME') }}

# Avec défaut
{{ env_var('VAR_NAME', 'default') }}

# Conversion
{{ env_var('VAR_NAME') | int }}
{{ env_var('VAR_NAME') | lower == 'true' }}
```

### Checklist sécurité

- [ ] Tous les secrets utilisent `env_var()`
- [ ] `.env` dans `.gitignore`
- [ ] `.env.example` versionné comme template
- [ ] Secrets CI/CD configurés dans la plateforme
- [ ] Différents credentials par environnement
- [ ] Rotation régulière des secrets production

### Variables communes

| Variable             | Usage               |
|----------------------|---------------------|
| `SNOWFLAKE_ACCOUNT`  | Compte Snowflake    |
| `SNOWFLAKE_USER`     | Utilisateur         |
| `SNOWFLAKE_PASSWORD` | Mot de passe        |
| `DBT_TARGET`         | Environnement cible |
| `DBT_THREADS`        | Parallélisme        |
| `DBT_SCHEMA`         | Schéma par défaut   |

---

## Prochaines étapes

→ [Organisation des dossiers](../03-structure-projet/01-organisation-dossiers.md)


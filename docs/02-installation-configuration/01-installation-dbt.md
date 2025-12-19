# Installation de DBT

## 📋 Table des matières
1. [Prérequis](#prérequis)
2. [Installation de DBT Core](#installation-de-dbt-core)
3. [Installation par adapter](#installation-par-adapter)
4. [DBT Cloud (Alternative)](#dbt-cloud-alternative)
5. [Vérification de l'installation](#vérification-de-linstallation)
6. [Mise à jour de DBT](#mise-à-jour-de-dbt)

---

## Prérequis

### Système

| Prérequis | Version minimale | Commande de vérification |
|-----------|------------------|--------------------------|
| Python    | 3.8+             | `python --version`       |
| pip       | 21.0+            | `pip --version`          |
| Git       | 2.0+             | `git --version`          |

### Environnement recommandé

```bash
# Créer un environnement virtuel (recommandé)
python -m venv dbt-env

# Activer l'environnement
# Windows
dbt-env\Scripts\activate

# macOS/Linux
source dbt-env/bin/activate
```

> ⚠️ **Important** : Utilisez toujours un environnement virtuel pour isoler les dépendances DBT.

---

## Installation de DBT Core

### Méthode 1 : pip (recommandé)

```bash
# Installation de base (sans adapter)
pip install dbt-core

# Vérification
dbt --version
```

### Méthode 2 : pipx (isolation automatique)

```bash
# Installation de pipx si nécessaire
pip install pipx
pipx ensurepath

# Installation de dbt avec un adapter
pipx install dbt-snowflake
```

### Structure des packages DBT

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PACKAGES DBT                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                       ┌─────────────┐                               │
│                       │  dbt-core   │                               │
│                       │  (moteur)   │                               │
│                       └──────┬──────┘                               │
│                              │                                       │
│           ┌──────────────────┼──────────────────┐                   │
│           │                  │                  │                   │
│           ▼                  ▼                  ▼                   │
│    ┌────────────┐     ┌────────────┐     ┌────────────┐            │
│    │dbt-snowflake│    │dbt-bigquery│    │dbt-postgres │            │
│    │  (adapter) │     │  (adapter) │     │  (adapter) │            │
│    └────────────┘     └────────────┘     └────────────┘            │
│                                                                      │
│  Note: Installer un adapter installe automatiquement dbt-core       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Installation par adapter

### Liste des adapters officiels

| Adapter | Commande | Documentation |
|---------|----------|---------------|
| **Snowflake** | `pip install dbt-snowflake` | [docs](https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup) |
| **BigQuery** | `pip install dbt-bigquery` | [docs](https://docs.getdbt.com/docs/core/connect-data-platform/bigquery-setup) |
| **Redshift** | `pip install dbt-redshift` | [docs](https://docs.getdbt.com/docs/core/connect-data-platform/redshift-setup) |
| **PostgreSQL** | `pip install dbt-postgres` | [docs](https://docs.getdbt.com/docs/core/connect-data-platform/postgres-setup) |
| **Databricks** | `pip install dbt-databricks` | [docs](https://docs.getdbt.com/docs/core/connect-data-platform/databricks-setup) |
| **Spark** | `pip install dbt-spark` | [docs](https://docs.getdbt.com/docs/core/connect-data-platform/spark-setup) |
| **SQL Server** | `pip install dbt-sqlserver` | [docs](https://docs.getdbt.com/docs/core/connect-data-platform/mssql-setup) |
| **Trino** | `pip install dbt-trino` | [docs](https://docs.getdbt.com/docs/core/connect-data-platform/trino-setup) |

### Installation Snowflake (exemple détaillé)

```bash
# 1. Créer et activer l'environnement virtuel
python -m venv dbt-venv
source dbt-venv/bin/activate  # ou dbt-venv\Scripts\activate sur Windows

# 2. Mettre à jour pip
pip install --upgrade pip

# 3. Installer dbt-snowflake
pip install dbt-snowflake

# 4. Vérifier l'installation
dbt --version
```

**Sortie attendue :**
```
Core:
  - installed: 1.7.x
  - latest:    1.7.x

Plugins:
  - snowflake: 1.7.x
```

### Installation BigQuery (exemple détaillé)

```bash
# Installation
pip install dbt-bigquery

# Prérequis supplémentaire : authentification GCP
# Option 1 : Service Account (recommandé pour production)
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/keyfile.json"

# Option 2 : OAuth (développement local)
gcloud auth application-default login
```

### Installation PostgreSQL (développement local)

```bash
# Idéal pour apprendre DBT localement
pip install dbt-postgres

# Prérequis : PostgreSQL installé
# Windows : https://www.postgresql.org/download/windows/
# macOS   : brew install postgresql
# Linux   : sudo apt install postgresql
```

---

## DBT Cloud (Alternative)

### Présentation

DBT Cloud est la version **SaaS** de DBT, ne nécessitant pas d'installation locale.

```
┌─────────────────────────────────────────────────────────────────────┐
│                      DBT CLOUD                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                         NAVIGATEUR                             │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │                    IDE Intégré                           │  │  │
│  │  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │  │
│  │  │  │   Éditeur    │  │   Terminal   │  │   Logs       │   │  │  │
│  │  │  │   SQL        │  │   dbt run    │  │   Results    │   │  │  │
│  │  │  └──────────────┘  └──────────────┘  └──────────────┘   │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  │                                                                │  │
│  │  Features incluses :                                          │  │
│  │  ✓ Scheduling intégré                                        │  │
│  │  ✓ CI/CD automatique                                         │  │
│  │  ✓ Environnements (dev/staging/prod)                         │  │
│  │  ✓ Gestion des secrets                                       │  │
│  │  ✓ Documentation hébergée                                    │  │
│  │                                                                │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Plans disponibles

| Plan | Prix | Fonctionnalités |
|------|------|-----------------|
| **Developer** | Gratuit | 1 développeur, 1 projet |
| **Team** | $100/seat/mois | Multi-utilisateurs, CI/CD |
| **Enterprise** | Sur devis | SSO, SLA, Support dédié |

### Inscription

1. Aller sur [cloud.getdbt.com](https://cloud.getdbt.com)
2. Créer un compte
3. Connecter le repository Git
4. Configurer la connexion warehouse

---

## Vérification de l'installation

### Commande de diagnostic

```bash
# Vérification complète
dbt debug
```

**Sortie type (connexion non configurée) :**

```
Running with dbt=1.7.0
dbt version: 1.7.0
python version: 3.10.12
python path: /path/to/python
os info: Windows-10-...

Configuration:
  profiles.yml file [ERROR not found]
  dbt_project.yml file [ERROR not found]

Required dependencies:
 - git [OK found]

Connection:
  [ERROR] Could not connect to database
```

### Créer un projet de test

```bash
# Initialiser un nouveau projet
dbt init my_first_project

# Questions interactives
# 1. Which database would you like to use?
# 2. Informations de connexion...

# Se déplacer dans le projet
cd my_first_project

# Vérifier la structure
ls -la
# ou
dir  # Windows
```

### Structure créée

```
my_first_project/
├── dbt_project.yml      # Configuration du projet
├── README.md
├── analyses/            # Analyses SQL (non matérialisées)
├── macros/              # Macros Jinja personnalisées
├── models/              # Modèles SQL
│   └── example/
│       ├── my_first_dbt_model.sql
│       ├── my_second_dbt_model.sql
│       └── schema.yml
├── seeds/               # Fichiers CSV
├── snapshots/           # Snapshots SCD
└── tests/               # Tests singuliers
```

---

## Mise à jour de DBT

### Vérifier la version actuelle

```bash
dbt --version
```

### Mettre à jour

```bash
# Mise à jour de dbt et de l'adapter
pip install --upgrade dbt-core dbt-snowflake

# Ou si vous utilisez un seul adapter
pip install --upgrade dbt-snowflake
```

### Gestion des versions

```bash
# Installer une version spécifique
pip install dbt-snowflake==1.7.0

# Voir les versions disponibles
pip index versions dbt-snowflake
```

### Fichier requirements.txt (bonnes pratiques)

```text
# requirements.txt
dbt-snowflake==1.7.0
# ou
dbt-bigquery>=1.7.0,<1.8.0
```

```bash
# Installation depuis requirements.txt
pip install -r requirements.txt
```

---

## Troubleshooting

### Erreurs courantes

#### 1. Python version trop ancienne

```
ERROR: dbt-core requires Python >=3.8
```

**Solution :** Installer Python 3.8+

#### 2. Conflit de dépendances

```
ERROR: pip's dependency resolver does not currently take into account all the packages that are installed.
```

**Solution :**
```bash
# Créer un environnement virtuel propre
python -m venv fresh-dbt-env
source fresh-dbt-env/bin/activate
pip install dbt-snowflake
```

#### 3. Erreur de connexion SSL (Windows)

```
ERROR: SSL: CERTIFICATE_VERIFY_FAILED
```

**Solution :**
```bash
pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org dbt-snowflake
```

#### 4. Permissions (Linux/macOS)

```
ERROR: Could not install packages due to an EnvironmentError: [Errno 13] Permission denied
```

**Solution :**
```bash
# Ne JAMAIS utiliser sudo avec pip
# Utiliser un environnement virtuel
python -m venv dbt-env
source dbt-env/bin/activate
pip install dbt-snowflake
```

---

## Résumé

| Étape | Commande |
|-------|----------|
| Créer environnement virtuel | `python -m venv dbt-env` |
| Activer l'environnement | `source dbt-env/bin/activate` |
| Installer DBT + adapter | `pip install dbt-snowflake` |
| Vérifier l'installation | `dbt --version` |
| Créer un projet | `dbt init my_project` |
| Diagnostiquer | `dbt debug` |

---

## Prochaines étapes

→ [Configuration dbt_project.yml](./02-dbt-project-yml.md)


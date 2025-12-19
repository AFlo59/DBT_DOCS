# Guide d'Installation Locale - DBT avec Virtual Environment

Ce guide détaille l'installation complète de DBT en local avec un environnement virtuel Python.

---

## Table des matières

1. [Prérequis](#prérequis)
2. [Installation Python](#installation-python)
3. [Création du Virtual Environment](#création-du-virtual-environment)
4. [Installation de DBT](#installation-de-dbt)
5. [Initialisation du Projet](#initialisation-du-projet)
6. [Configuration du Profile](#configuration-du-profile)
7. [Validation de l'Installation](#validation-de-linstallation)
8. [Commandes Utiles](#commandes-utiles)

---

## Prérequis

### Système requis

| Composant | Version minimale | Recommandé |
|-----------|------------------|------------|
| Python    | 3.8              | 3.10+      |
| pip       | 21.0             | Dernière   |
| Git       | 2.0              | Dernière   |

### Vérifier les prérequis

```powershell
# Vérifier Python
python --version

# Vérifier pip
pip --version

# Vérifier Git
git --version
```

---

## Installation Python

### Windows

1. **Télécharger Python** depuis [python.org](https://www.python.org/downloads/)

2. **Lors de l'installation** :
   - ✅ Cocher "Add Python to PATH"
   - ✅ Cocher "Install pip"

3. **Vérifier l'installation** :

```powershell
python --version
# Python 3.10.x ou supérieur
```

### macOS

```bash
# Avec Homebrew
brew install python@3.10

# Vérifier
python3 --version
```

### Linux (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install python3.10 python3.10-venv python3-pip

# Vérifier
python3 --version
```

---

## Création du Virtual Environment

### Étape 1 : Créer le dossier du projet

```powershell
# Windows
mkdir mon-projet-dbt
cd mon-projet-dbt
```

```bash
# macOS / Linux
mkdir mon-projet-dbt
cd mon-projet-dbt
```

### Étape 2 : Créer l'environnement virtuel

```powershell
# Windows
python -m venv venv
```

```bash
# macOS / Linux
python3 -m venv venv
```

### Étape 3 : Activer l'environnement virtuel

```powershell
# Windows (PowerShell)
.\venv\Scripts\Activate.ps1

# Windows (CMD)
.\venv\Scripts\activate.bat
```

```bash
# macOS / Linux
source venv/bin/activate
```

> 💡 **Indicateur** : Vous verrez `(venv)` au début de votre prompt une fois activé.

### Étape 4 : Mettre à jour pip

```bash
# Toutes plateformes (une fois venv activé)
pip install --upgrade pip
```

---

## Installation de DBT

### Option 1 : Installation avec requirements.txt (Recommandé)

1. **Créer le fichier `requirements.txt`** :

```text
dbt-core>=1.7.0,<2.0.0
dbt-snowflake>=1.7.0,<2.0.0
python-dotenv>=1.0.0
PyYAML>=6.0.1
```

2. **Installer les dépendances** :

```bash
pip install -r requirements.txt
```

### Option 2 : Installation directe

```bash
# DBT Core + adaptateur Snowflake
pip install dbt-core dbt-snowflake

# Ou avec un autre adaptateur
pip install dbt-core dbt-bigquery      # BigQuery
pip install dbt-core dbt-redshift      # Redshift
pip install dbt-core dbt-postgres      # PostgreSQL
pip install dbt-core dbt-databricks    # Databricks
```

### Vérifier l'installation de DBT

```bash
dbt --version
```

**Sortie attendue** :

```
Core:
  - installed: 1.7.x
  - latest:    1.7.x - Up to date!

Plugins:
  - snowflake: 1.7.x - Up to date!
```

---

## Initialisation du Projet

### Créer un nouveau projet DBT

```bash
# Initialiser un nouveau projet
dbt init mon_projet
```

**Répondre aux questions interactives** :

```
Which database would you like to use?
[1] snowflake

Enter a number: 1
```

### Structure créée

```
mon_projet/
├── analyses/
├── macros/
├── models/
│   └── example/
│       ├── my_first_dbt_model.sql
│       ├── my_second_dbt_model.sql
│       └── schema.yml
├── seeds/
├── snapshots/
├── tests/
├── dbt_project.yml
└── README.md
```

### Se positionner dans le projet

```bash
cd mon_projet
```

---

## Configuration du Profile

### Localisation du fichier profiles.yml

| OS      | Chemin                              |
|---------|-------------------------------------|
| Windows | `C:\Users\<USER>\.dbt\profiles.yml` |
| macOS   | `~/.dbt/profiles.yml`               |
| Linux   | `~/.dbt/profiles.yml`               |

### Créer le dossier .dbt (si inexistant)

```powershell
# Windows
mkdir $HOME\.dbt
```

```bash
# macOS / Linux
mkdir -p ~/.dbt
```

### Configuration pour Snowflake

Créer/éditer `~/.dbt/profiles.yml` :

```yaml
mon_projet:  # Doit correspondre au "profile" dans dbt_project.yml
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('DBT_SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('DBT_SNOWFLAKE_USER') }}"
      password: "{{ env_var('DBT_SNOWFLAKE_PASSWORD') }}"
      role: "{{ env_var('DBT_SNOWFLAKE_ROLE', 'TRANSFORMER') }}"
      warehouse: "{{ env_var('DBT_SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH') }}"
      database: "{{ env_var('DBT_SNOWFLAKE_DATABASE', 'ANALYTICS') }}"
      schema: dev_{{ env_var('USER', 'default') }}
      threads: 4

    prod:
      type: snowflake
      account: "{{ env_var('DBT_SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('DBT_SNOWFLAKE_USER') }}"
      password: "{{ env_var('DBT_SNOWFLAKE_PASSWORD') }}"
      role: TRANSFORMER
      warehouse: TRANSFORMING_WH
      database: ANALYTICS
      schema: prod
      threads: 8
```

### Configurer les variables d'environnement

#### Windows (PowerShell)

```powershell
# Définir pour la session courante
$env:DBT_SNOWFLAKE_ACCOUNT = "xy12345.eu-west-1"
$env:DBT_SNOWFLAKE_USER = "votre_user"
$env:DBT_SNOWFLAKE_PASSWORD = "votre_password"
$env:DBT_SNOWFLAKE_ROLE = "TRANSFORMER"
$env:DBT_SNOWFLAKE_WAREHOUSE = "COMPUTE_WH"
$env:DBT_SNOWFLAKE_DATABASE = "ANALYTICS"
```

#### macOS / Linux

```bash
# Définir pour la session courante
export DBT_SNOWFLAKE_ACCOUNT="xy12345.eu-west-1"
export DBT_SNOWFLAKE_USER="votre_user"
export DBT_SNOWFLAKE_PASSWORD="votre_password"
export DBT_SNOWFLAKE_ROLE="TRANSFORMER"
export DBT_SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
export DBT_SNOWFLAKE_DATABASE="ANALYTICS"
```

#### Avec fichier .env (Recommandé)

1. Créer un fichier `.env` à la racine du projet :

```env
DBT_SNOWFLAKE_ACCOUNT=xy12345.eu-west-1
DBT_SNOWFLAKE_USER=votre_user
DBT_SNOWFLAKE_PASSWORD=votre_password
DBT_SNOWFLAKE_ROLE=TRANSFORMER
DBT_SNOWFLAKE_WAREHOUSE=COMPUTE_WH
DBT_SNOWFLAKE_DATABASE=ANALYTICS
```

2. Charger les variables avant d'exécuter DBT :

```powershell
# Windows PowerShell
Get-Content .env | ForEach-Object {
    if ($_ -match '^([^#][^=]*)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}
```

```bash
# macOS / Linux
set -a && source .env && set +a
```

---

## Validation de l'Installation

### 1. Vérifier la version de DBT

```bash
dbt --version
```

### 2. Valider la configuration du projet

```bash
dbt debug
```

**Sortie attendue (tout doit être OK)** :

```
Configuration:
  profiles.yml file [OK found and valid]
  dbt_project.yml file [OK found and valid]

Required dependencies:
  - git [OK found]

Connection:
  account: xy12345.eu-west-1
  user: votre_user
  database: ANALYTICS
  schema: dev_votre_user
  warehouse: COMPUTE_WH
  role: TRANSFORMER
  Connection test: [OK connection ok]

All checks passed!
```

### 3. Valider la connexion au warehouse

```bash
dbt debug --connection
```

### 4. Installer les packages (si packages.yml existe)

```bash
dbt deps
```

### 5. Compiler les modèles (sans exécution)

```bash
dbt compile
```

### 6. Exécuter les modèles d'exemple

```bash
dbt run
```

### 7. Exécuter les tests

```bash
dbt test
```

---

## Commandes Utiles

### Gestion du Virtual Environment

```bash
# Activer le venv
# Windows: .\venv\Scripts\Activate.ps1
# Linux/macOS: source venv/bin/activate

# Désactiver le venv
deactivate

# Lister les packages installés
pip list

# Exporter les dépendances
pip freeze > requirements.txt

# Réinstaller depuis requirements
pip install -r requirements.txt
```

### Commandes DBT Essentielles

```bash
# Initialiser un projet
dbt init nom_projet

# Debug / Validation
dbt debug

# Installer les packages
dbt deps

# Compiler (sans exécuter)
dbt compile

# Exécuter tous les modèles
dbt run

# Exécuter un modèle spécifique
dbt run --select mon_modele

# Exécuter les tests
dbt test

# Charger les seeds
dbt seed

# Générer la documentation
dbt docs generate

# Servir la documentation
dbt docs serve

# Exécuter les snapshots
dbt snapshot

# Nettoyer les artefacts
dbt clean

# Afficher le DAG
dbt ls --output json
```

---

## Résolution des Problèmes Courants

### Erreur : "dbt command not found"

```bash
# Vérifier que le venv est activé
# Réinstaller dbt
pip install --force-reinstall dbt-core dbt-snowflake
```

### Erreur : "Could not find profile"

```bash
# Vérifier le nom du profile dans dbt_project.yml
# Vérifier que profiles.yml existe dans ~/.dbt/
dbt debug --config-dir
```

### Erreur : "Connection failed"

```bash
# Vérifier les variables d'environnement
echo $DBT_SNOWFLAKE_ACCOUNT  # Linux/macOS
echo $env:DBT_SNOWFLAKE_ACCOUNT  # Windows PowerShell

# Tester la connexion
dbt debug --connection
```

### Erreur PowerShell : "Execution Policy"

```powershell
# Autoriser les scripts pour l'utilisateur courant
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Checklist Installation Complète

- [ ] Python 3.8+ installé
- [ ] Virtual environment créé et activé
- [ ] DBT et adaptateur installés
- [ ] Projet initialisé avec `dbt init`
- [ ] `profiles.yml` configuré dans `~/.dbt/`
- [ ] Variables d'environnement définies
- [ ] `dbt debug` passe tous les checks
- [ ] `dbt run` fonctionne sur les modèles d'exemple

---

**Prochaine étape** : Consultez le guide Docker pour une installation conteneurisée.


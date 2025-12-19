# Guide de Validation - Projet et Profile DBT

Ce guide regroupe toutes les commandes de validation pour vérifier que votre installation, projet et connexion DBT fonctionnent correctement.

---

## Table des matières

1. [Validation de l'Installation](#validation-de-linstallation)
2. [Validation du Projet](#validation-du-projet)
3. [Validation du Profile](#validation-du-profile)
4. [Validation de la Connexion](#validation-de-la-connexion)
5. [Validation des Modèles](#validation-des-modèles)
6. [Validation Complète (Checklist)](#validation-complète-checklist)
7. [Diagnostic des Erreurs](#diagnostic-des-erreurs)

---

## Validation de l'Installation

### Vérifier la version de DBT

```bash
dbt --version
```

**Sortie attendue** :

```
Core:
  - installed: 1.7.4
  - latest:    1.7.4 - Up to date!

Plugins:
  - snowflake: 1.7.3 - Up to date!
```

### Vérifier les packages Python installés

```bash
pip list | grep dbt
```

**Sortie attendue** :

```
dbt-core                   1.7.4
dbt-extractor              0.5.1
dbt-snowflake              1.7.3
```

### Vérifier le chemin de l'exécutable DBT

```bash
# Linux / macOS
which dbt

# Windows PowerShell
Get-Command dbt
```

---

## Validation du Projet

### Vérifier la structure du projet

```bash
# Afficher l'arborescence du projet
# Linux / macOS
ls -la

# Windows PowerShell
Get-ChildItem
```

**Fichiers requis** :

| Fichier           | Description              | Obligatoire |
|-------------------|--------------------------|-------------|
| `dbt_project.yml` | Configuration du projet  | ✅ Oui ✅  |
| `models/`         | Dossier des modèles      | ✅ Oui ✅  |
| `profiles.yml`    | Connexion (dans ~/.dbt/) | ✅ Oui ✅  |
| `packages.yml`    | Dépendances externes     | ❌ Non ❌  |
| `macros/`         | Macros personnalisées    | ❌ Non ❌  |
| `seeds/`          | Fichiers CSV             | ❌ Non ❌  |
| `snapshots/`      | Snapshots SCD            | ❌ Non ❌  |
| `tests/`          | Tests singuliers         | ❌ Non ❌  |

### Valider le fichier dbt_project.yml

```bash
# Afficher le contenu
cat dbt_project.yml
```

**Éléments à vérifier** :

```yaml
name: 'mon_projet'           # Nom du projet (doit correspondre au dossier)
version: '1.0.0'
config-version: 2            # Doit être 2

profile: 'mon_projet'        # Doit correspondre au profile dans profiles.yml

model-paths: ["models"]
seed-paths: ["seeds"]
test-paths: ["tests"]
analysis-paths: ["analyses"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]
target-path: "target"
clean-targets: ["target", "dbt_packages"]
```

### Lister les modèles du projet

```bash
# Lister tous les modèles
dbt ls --resource-type model

# Lister avec les chemins complets
dbt ls --output path

# Lister en JSON
dbt ls --output json
```

### Valider le DAG (graphe de dépendances)

```bash
# Visualiser les dépendances
dbt ls --select +mon_modele+
```

---

## Validation du Profile

### Localiser le fichier profiles.yml

```bash
# Afficher le répertoire de configuration DBT
dbt debug --config-dir
```

**Emplacements par défaut** :

| OS      | Chemin                              |
|---------|-------------------------------------|
| Windows | `C:\Users\<USER>\.dbt\profiles.yml` |
| macOS   | `~/.dbt/profiles.yml`               |
| Linux   | `~/.dbt/profiles.yml`               |

### Vérifier le contenu du profile

```bash
# Linux / macOS
cat ~/.dbt/profiles.yml

# Windows PowerShell
Get-Content $HOME\.dbt\profiles.yml
```

### Valider la syntaxe YAML

```bash
# Le debug vérifie automatiquement la syntaxe
dbt debug
```

**Points à vérifier** :

1. Le nom du profile correspond au `profile:` dans `dbt_project.yml`
2. Le `target` par défaut existe dans `outputs`
3. Les indentations sont correctes (espaces, pas de tabs)
4. Les variables d'environnement sont définies

### Vérifier les variables d'environnement

```bash
# Linux / macOS
echo $DBT_SNOWFLAKE_ACCOUNT
echo $DBT_SNOWFLAKE_USER
echo $DBT_SNOWFLAKE_PASSWORD

# Windows PowerShell
echo $env:DBT_SNOWFLAKE_ACCOUNT
echo $env:DBT_SNOWFLAKE_USER
echo $env:DBT_SNOWFLAKE_PASSWORD
```

---

## Validation de la Connexion

### Test de connexion complet

```bash
dbt debug
```

**Sortie attendue (tous les checks doivent passer)** :

```
Running with dbt=1.7.4

dbt version: 1.7.4
python version: 3.10.12
python path: /path/to/python
os info: Windows-10-xxx

Configuration:
  profiles.yml file [OK found and valid]
  dbt_project.yml file [OK found and valid]

Required dependencies:
  - git [OK found]

Connection:
  account: xy12345.eu-west-1
  user: mon_user
  database: ANALYTICS
  warehouse: COMPUTE_WH
  role: TRANSFORMER
  schema: dev
  authenticator: snowflake
  Connection test: [OK connection ok]

All checks passed!
```

### Test de connexion seule

```bash
dbt debug --connection
```

### Vérifier l'accès au warehouse

```bash
# Exécuter une requête simple via macro
dbt run-operation test_connection
```

Créer une macro de test `macros/test_connection.sql` :

```sql
{% macro test_connection() %}
    {% set query %}
        SELECT 
            CURRENT_USER() as user,
            CURRENT_ROLE() as role,
            CURRENT_WAREHOUSE() as warehouse,
            CURRENT_DATABASE() as database,
            CURRENT_SCHEMA() as schema,
            CURRENT_TIMESTAMP() as timestamp
    {% endset %}
    
    {% set results = run_query(query) %}
    
    {% if execute %}
        {% for row in results %}
            {{ log("User: " ~ row['USER'], info=True) }}
            {{ log("Role: " ~ row['ROLE'], info=True) }}
            {{ log("Warehouse: " ~ row['WAREHOUSE'], info=True) }}
            {{ log("Database: " ~ row['DATABASE'], info=True) }}
            {{ log("Schema: " ~ row['SCHEMA'], info=True) }}
            {{ log("Timestamp: " ~ row['TIMESTAMP'], info=True) }}
        {% endfor %}
    {% endif %}
{% endmacro %}
```

---

## Validation des Modèles

### Compiler les modèles (sans exécution)

```bash
# Compiler tous les modèles
dbt compile

# Compiler un modèle spécifique
dbt compile --select mon_modele
```

**Vérifier le SQL compilé** :

```bash
# Le SQL généré est dans target/compiled/
cat target/compiled/mon_projet/models/staging/stg_customers.sql
```

### Exécuter les modèles

```bash
# Exécuter tous les modèles
dbt run

# Exécuter un modèle spécifique
dbt run --select mon_modele

# Exécuter avec ses dépendances
dbt run --select +mon_modele

# Exécuter avec ses dépendants
dbt run --select mon_modele+

# Dry run (voir ce qui serait exécuté)
dbt run --select mon_modele --empty
```

### Valider les résultats d'exécution

```bash
# Afficher le résumé d'exécution
cat target/run_results.json | python -m json.tool
```

### Exécuter les tests

```bash
# Tous les tests
dbt test

# Tests d'un modèle spécifique
dbt test --select mon_modele

# Tests de données uniquement
dbt test --select test_type:data

# Tests de schéma uniquement
dbt test --select test_type:schema
```

### Vérifier la fraîcheur des sources

```bash
dbt source freshness
```

---

## Validation Complète (Checklist)

### Script de validation automatique

Créer `scripts/validate.sh` (ou `.ps1` pour Windows) :

```bash
#!/bin/bash
# =============================================================================
# Script de validation complète DBT
# =============================================================================

set -e

echo "=========================================="
echo "VALIDATION DBT - Début"
echo "=========================================="

echo ""
echo "1. Vérification de la version DBT..."
dbt --version

echo ""
echo "2. Validation du debug (projet + profile + connexion)..."
dbt debug

echo ""
echo "3. Installation/mise à jour des packages..."
dbt deps

echo ""
echo "4. Compilation des modèles..."
dbt compile

echo ""
echo "5. Exécution des modèles..."
dbt run

echo ""
echo "6. Exécution des tests..."
dbt test

echo ""
echo "=========================================="
echo "VALIDATION DBT - Succès ✅"
echo "=========================================="
```

```powershell
# scripts/validate.ps1 - Version PowerShell
# =============================================================================
# Script de validation complète DBT
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "VALIDATION DBT - Début" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

Write-Host "`n1. Vérification de la version DBT..." -ForegroundColor Yellow
dbt --version

Write-Host "`n2. Validation du debug (projet + profile + connexion)..." -ForegroundColor Yellow
dbt debug

Write-Host "`n3. Installation/mise à jour des packages..." -ForegroundColor Yellow
dbt deps

Write-Host "`n4. Compilation des modèles..." -ForegroundColor Yellow
dbt compile

Write-Host "`n5. Exécution des modèles..." -ForegroundColor Yellow
dbt run

Write-Host "`n6. Exécution des tests..." -ForegroundColor Yellow
dbt test

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "VALIDATION DBT - Succès ✅" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
```

### Checklist manuelle

| Étape         | Commande         | Statut |
|---------------|------------------|--------|
| Version DBT   | `dbt --version`  | ☐ |
| Debug complet | `dbt debug`      | ☐ |
| Profil trouvé | (dans debug)     | ☐ |
| Projet valide | (dans debug)     | ☐ |
| Connexion OK  | (dans debug)     | ☐ |
| Dépendances   | `dbt deps`       | ☐ |
| Compilation   | `dbt compile`    | ☐ |
| Exécution     | `dbt run`        | ☐ |
| Tests         | `dbt test`       | ☐ |

---

## Diagnostic des Erreurs

### Erreur : "Could not find profile named 'xxx'"

**Cause** : Le profile dans `dbt_project.yml` ne correspond pas à `profiles.yml`.

**Solution** :

```bash
# Vérifier le nom du profile dans dbt_project.yml
grep "profile:" dbt_project.yml

# Vérifier les profiles disponibles
grep -E "^[a-zA-Z]" ~/.dbt/profiles.yml
```

### Erreur : "Connection failed"

**Causes possibles** :

1. Credentials incorrects
2. Warehouse non démarré
3. IP non autorisée
4. Rôle sans permissions

**Solutions** :

```bash
# Vérifier les variables d'environnement
env | grep DBT

# Tester avec des credentials en dur (temporairement)
# Vérifier le statut du warehouse dans Snowflake
```

### Erreur : "Compilation Error"

**Cause** : Erreur de syntaxe SQL ou Jinja.

**Solution** :

```bash
# Compiler le modèle spécifique pour voir l'erreur
dbt compile --select mon_modele

# Vérifier le SQL généré
cat target/compiled/mon_projet/models/.../mon_modele.sql
```

### Erreur : "Database Error"

**Cause** : Erreur SQL côté warehouse.

**Solution** :

```bash
# Vérifier le SQL exécuté
cat target/run/mon_projet/models/.../mon_modele.sql

# Exécuter le SQL directement dans le warehouse pour debug
```

### Erreur : "dbt command not found"

**Cause** : DBT non installé ou venv non activé.

**Solution** :

```bash
# Activer le venv
# Windows: .\venv\Scripts\Activate.ps1
# Linux: source venv/bin/activate

# Réinstaller si nécessaire
pip install dbt-core dbt-snowflake
```

### Erreur : "YAML syntax error"

**Cause** : Indentation ou syntaxe YAML incorrecte.

**Solution** :

```bash
# Valider le YAML en ligne : https://yamlvalidator.com/
# Vérifier les tabs vs espaces
# Vérifier les guillemets manquants
```

---

## Commandes de Debug Avancées

### Mode verbose

```bash
# Exécution avec logs détaillés
dbt run --debug

# Logs dans un fichier
dbt run --debug 2>&1 | tee dbt_debug.log
```

### Afficher le DAG complet

```bash
# Liste JSON de tous les modèles avec métadonnées
dbt ls --output json --output-keys unique_id resource_type depends_on
```

### Vérifier les artefacts

```bash
# Manifest (graphe complet)
cat target/manifest.json | python -m json.tool | head -100

# Résultats d'exécution
cat target/run_results.json | python -m json.tool

# Catalogue (documentation)
cat target/catalog.json | python -m json.tool | head -100
```

### Réinitialisation complète

```bash
# Nettoyer tous les artefacts
dbt clean

# Réinstaller les packages
dbt deps

# Exécution fraîche
dbt run --full-refresh
```

---

## Résumé des Commandes

| Action             | Commande |
|--------------------|----------|
| Version            | `dbt --version` |
| Debug complet      | `dbt debug` |
| Connexion seule    | `dbt debug --connection` |
| Installer packages | `dbt deps` |
| Compiler           | `dbt compile` |
| Exécuter           | `dbt run` |
| Tester             | `dbt test` |
| Fraîcheur sources  | `dbt source freshness` |
| Documentation      | `dbt docs generate && dbt docs serve` |
| Nettoyer           | `dbt clean` |
| Lister modèles     | `dbt ls` |
| Mode debug         | `dbt run --debug` |

---

**Votre installation est validée si toutes les étapes passent avec succès !** 🎉


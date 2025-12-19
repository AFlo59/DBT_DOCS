# Configuration dbt_project.yml

## 📋 Table des matières
1. [Vue d'ensemble](#vue-densemble)
2. [Structure du fichier](#structure-du-fichier)
3. [Propriétés obligatoires](#propriétés-obligatoires)
4. [Propriétés optionnelles](#propriétés-optionnelles)
5. [Configuration des modèles](#configuration-des-modèles)
6. [Configuration des seeds](#configuration-des-seeds)
7. [Configuration des snapshots](#configuration-des-snapshots)
8. [Variables](#variables)
9. [Exemples complets](#exemples-complets)

---

## Vue d'ensemble

### Qu'est-ce que dbt_project.yml ?

Le fichier `dbt_project.yml` est le **fichier de configuration principal** d'un projet DBT. Il définit :
- Les métadonnées du projet
- Les chemins vers les ressources
- Les configurations par défaut des modèles
- Les variables globales

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RÔLE DE dbt_project.yml                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  my_project/                                                        │
│  ├── dbt_project.yml  ◄─── Configuration centrale                   │
│  │                         - Nom du projet                          │
│  │                         - Chemins des ressources                 │
│  │                         - Config par défaut                      │
│  │                                                                  │
│  ├── models/                                                        │
│  ├── seeds/                                                         │
│  ├── snapshots/                                                     │
│  └── macros/                                                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Localisation

Le fichier doit être **à la racine du projet** :

```
my_dbt_project/
├── dbt_project.yml    ◄── Ici (obligatoire)
├── models/
├── seeds/
└── ...
```

---

## Structure du fichier

### Template minimal

```yaml
# dbt_project.yml

# Obligatoire
name: 'my_project'
version: '1.0.0'

# Requis pour dbt 1.5+
config-version: 2

# Profil de connexion (référence profiles.yml)
profile: 'my_profile'

# Configuration des modèles
models:
  my_project:
    +materialized: view
```

### Template complet

```yaml
# dbt_project.yml

# ═══════════════════════════════════════════════════════════════════
# MÉTADONNÉES DU PROJET
# ═══════════════════════════════════════════════════════════════════
name: 'my_analytics_project'
version: '1.0.0'
config-version: 2

# ═══════════════════════════════════════════════════════════════════
# CONNEXION
# ═══════════════════════════════════════════════════════════════════
profile: 'my_company_dwh'

# ═══════════════════════════════════════════════════════════════════
# CHEMINS (optionnels - valeurs par défaut)
# ═══════════════════════════════════════════════════════════════════
model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]
asset-paths: ["assets"]

# Dossier de sortie (compilé/exécuté)
target-path: "target"

# Fichiers à ignorer
clean-targets:
  - "target"
  - "dbt_packages"

# ═══════════════════════════════════════════════════════════════════
# VARIABLES GLOBALES
# ═══════════════════════════════════════════════════════════════════
vars:
  start_date: '2020-01-01'
  environment: 'dev'

# ═══════════════════════════════════════════════════════════════════
# CONFIGURATION DES RESSOURCES
# ═══════════════════════════════════════════════════════════════════
models:
  my_analytics_project:
    +materialized: view

seeds:
  my_analytics_project:
    +schema: seeds

snapshots:
  my_analytics_project:
    +target_schema: snapshots
```

---

## Propriétés obligatoires

### name

**Type :** String  
**Description :** Identifiant unique du projet

```yaml
name: 'my_project'
```

**Règles :**
- Doit correspondre à un identifiant valide (lettres, chiffres, underscores)
- Utilisé pour référencer les configurations dans le fichier
- Utilisé comme namespace pour les packages

### version

**Type :** String  
**Description :** Version sémantique du projet

```yaml
version: '1.0.0'
```

**Bonnes pratiques :**
- Suivre le versioning sémantique (MAJOR.MINOR.PATCH)
- Incrémenter lors des changements significatifs

### config-version

**Type :** Integer  
**Description :** Version du format de configuration

```yaml
config-version: 2
```

> ⚠️ **Important** : Toujours utiliser `config-version: 2` pour les projets modernes.

### profile

**Type :** String  
**Description :** Référence au profil dans `profiles.yml`

```yaml
profile: 'my_warehouse'
```

**Correspondance avec profiles.yml :**

```yaml
# profiles.yml
my_warehouse:        # ◄── Doit correspondre
  target: dev
  outputs:
    dev:
      type: snowflake
      ...
```

---

## Propriétés optionnelles

### Chemins des ressources

| Propriété        | Défaut          | Description                       |
|------------------|-----------------|-----------------------------------|
| `model-paths`    | `["models"]`    | Dossier des modèles SQL           |
| `seed-paths`     | `["seeds"]`     | Dossier des fichiers CSV          |
| `test-paths`     | `["tests"]`     | Dossier des tests singuliers      |
| `snapshot-paths` | `["snapshots"]` | Dossier des snapshots             |
| `macro-paths`    | `["macros"]`    | Dossier des macros Jinja          |
| `analysis-paths` | `["analyses"]`  | Dossier des analyses              |
| `asset-paths`    | `["assets"]`    | Dossier des assets (images, etc.) |

```yaml
# Personnalisation des chemins
model-paths: ["sql/models"]
seed-paths: ["data/seeds"]
macro-paths: ["sql/macros", "sql/utils"]  # Plusieurs chemins possibles
```

### target-path

```yaml
# Dossier de sortie (SQL compilé, manifests)
target-path: "target"
```

### clean-targets

```yaml
# Dossiers nettoyés par `dbt clean`
clean-targets:
  - "target"
  - "dbt_packages"
  - "logs"
```

### require-dbt-version

```yaml
# Contrainte de version DBT
require-dbt-version: ">=1.5.0"

# Ou avec borne supérieure
require-dbt-version: [">=1.5.0", "<2.0.0"]
```

---

## Configuration des modèles

### Syntaxe

```yaml
models:
  <project_name>:
    +<config_option>: <value>
    <folder_name>:
      +<config_option>: <value>
```

### Hiérarchie de configuration

```
┌─────────────────────────────────────────────────────────────────────┐
│               HIÉRARCHIE DE CONFIGURATION                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Priorité croissante (le plus spécifique gagne) :                   │
│                                                                     │
│  1. dbt_project.yml (niveau projet)     ─── Moins prioritaire       │
│  2. dbt_project.yml (niveau dossier)                                │
│  3. Fichier schema.yml                                              │
│  4. Bloc config() dans le modèle        ─── Plus prioritaire        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Options de configuration courantes

| Option         | Valeurs                                     | Description                  |
|----------------|---------------------------------------------|------------------------------|
| `materialized` | `view`, `table`, `incremental`, `ephemeral` | Type de matérialisation      |
| `schema`       | String                                      | Schéma cible                 |
| `database`     | String                                      | Base de données cible        |
| `tags`         | Liste                                       | Tags pour sélection          |
| `enabled`      | Boolean                                     | Activer/désactiver le modèle |
| `persist_docs` | Object                                      | Persister la documentation   |

### Exemple par dossier

```yaml
models:
  my_project:
    # Configuration globale pour tous les modèles
    +materialized: view
    +persist_docs:
      relation: true
      columns: true
    
    # Configuration pour le dossier staging
    staging:
      +materialized: view
      +schema: staging
      +tags: ['daily']
    
    # Configuration pour le dossier marts
    marts:
      +materialized: table
      +schema: marts
      
      # Sous-dossier finance
      finance:
        +schema: finance_marts
        +tags: ['finance', 'daily']
      
      # Sous-dossier marketing
      marketing:
        +schema: marketing_marts
```

### Résultat de la configuration

```
models/
├── staging/
│   └── stg_orders.sql       → VIEW dans schema "staging"
├── marts/
│   ├── finance/
│   │   └── fct_revenue.sql  → TABLE dans schema "finance_marts"
│   └── marketing/
│       └── dim_campaigns.sql → TABLE dans schema "marketing_marts"
```

---

## Configuration des seeds

### Syntaxe

```yaml
seeds:
  <project_name>:
    +<config_option>: <value>
```

### Options courantes

```yaml
seeds:
  my_project:
    # Schéma pour tous les seeds
    +schema: static_data
    
    # Surcharger les types de colonnes
    +column_types:
      id: varchar(50)
      amount: numeric(10,2)
    
    # Configuration par dossier
    lookups:
      +schema: lookups
      country_codes:
        +column_types:
          code: varchar(3)
```

### Exemple avec fichier CSV

```
seeds/
└── lookups/
    └── country_codes.csv
```

```csv
code,name,region
USA,United States,North America
FRA,France,Europe
JPN,Japan,Asia
```

---

## Configuration des snapshots

### Syntaxe

```yaml
snapshots:
  <project_name>:
    +<config_option>: <value>
```

### Options courantes

```yaml
snapshots:
  my_project:
    # Schéma cible pour les snapshots
    +target_schema: snapshots
    
    # Stratégie par défaut
    +strategy: timestamp
    
    # Configuration avancée
    +invalidate_hard_deletes: true
```

---

## Variables

### Définition

```yaml
vars:
  # Variables simples
  start_date: '2020-01-01'
  default_country: 'FR'
  
  # Variables par environnement (via profiles.yml)
  
  # Variables numériques
  lookback_days: 30
  
  # Variables booléennes
  enable_debug: false
```

### Utilisation dans les modèles

```sql
-- Accès à une variable
SELECT *
FROM {{ ref('orders') }}
WHERE order_date >= '{{ var("start_date") }}'

-- Avec valeur par défaut
WHERE country = '{{ var("default_country", "US") }}'
```

### Variables par scope de projet

```yaml
vars:
  # Variable globale
  global_start_date: '2020-01-01'
  
  # Variable spécifique au projet
  my_project:
    project_specific_var: 'value'
  
  # Variable d'un package importé
  dbt_utils:
    some_var: 'other_value'
```

### Surcharge en ligne de commande

```bash
# Surcharger une variable
dbt run --vars '{"start_date": "2023-01-01"}'

# Plusieurs variables
dbt run --vars '{"start_date": "2023-01-01", "enable_debug": true}'
```

---

## Exemples complets

### Projet simple (débutant)

```yaml
# dbt_project.yml - Projet simple

name: 'ecommerce_analytics'
version: '1.0.0'
config-version: 2

profile: 'ecommerce'

models:
  ecommerce_analytics:
    +materialized: view
    staging:
      +materialized: view
    marts:
      +materialized: table
```

### Projet intermédiaire

```yaml
# dbt_project.yml - Projet intermédiaire

name: 'company_analytics'
version: '2.1.0'
config-version: 2

profile: 'snowflake_prod'

require-dbt-version: ">=1.5.0"

vars:
  start_date: '2020-01-01'
  default_schema: 'analytics'

models:
  company_analytics:
    +persist_docs:
      relation: true
      columns: true
    
    staging:
      +materialized: view
      +schema: staging
    
    intermediate:
      +materialized: ephemeral
    
    marts:
      +materialized: table
      +schema: marts
      core:
        +schema: core_marts
      finance:
        +schema: finance_marts
        +tags: ['finance']

seeds:
  company_analytics:
    +schema: seeds

snapshots:
  company_analytics:
    +target_schema: snapshots
```

### Projet avancé (enterprise)

```yaml
# dbt_project.yml - Projet enterprise

name: 'enterprise_dwh'
version: '3.5.2'
config-version: 2

profile: 'enterprise_warehouse'

require-dbt-version: [">=1.6.0", "<2.0.0"]

# Chemins personnalisés
model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
clean-targets:
  - "target"
  - "dbt_packages"
  - "logs"

# Variables globales
vars:
  # Dates
  start_date: '2019-01-01'
  
  # Feature flags
  enable_pii_masking: true
  enable_row_level_security: false
  
  # Limites
  max_lookback_days: 365

# Query comportement
query-comment:
  comment: "dbt {{ node.unique_id }}"
  append: true

# Dispatching de macros
dispatch:
  - macro_namespace: dbt_utils
    search_order: ['my_project', 'dbt_utils']

# Configuration des modèles
models:
  enterprise_dwh:
    # Configuration globale
    +persist_docs:
      relation: true
      columns: true
    +on_schema_change: "append_new_columns"
    
    # Couche Source/Staging
    staging:
      +materialized: view
      +schema: staging
      +tags: ['staging']
      
      # Par source
      salesforce:
        +schema: stg_salesforce
      stripe:
        +schema: stg_stripe
      google_analytics:
        +schema: stg_ga
    
    # Couche Intermediate
    intermediate:
      +materialized: ephemeral
      +schema: intermediate
    
    # Couche Marts (Dimensionnel)
    marts:
      +materialized: table
      +tags: ['marts']
      
      core:
        +schema: core
        +post-hook:
          - "GRANT SELECT ON {{ this }} TO ROLE analyst_role"
      
      finance:
        +schema: finance
        +tags: ['finance', 'confidential']
        +post-hook:
          - "GRANT SELECT ON {{ this }} TO ROLE finance_role"
      
      marketing:
        +schema: marketing
        +materialized: incremental
        +incremental_strategy: merge
        +unique_key: id
    
    # Modèles Exposés (API)
    exports:
      +materialized: table
      +schema: exports
      +tags: ['external']

# Configuration des seeds
seeds:
  enterprise_dwh:
    +schema: reference_data
    +quote_columns: true
    
    mappings:
      +column_types:
        source_code: varchar(10)
        target_code: varchar(10)

# Configuration des snapshots
snapshots:
  enterprise_dwh:
    +target_schema: snapshots
    +strategy: timestamp
    +updated_at: updated_at
    +invalidate_hard_deletes: true

# Configuration des tests
tests:
  enterprise_dwh:
    +severity: error
    +store_failures: true
```

---

## Validation

### Vérifier la syntaxe

```bash
# Parse le projet sans exécuter
dbt parse

# Debug complet
dbt debug
```

### Erreurs courantes

| Erreur              | Cause                             | Solution                              |
|---------------------|-----------------------------------|---------------------------------------|
| `name` invalide     | Caractères spéciaux               | Utiliser uniquement `a-z`, `0-9`, `_` |
| `profile` not found | Profil manquant dans profiles.yml | Créer le profil                       |
| Indentation YAML    | Espaces/tabs mélangés             | Utiliser uniquement des espaces       |
| `+` manquant        | Oubli du préfixe                  | Ajouter `+` devant les configs        |

---

## Résumé

| Section         | Description                                        |
|-----------------|----------------------------------------------------|
| **Métadonnées** | `name`, `version`, `config-version`, `profile`     |
| **Chemins**     | `model-paths`, `seed-paths`, `macro-paths`, etc.   |
| **Variables**   | `vars` - valeurs globales réutilisables            |
| **Models**      | Configuration par dossier, matérialisation, schéma |
| **Seeds**       | Types de colonnes, schéma cible                    |
| **Snapshots**   | Stratégie, schéma cible                            |

---

## Prochaines étapes

→ [Configuration profiles.yml](./03-profiles-yml.md)


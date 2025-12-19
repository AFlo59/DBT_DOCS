# Packages DBT

## 📋 Table des matières
1. [Concept des packages](#concept-des-packages)
2. [Installation de packages](#installation-de-packages)
3. [Packages populaires](#packages-populaires)
4. [Utilisation des packages](#utilisation-des-packages)
5. [Créer son propre package](#créer-son-propre-package)

---

## Concept des packages

### Qu'est-ce qu'un package ?

Un **package DBT** est une collection de macros, tests, et modèles réutilisables que vous pouvez importer dans votre projet.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PACKAGES DBT                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   packages.yml                       dbt_packages/                   │
│   ┌──────────────────┐              ┌───────────────────────────┐   │
│   │ packages:        │   dbt deps   │ dbt_utils/                │   │
│   │   - package:     │ ──────────>  │   ├── macros/             │   │
│   │       dbt-labs/  │              │   │   └── generate_key... │   │
│   │       dbt_utils  │              │   └── tests/              │   │
│   │     version: 1.1.1│             │ dbt_expectations/         │   │
│   └──────────────────┘              │   └── ...                 │   │
│                                      └───────────────────────────┘   │
│                                                                      │
│   Utilisation :                                                      │
│   {{ dbt_utils.generate_surrogate_key(['col1', 'col2']) }}          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Avantages

| Avantage | Description |
|----------|-------------|
| **Réutilisation** | Ne pas réinventer la roue |
| **Qualité** | Code testé par la communauté |
| **Standardisation** | Macros communes entre projets |
| **Maintenance** | Mises à jour par les mainteneurs |

---

## Installation de packages

### Fichier packages.yml

Créer un fichier `packages.yml` à la racine du projet :

```yaml
# packages.yml

packages:
  # Package depuis dbt Hub
  - package: dbt-labs/dbt_utils
    version: 1.1.1
  
  # Package depuis Git
  - git: https://github.com/dbt-labs/dbt-utils.git
    revision: 1.1.1  # tag, branch, ou commit
  
  # Package local
  - local: ../shared-macros
```

### Commande dbt deps

```bash
# Installer les packages
dbt deps

# Les packages sont téléchargés dans dbt_packages/
```

### Versioning

```yaml
packages:
  # Version exacte
  - package: dbt-labs/dbt_utils
    version: 1.1.1
  
  # Range de versions
  - package: dbt-labs/dbt_utils
    version: [">=1.0.0", "<2.0.0"]
  
  # Dernière version compatible
  - package: dbt-labs/dbt_utils
    version: ">=1.1.0"
```

### .gitignore

```gitignore
# Packages téléchargés (ne pas versionner)
dbt_packages/
```

---

## Packages populaires

### dbt_utils (indispensable)

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

**Macros utiles :**

```sql
-- Génération de clé de substitution
{{ dbt_utils.generate_surrogate_key(['order_id', 'product_id']) }}

-- Pivot
{{ dbt_utils.pivot('status', dbt_utils.get_column_values('orders', 'status')) }}

-- Date spine (calendrier)
{{ dbt_utils.date_spine(
    datepart="day",
    start_date="cast('2020-01-01' as date)",
    end_date="current_date"
) }}

-- Star schema helpers
{{ dbt_utils.star(ref('dim_customers'), except=['_loaded_at']) }}

-- Get column names
{% set columns = dbt_utils.get_filtered_columns_in_relation(ref('my_model')) %}
```

**Tests :**

```yaml
tests:
  - dbt_utils.unique_combination_of_columns:
      combination_of_columns: ['order_id', 'line_item_id']
  - dbt_utils.at_least_one
  - dbt_utils.recency:
      datepart: day
      field: created_at
      interval: 1
  - dbt_utils.accepted_range:
      min_value: 0
      max_value: 1000
```

### dbt_expectations

```yaml
packages:
  - package: calogica/dbt_expectations
    version: 0.10.1
```

**Tests inspirés de Great Expectations :**

```yaml
tests:
  - dbt_expectations.expect_column_values_to_not_be_null
  - dbt_expectations.expect_column_values_to_be_unique
  - dbt_expectations.expect_column_values_to_match_regex:
      regex: '^[A-Z]{3}$'
  - dbt_expectations.expect_column_values_to_be_between:
      min_value: 0
      max_value: 100
  - dbt_expectations.expect_table_row_count_to_be_between:
      min_value: 1
      max_value: 1000000
```

### dbt_date

```yaml
packages:
  - package: calogica/dbt_date
    version: 0.10.0
```

**Macros de dates :**

```sql
-- Obtenir toutes les dates entre deux dates
{{ dbt_date.get_date_dimension('2020-01-01', '2024-12-31') }}

-- Début/fin de période
{{ dbt_date.week_start('order_date') }}
{{ dbt_date.month_end('order_date') }}
{{ dbt_date.fiscal_year('order_date', month_offset=3) }}
```

### audit_helper

```yaml
packages:
  - package: dbt-labs/audit_helper
    version: 0.9.0
```

**Comparaison de données :**

```sql
-- Comparer deux relations
{{ audit_helper.compare_relations(
    a_relation=ref('fct_orders_old'),
    b_relation=ref('fct_orders_new'),
    primary_key='order_id'
) }}

-- Comparer les résultats de deux queries
{{ audit_helper.compare_queries(
    a_query="SELECT * FROM table_a",
    b_query="SELECT * FROM table_b"
) }}
```

### dbt_artifacts

```yaml
packages:
  - package: brooklyn-data/dbt_artifacts
    version: 2.6.2
```

Capture les métadonnées d'exécution dans des tables.

### codegen

```yaml
packages:
  - package: dbt-labs/codegen
    version: 0.12.1
```

**Génération de code :**

```bash
# Générer un fichier source YAML
dbt run-operation generate_source --args '{"schema_name": "raw", "database_name": "raw_db"}'

# Générer un model staging
dbt run-operation generate_base_model --args '{"source_name": "shopify", "table_name": "orders"}'
```

---

## Utilisation des packages

### Appeler une macro de package

```sql
-- Syntaxe : {{ package_name.macro_name(args) }}

SELECT
    {{ dbt_utils.generate_surrogate_key(['order_id', 'product_id']) }} AS unique_key,
    order_id,
    product_id
FROM {{ ref('stg_orders') }}
```

### Utiliser un model de package

```sql
-- Référencer un model d'un package
SELECT * FROM {{ ref('dbt_utils', 'date_spine') }}
```

### Override une macro de package

```sql
-- macros/generate_schema_name.sql

{# Override la macro de dbt_utils #}
{% macro generate_schema_name(custom_schema_name, node) %}
    {# Votre logique personnalisée #}
{% endmacro %}
```

### Configuration dispatch

```yaml
# dbt_project.yml

dispatch:
  - macro_namespace: dbt_utils
    search_order: ['my_project', 'dbt_utils']
```

---

## Créer son propre package

### Structure d'un package

```
my_shared_macros/
├── dbt_project.yml
├── macros/
│   ├── utils.sql
│   └── transformations.sql
├── models/
│   └── utilities/
│       └── dim_date.sql
└── README.md
```

### dbt_project.yml du package

```yaml
# my_shared_macros/dbt_project.yml

name: 'my_shared_macros'
version: '1.0.0'
config-version: 2

# Pas de profile car c'est un package
```

### Utilisation comme package local

```yaml
# packages.yml du projet consommateur

packages:
  - local: ../my_shared_macros
```

### Publication sur GitHub

```yaml
# packages.yml

packages:
  - git: https://github.com/myorg/my-dbt-package.git
    revision: v1.0.0
```

### Publication sur dbt Hub

1. Suivre les guidelines de dbt Hub
2. Soumettre le package pour review
3. Une fois accepté, utilisable via `package:`

---

## Résumé

### Installation

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

```bash
dbt deps
```

### Packages essentiels

| Package | Usage |
|---------|-------|
| `dbt_utils` | Utilitaires généraux |
| `dbt_expectations` | Tests avancés |
| `dbt_date` | Manipulation de dates |
| `audit_helper` | Comparaison de données |
| `codegen` | Génération de code |

### Checklist

- [ ] Créer `packages.yml`
- [ ] Ajouter `dbt_packages/` au `.gitignore`
- [ ] Exécuter `dbt deps` après clone
- [ ] Documenter les packages utilisés
- [ ] Fixer les versions des packages

---

## Prochaines étapes

→ [Utilisation des seeds](../09-seeds/01-utilisation-seeds.md)


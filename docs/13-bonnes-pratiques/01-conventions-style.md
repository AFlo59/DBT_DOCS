# Conventions et Style DBT

## 📋 Table des matières
1. [Style SQL](#style-sql)
2. [Structure des models](#structure-des-models)
3. [Organisation du projet](#organisation-du-projet)
4. [Documentation](#documentation)
5. [Checklist de qualité](#checklist-de-qualité)

---

## Style SQL

### Formatage de base

```sql
-- ✅ BON STYLE

SELECT
    customer_id,
    customer_name,
    LOWER(email) AS email,
    DATE_TRUNC('month', created_at) AS created_month,
    CASE
        WHEN lifetime_value >= 1000 THEN 'VIP'
        WHEN lifetime_value >= 100 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment
FROM {{ ref('stg_customers') }}
WHERE is_active = TRUE
  AND created_at >= '2020-01-01'
ORDER BY customer_id
```

### Règles de formatage

| Règle | Exemple |
|-------|---------|
| **Mots-clés en majuscules** | `SELECT`, `FROM`, `WHERE` |
| **Noms en minuscules** | `customer_id`, `order_total` |
| **Indentation 4 espaces** | Pas de tabs |
| **Une colonne par ligne** | Après le premier SELECT |
| **Virgule en début de ligne** | Optionnel mais cohérent |

### Style des colonnes

```sql
-- Style virgule en fin de ligne (courant)
SELECT
    customer_id,
    customer_name,
    email

-- Style virgule en début de ligne (facilite les diffs)
SELECT
    customer_id
    , customer_name
    , email
```

### CTEs (Common Table Expressions)

```sql
-- ✅ BON : CTEs nommées clairement
WITH source_data AS (
    SELECT * FROM {{ source('raw', 'orders') }}
),

cleaned_data AS (
    SELECT
        id AS order_id,
        TRIM(customer_name) AS customer_name
    FROM source_data
    WHERE id IS NOT NULL
),

final AS (
    SELECT * FROM cleaned_data
)

SELECT * FROM final
```

### Aliasing

```sql
-- ✅ BON : Alias explicites avec AS
SELECT
    c.customer_id,
    c.customer_name,
    o.order_total AS total_amount  -- AS explicite
FROM {{ ref('dim_customers') }} AS c  -- AS pour les tables aussi
LEFT JOIN {{ ref('fct_orders') }} AS o
    ON c.customer_id = o.customer_id

-- ❌ ÉVITER : Alias implicites
SELECT
    customer_id id,  -- Pas de AS
    c.customer_name
FROM customers c  -- Pas de AS
```

### JOINs

```sql
-- ✅ BON : Jointures claires
SELECT
    o.order_id,
    c.customer_name,
    p.product_name
FROM {{ ref('fct_orders') }} AS o
LEFT JOIN {{ ref('dim_customers') }} AS c
    ON o.customer_id = c.customer_id
LEFT JOIN {{ ref('dim_products') }} AS p
    ON o.product_id = p.product_id
WHERE o.order_status = 'completed'

-- Toujours expliciter le type de JOIN (LEFT, INNER, etc.)
-- Ne pas utiliser RIGHT JOIN (inverser les tables)
```

### CASE WHEN

```sql
-- ✅ BON : CASE sur plusieurs lignes
CASE
    WHEN amount > 1000 THEN 'High'
    WHEN amount > 100 THEN 'Medium'
    ELSE 'Low'
END AS amount_category

-- ❌ ÉVITER : CASE sur une ligne
CASE WHEN amount > 1000 THEN 'High' WHEN amount > 100 THEN 'Medium' ELSE 'Low' END
```

---

## Structure des models

### Template de model staging

```sql
-- models/staging/shopify/stg_shopify__orders.sql

WITH source AS (
    SELECT * FROM {{ source('shopify', 'orders') }}
),

renamed AS (
    SELECT
        -- Primary key
        id AS order_id,
        
        -- Foreign keys
        customer_id,
        
        -- Attributes
        TRIM(status) AS order_status,
        LOWER(email) AS customer_email,
        
        -- Numerics
        CAST(total_price AS DECIMAL(10,2)) AS order_total,
        
        -- Dates
        CAST(created_at AS TIMESTAMP) AS ordered_at,
        CAST(updated_at AS TIMESTAMP) AS updated_at,
        
        -- Metadata
        _loaded_at
        
    FROM source
)

SELECT * FROM renamed
WHERE order_id IS NOT NULL
```

### Template de model marts

```sql
-- models/marts/core/fct_orders.sql

{{
    config(
        materialized='table',
        schema='core'
    )
}}

/*
    Fact table: Orders
    Grain: One row per order
    Description: All completed orders with customer and product details
*/

WITH orders AS (
    SELECT * FROM {{ ref('stg_shopify__orders') }}
),

customers AS (
    SELECT * FROM {{ ref('dim_customers') }}
),

-- Join and enrich
enriched AS (
    SELECT
        -- Keys
        o.order_id,
        o.customer_id,
        
        -- Customer attributes (denormalized)
        c.customer_name,
        c.customer_segment,
        
        -- Order attributes
        o.order_status,
        o.order_total,
        
        -- Dates
        o.ordered_at,
        DATE(o.ordered_at) AS order_date,
        
        -- Calculated fields
        ROW_NUMBER() OVER (
            PARTITION BY o.customer_id 
            ORDER BY o.ordered_at
        ) AS customer_order_number
        
    FROM orders AS o
    LEFT JOIN customers AS c
        ON o.customer_id = c.customer_id
)

SELECT * FROM enriched
WHERE order_status = 'completed'
```

---

## Organisation du projet

### Structure de dossiers

```
my_project/
├── dbt_project.yml
├── packages.yml
│
├── models/
│   ├── staging/              # Sources nettoyées
│   │   ├── shopify/
│   │   │   ├── _shopify__sources.yml
│   │   │   ├── _shopify__models.yml
│   │   │   └── stg_shopify__*.sql
│   │   └── stripe/
│   │       └── ...
│   │
│   ├── intermediate/         # Logique métier
│   │   └── int_*.sql
│   │
│   ├── marts/                # Tables finales
│   │   ├── core/
│   │   │   ├── _core__models.yml
│   │   │   ├── dim_*.sql
│   │   │   └── fct_*.sql
│   │   └── finance/
│   │       └── ...
│   │
│   └── docs/                 # Documentation
│       ├── __overview__.md
│       └── columns.md
│
├── seeds/                    # Données CSV
│   └── country_codes.csv
│
├── snapshots/                # SCD Type 2
│   └── snap_customers.sql
│
├── macros/                   # Macros réutilisables
│   ├── utils/
│   └── tests/
│
├── tests/                    # Tests singuliers
│   └── assert_*.sql
│
└── analyses/                 # Analyses non matérialisées
    └── ad_hoc_*.sql
```

### Conventions de nommage

| Élément | Convention | Exemple |
|---------|------------|---------|
| **Staging** | `stg_<source>__<table>` | `stg_shopify__orders` |
| **Intermediate** | `int_<description>` | `int_orders_enriched` |
| **Fact** | `fct_<événement>` | `fct_orders` |
| **Dimension** | `dim_<entité>` | `dim_customers` |
| **Snapshot** | `snap_<table>` | `snap_customers` |
| **Colonne PK** | `<entity>_id` | `customer_id` |
| **Colonne date** | `<action>_at` ou `_date` | `created_at` |
| **Colonne bool** | `is_`, `has_`, `was_` | `is_active` |

---

## Documentation

### Schema.yml complet

```yaml
version: 2

models:
  - name: fct_orders
    description: |
      ## Description
      Table de faits des commandes complétées.
      
      ## Grain
      Une ligne par commande (order_id).
      
      ## Sources
      - stg_shopify__orders
      - dim_customers
      
      ## Mise à jour
      Quotidienne à 6h UTC.
      
    config:
      tags: ['daily', 'core']
      
    columns:
      - name: order_id
        description: "Clé primaire - identifiant unique de la commande"
        tests:
          - unique
          - not_null
          
      - name: customer_id
        description: "FK vers dim_customers"
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
              
      - name: order_total
        description: "Montant total TTC en EUR"
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
```

### Commentaires dans le SQL

```sql
/*
==========================================================================
Model: fct_orders
Description: Completed orders with customer details
Author: Data Team
Last Modified: 2024-01-15
==========================================================================

Changelog:
- 2024-01-15: Added customer_segment
- 2024-01-01: Initial creation

Notes:
- Excludes cancelled orders
- Amounts are in EUR TTC
==========================================================================
*/

{{ config(materialized='table') }}

-- Import CTEs
WITH orders AS (
    -- Raw orders from Shopify
    SELECT * FROM {{ ref('stg_shopify__orders') }}
),

-- ... rest of the model
```

---

## Checklist de qualité

### Avant de merger

```
□ CODE STYLE
  ├── Mots-clés SQL en majuscules
  ├── Noms de colonnes en snake_case
  ├── Indentation cohérente (4 espaces)
  ├── CTEs nommées clairement
  └── Alias explicites avec AS

□ STRUCTURE
  ├── Préfixe correct (stg_, int_, fct_, dim_)
  ├── Fichier dans le bon dossier
  ├── Conventions de nommage respectées
  └── Config appropriée (materialized, schema)

□ QUALITÉ
  ├── Tests sur la PK (unique, not_null)
  ├── Tests sur les FK (relationships)
  ├── Pas de SELECT *
  └── Gestion des NULL

□ DOCUMENTATION
  ├── Description du model
  ├── Description des colonnes clés
  ├── Grain explicité
  └── Tags appropriés

□ PERFORMANCE
  ├── Matérialisation appropriée
  ├── Filtres WHERE en amont
  └── Pas de jointures inutiles
```

### Revue de code

```sql
-- Questions à se poser :

-- 1. Est-ce que le nom est clair ?
-- 2. Est-ce que le grain est explicite ?
-- 3. Les CTEs sont-elles nécessaires ?
-- 4. Les tests couvrent-ils les cas critiques ?
-- 5. La documentation est-elle suffisante ?
-- 6. Y a-t-il des duplications à factoriser ?
```

---

## Résumé

### Style SQL

| Règle | Application |
|-------|-------------|
| Majuscules | Mots-clés SQL |
| Minuscules | Noms, colonnes, tables |
| CTEs | Toujours, bien nommées |
| AS | Toujours explicite |

### Structure

| Couche | Préfixe | Matérialisation |
|--------|---------|-----------------|
| Staging | `stg_` | view |
| Intermediate | `int_` | ephemeral |
| Marts | `fct_`, `dim_` | table |

### Documentation

- Description de chaque model
- Description des colonnes clés
- Tests sur PK et FK
- Tags cohérents

---

## Prochaines étapes

→ [Performance](./02-performance.md)


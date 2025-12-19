# Types de Models : Staging, Intermediate, Marts

## 📋 Table des matières
1. [Vue d'ensemble](#vue-densemble)
2. [Couche Staging](#couche-staging)
3. [Couche Intermediate](#couche-intermediate)
4. [Couche Marts](#couche-marts)
5. [Flux de données complet](#flux-de-données-complet)
6. [Quand utiliser quelle couche](#quand-utiliser-quelle-couche)

---

## Vue d'ensemble

### Architecture en couches

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ARCHITECTURE EN 3 COUCHES                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  SOURCES                STAGING              INTERMEDIATE           │
│  (Données brutes)       (Nettoyage)          (Préparation)          │
│                                                                     │
│  ┌──────────────┐      ┌──────────────┐     ┌──────────────┐        │
│  │ raw.orders   │─────>│ stg_orders   │────>│ int_orders   │        │
│  └──────────────┘      └──────────────┘     │ _enriched    │        │
│                                             └───────┬──────┘        │
│  ┌──────────────┐      ┌──────────────┐             │               │
│  │raw.customers │─────>│stg_customers │─────────────┤               │
│  └──────────────┘      └──────────────┘             │               │
│                                                     │               │
│                                                     ▼               │
│                                              ┌──────────────┐       │
│                         MARTS                │  fct_orders  │       │
│                    (Tables finales)          ├──────────────┤       │
│                                              │dim_customers │       │
│                                              └──────────────┘       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Caractéristiques par couche

| Couche           | Préfixe        | Matérialisation | Audience            |
|------------------|----------------|-----------------|---------------------|
| **Staging**      | `stg_`         | VIEW            | Data Engineers      |
| **Intermediate** | `int_`         | EPHEMERAL/VIEW  | Analytics Engineers |
| **Marts**        | `fct_`, `dim_` | TABLE           | Utilisateurs finaux |

---

## Couche Staging

### Objectif

La couche staging est la **première transformation** des données brutes. Son rôle est limité et précis :

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RÈGLES DU STAGING                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ✅ CE QU'ON FAIT ✅                                               │
│  ─────────────────                                                  │
│  • Renommer les colonnes (conventions)                              │
│  • Caster les types de données                                      │
│  • Conversion d'unités basique                                      │
│  • Filtrer les lignes invalides (NULL IDs)                          │
│  • Dédupliquer si nécessaire                                        │
│                                                                     │
│  ❌ CE QU'ON NE FAIT PAS ❌                                        │
│  ────────────────────────                                           │
│  • Jointures entre sources                                          │
│  • Calculs métier                                                   │
│  • Agrégations                                                      │
│  • Logique conditionnelle complexe                                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Convention de nommage

```
stg_<source>__<table>
```

```
stg_shopify__orders        ← Source: Shopify, Table: orders
stg_stripe__payments       ← Source: Stripe, Table: payments
stg_hubspot__contacts      ← Source: HubSpot, Table: contacts
```

### Structure type

```sql
-- models/staging/shopify/stg_shopify__orders.sql

WITH source AS (
    -- 1. Référence à la source
    SELECT * FROM {{ source('shopify', 'orders') }}
),

renamed AS (
    SELECT
        -- 2. Renommage avec conventions
        id AS order_id,
        customer_id,
        
        -- 3. Casting des types
        CAST(total_price AS DECIMAL(10,2)) AS order_total,
        CAST(subtotal_price AS DECIMAL(10,2)) AS order_subtotal,
        
        -- 4. Transformation des timestamps
        CAST(created_at AS TIMESTAMP) AS ordered_at,
        CAST(updated_at AS TIMESTAMP) AS updated_at,
        
        -- 5. Nettoyage basique
        LOWER(TRIM(email)) AS customer_email,
        UPPER(currency) AS currency_code,
        
        -- 6. Standardisation des booléens
        CASE 
            WHEN cancelled = 'true' THEN TRUE 
            ELSE FALSE 
        END AS is_cancelled,
        
        -- 7. Colonnes d'audit
        _loaded_at AS _loaded_at
        
    FROM source
)

SELECT * FROM renamed
-- 8. Filtrage des données invalides
WHERE order_id IS NOT NULL
```

### Exemple complet avec sources.yml

```yaml
# models/staging/shopify/_shopify__sources.yml

sources:
  - name: shopify
    description: "Données e-commerce Shopify"
    database: raw_data
    schema: shopify
    
    tables:
      - name: orders
        description: "Commandes Shopify"
        columns:
          - name: id
            description: "ID de la commande"
          - name: customer_id
            description: "ID du client"
          - name: total_price
            description: "Prix total en centimes"
            
      - name: customers
        description: "Clients Shopify"
```

```sql
-- models/staging/shopify/stg_shopify__customers.sql

WITH source AS (
    SELECT * FROM {{ source('shopify', 'customers') }}
),

renamed AS (
    SELECT
        id AS customer_id,
        TRIM(first_name) AS first_name,
        TRIM(last_name) AS last_name,
        CONCAT(TRIM(first_name), ' ', TRIM(last_name)) AS full_name,
        LOWER(TRIM(email)) AS email,
        CAST(created_at AS TIMESTAMP) AS created_at,
        COALESCE(verified_email, FALSE) AS is_email_verified
    FROM source
)

SELECT * FROM renamed
WHERE customer_id IS NOT NULL
```

### Configuration staging

```yaml
# dbt_project.yml
models:
  my_project:
    staging:
      +materialized: view
      +schema: staging
```

---

## Couche Intermediate

### Objectif

La couche intermediate contient la **logique métier complexe** et prépare les données pour les marts.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RÈGLES DE L'INTERMEDIATE                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ✅ CE QU'ON FAIT ✅                                               │
│  ─────────────────                                                  │
│  • Jointures entre modèles staging                                  │
│  • Calculs et métriques                                             │
│  • Agrégations partielles                                           │
│  • Logique métier                                                   │
│  • Transformations complexes                                        │
│                                                                     │
│  🎯 OBJECTIF 🎯                                                    │
│  ────────────                                                       │
│  Préparer les données pour qu'un SELECT simple                      │
│  suffise dans les marts                                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Convention de nommage

```
int_<description_claire>
```

```
int_orders_with_payments
int_customer_order_metrics
int_daily_revenue_by_product
```

### Exemple : Enrichissement

```sql
-- models/intermediate/int_orders_enriched.sql

{{
    config(
        materialized='ephemeral'  -- Pas de table créée
    )
}}

WITH orders AS (
    SELECT * FROM {{ ref('stg_shopify__orders') }}
),

customers AS (
    SELECT * FROM {{ ref('stg_shopify__customers') }}
),

payments AS (
    SELECT * FROM {{ ref('stg_stripe__payments') }}
),

-- Jointure orders + customers
orders_with_customers AS (
    SELECT
        o.order_id,
        o.ordered_at,
        o.order_total,
        o.currency_code,
        
        c.customer_id,
        c.full_name AS customer_name,
        c.email AS customer_email,
        c.created_at AS customer_created_at
        
    FROM orders o
    LEFT JOIN customers c
        ON o.customer_id = c.customer_id
),

-- Ajout des paiements
final AS (
    SELECT
        oc.*,
        
        p.payment_method,
        p.paid_at,
        p.payment_status,
        
        -- Calcul : délai de paiement
        DATEDIFF('hour', oc.ordered_at, p.paid_at) AS hours_to_payment,
        
        -- Calcul : nouveau client ?
        CASE 
            WHEN oc.ordered_at = oc.customer_created_at THEN TRUE
            ELSE FALSE 
        END AS is_first_order
        
    FROM orders_with_customers oc
    LEFT JOIN payments p
        ON oc.order_id = p.order_id
)

SELECT * FROM final
```

### Exemple : Agrégation par client

```sql
-- models/intermediate/int_customer_order_metrics.sql

WITH orders AS (
    SELECT * FROM {{ ref('int_orders_enriched') }}
),

customer_metrics AS (
    SELECT
        customer_id,
        customer_name,
        customer_email,
        
        -- Métriques de commandes
        COUNT(*) AS total_orders,
        SUM(order_total) AS lifetime_value,
        AVG(order_total) AS average_order_value,
        
        -- Dates clés
        MIN(ordered_at) AS first_order_at,
        MAX(ordered_at) AS last_order_at,
        
        -- Calculs dérivés
        DATEDIFF('day', MIN(ordered_at), MAX(ordered_at)) AS customer_lifespan_days
        
    FROM orders
    GROUP BY 1, 2, 3
)

SELECT * FROM customer_metrics
```

### Matérialisation Ephemeral

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EPHEMERAL = CTE INLINE                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   int_orders_enriched.sql                                           │
│   (materialized='ephemeral')                                        │
│            │                                                        │
│            │ Pas de table créée !                                   │
│            │ Le SQL est injecté comme CTE                           │
│            ▼                                                        │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │ -- fct_orders.sql (compilé)                                 │   │
│   │ WITH int_orders_enriched AS (                               │   │
│   │     -- Contenu de int_orders_enriched.sql injecté ici       │   │
│   │ )                                                           │   │
│   │ SELECT * FROM int_orders_enriched                           │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   Avantage : Pas de table intermédiaire à maintenir                 │
│   Inconvénient : Query plus longue, réexécutée à chaque ref()       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Couche Marts

### Objectif

Les marts sont les **tables finales** consommées par les utilisateurs et outils BI.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CARACTÉRISTIQUES DES MARTS                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  📊 AUDIENCE 📊                                                    │
│  ────────────                                                       │
│  • Analystes métier                                                 │
│  • Outils BI (Tableau, Looker, Power BI)                            │
│  • Data Scientists                                                  │
│  • Applications                                                     │
│                                                                     │
│  🎯 OBJECTIFS 🎯                                                   │
│  ────────────                                                       │
│  • Faciles à comprendre                                             │
│  • Bien documentés                                                  │
│  • Performants (optimisés pour les queries)                         │
│  • Stables (contrat avec les consommateurs)                         │
│                                                                     │
│  📐 MODÉLISATION 📐                                                │
│  ──────────────                                                     │
│  • Star Schema (faits + dimensions)                                 │
│  • Dénormalisé pour la performance                                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Types de marts

#### Tables de Faits (Facts)

```sql
-- models/marts/core/fct_orders.sql

{{
    config(
        materialized='table',
        schema='core_marts'
    )
}}

/*
    Table de faits : Commandes
    Grain : Une ligne par commande
    Usage : Analyse des ventes, revenus, performance
*/

SELECT
    -- Clés
    order_id,
    customer_id,
    product_id,
    
    -- Dimensions dégénérées
    order_status,
    payment_method,
    
    -- Mesures
    order_total,
    quantity,
    discount_amount,
    tax_amount,
    
    -- Dates (FK vers dim_date)
    ordered_at,
    DATE(ordered_at) AS order_date,
    
    -- Métriques calculées
    order_total - discount_amount AS net_revenue,
    
    -- Flags
    is_first_order,
    is_refunded

FROM {{ ref('int_orders_enriched') }}
WHERE order_status = 'completed'
```

#### Tables de Dimensions

```sql
-- models/marts/core/dim_customers.sql

{{
    config(
        materialized='table',
        schema='core_marts'
    )
}}

/*
    Dimension : Clients
    Grain : Une ligne par client unique
    Usage : Segmentation, analyse client
*/

WITH customer_base AS (
    SELECT * FROM {{ ref('stg_shopify__customers') }}
),

customer_metrics AS (
    SELECT * FROM {{ ref('int_customer_order_metrics') }}
),

final AS (
    SELECT
        -- Clé primaire
        cb.customer_id,
        
        -- Attributs descriptifs
        cb.full_name,
        cb.email,
        cb.created_at AS customer_since,
        
        -- Métriques agrégées (pour dénormalisation)
        cm.total_orders,
        cm.lifetime_value,
        cm.average_order_value,
        cm.first_order_at,
        cm.last_order_at,
        
        -- Segmentation
        CASE
            WHEN cm.lifetime_value >= 1000 THEN 'VIP'
            WHEN cm.lifetime_value >= 500 THEN 'Regular'
            WHEN cm.lifetime_value >= 100 THEN 'Occasional'
            ELSE 'New'
        END AS customer_segment,
        
        -- Statut
        CASE
            WHEN cm.last_order_at >= DATEADD('day', -90, CURRENT_DATE) THEN 'Active'
            WHEN cm.last_order_at >= DATEADD('day', -180, CURRENT_DATE) THEN 'At Risk'
            ELSE 'Churned'
        END AS customer_status
        
    FROM customer_base cb
    LEFT JOIN customer_metrics cm
        ON cb.customer_id = cm.customer_id
)

SELECT * FROM final
```

### Organisation des marts

```
models/marts/
│
├── core/                       # Marts partagés par tous
│   ├── _core__models.yml
│   ├── dim_customers.sql
│   ├── dim_products.sql
│   ├── dim_date.sql
│   └── fct_orders.sql
│
├── finance/                    # Marts équipe finance
│   ├── _finance__models.yml
│   ├── fct_daily_revenue.sql
│   ├── fct_monthly_mrr.sql
│   └── dim_cost_centers.sql
│
├── marketing/                  # Marts équipe marketing
│   ├── _marketing__models.yml
│   ├── fct_campaign_performance.sql
│   ├── fct_email_engagement.sql
│   └── dim_campaigns.sql
│
└── product/                    # Marts équipe produit
    ├── _product__models.yml
    ├── fct_feature_usage.sql
    └── fct_user_sessions.sql
```

---

## Flux de données complet

### Exemple end-to-end

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FLUX COMPLET                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  SOURCES                                                            │
│  ────────                                                           │
│  raw.shopify_orders  ────┐                                          │
│  raw.shopify_customers ──┼──> source()                              │
│  raw.stripe_payments  ───┘                                          │
│                                                                     │
│  STAGING (VIEW)                                                     │
│  ──────────────                                                     │
│  stg_shopify__orders     ◄── Renommage, types                       │
│  stg_shopify__customers  ◄── Nettoyage basique                      │
│  stg_stripe__payments    ◄── Standardisation                        │
│                                                                     │
│  INTERMEDIATE (EPHEMERAL)                                           │
│  ────────────────────────                                           │
│  int_orders_enriched     ◄── Jointures orders+customers+payments    │
│  int_customer_metrics    ◄── Agrégation par customer                │
│                                                                     │
│  MARTS (TABLE)                                                      │
│  ─────────────                                                      │
│  fct_orders              ◄── Table de faits finale                  │
│  dim_customers           ◄── Dimension client avec métriques        │
│                                                                     │
│                                    │                                │
│                                    ▼                                │
│                              ┌──────────┐                           │
│                              │  BI Tool │                           │
│                              │ Tableau  │                           │
│                              └──────────┘                           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Quand utiliser quelle couche

### Guide de décision

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ARBRE DE DÉCISION                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  "Est-ce une donnée brute d'une source externe ?"                   │
│      │                                                              │
│      ├── OUI → STAGING (stg_)                                       │
│      │         • Un model par table source                          │
│      │         • Nettoyage minimal                                  │
│      │                                                              │
│      └── NON → "Est-ce utilisé par les utilisateurs finaux ?"       │
│                   │                                                 │
│                   ├── OUI → MARTS (fct_, dim_)                      │
│                   │         • Bien documenté                        │
│                   │         • Matérialisé en TABLE                  │
│                   │                                                 │
│                   └── NON → INTERMEDIATE (int_)                     │
│                             • Logique complexe                      │
│                             • Souvent EPHEMERAL                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Tableau récapitulatif

| Question              | Staging         | Intermediate    | Marts           |
|-----------------------|-----------------|-----------------|-----------------|
| Source de données ?   | Externe (raw)   | Models DBT      | Models DBT      |
| Jointures ?           | ❌ Non ❌      | ✅ Oui ✅      | ✅ Simple ✅   |
| Logique métier ?      | ❌ Minimale ❌ | ✅ Complexe ✅ | ⚠️ Simple ⚠️   |
| Agrégations ?         | ❌ Non ❌      | ✅ Oui ✅      | ⚠️ Finales ⚠️  |
| Utilisateurs finaux ? | ❌ Non ❌      | ❌ Non ❌      | ✅ Oui ✅      |
| Documentation ?       | ⚠️ Basique ⚠️  | ⚠️ Interne ⚠️  | ✅ Complète ✅ |

---

## Résumé

| Couche           | Préfixe        | Rôle             | Matérialisation |
|------------------|----------------|------------------|-----------------|
| **Staging**      | `stg_`         | Nettoyage source | VIEW            |
| **Intermediate** | `int_`         | Logique métier   | EPHEMERAL       |
| **Marts**        | `fct_`, `dim_` | Tables finales   | TABLE           |

---

## Prochaines étapes

→ [Matérialisations](./03-materialisations.md)


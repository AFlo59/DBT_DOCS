# Conventions de nommage DBT

## 📋 Table des matières
1. [Principes généraux](#principes-généraux)
2. [Nommage des modèles](#nommage-des-modèles)
3. [Nommage des colonnes](#nommage-des-colonnes)
4. [Nommage des fichiers](#nommage-des-fichiers)
5. [Nommage des sources](#nommage-des-sources)
6. [Autres conventions](#autres-conventions)

---

## Principes généraux

### Les 5 règles d'or

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RÈGLES DE NOMMAGE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. SNAKE_CASE partout                                              │
│     └── order_id, customer_name, created_at                         │
│                                                                      │
│  2. SINGULIER pour les noms de tables                               │
│     └── customer (pas customers)                                    │
│     └── Sauf si concept pluriel (events, logs)                      │
│                                                                      │
│  3. PRÉFIXES descriptifs                                            │
│     └── stg_ (staging), int_ (intermediate), fct_ (fact), dim_     │
│                                                                      │
│  4. NOMS COMPLETS (pas d'abréviations)                              │
│     └── customer_id (pas cust_id)                                   │
│     └── Exceptions : id, qty, amt si standards                      │
│                                                                      │
│  5. COHÉRENCE avant tout                                            │
│     └── Une convention = partout la même                            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Formats autorisés

| Format | Exemple | Usage dans DBT |
|--------|---------|----------------|
| **snake_case** | `order_id` | ✅ Standard |
| **PascalCase** | `OrderId` | ❌ Éviter |
| **camelCase** | `orderId` | ❌ Éviter |
| **SCREAMING_SNAKE** | `ORDER_ID` | ⚠️ Selon warehouse |

---

## Nommage des modèles

### Préfixes par couche

| Couche | Préfixe | Exemple |
|--------|---------|---------|
| **Staging** | `stg_` | `stg_shopify__orders` |
| **Intermediate** | `int_` | `int_orders_enriched` |
| **Fact (Marts)** | `fct_` | `fct_orders` |
| **Dimension (Marts)** | `dim_` | `dim_customers` |
| **Snapshot** | `snap_` | `snap_customers` |
| **Utility** | `util_` | `util_date_spine` |

### Format des modèles staging

```
stg_<source>__<objet>
```

**Le double underscore `__`** sépare la source de l'objet.

```sql
-- Exemples
stg_shopify__orders         -- Source: shopify, Objet: orders
stg_stripe__payments        -- Source: stripe, Objet: payments
stg_google_analytics__events -- Source: google_analytics, Objet: events
```

### Format des modèles intermediate

```
int_<description>
```

```sql
-- Exemples
int_orders_with_payments
int_customer_lifetime_value
int_daily_revenue
```

### Format des modèles marts

```
fct_<événement>     -- Tables de faits (verbes, événements)
dim_<entité>        -- Tables de dimensions (noms, entités)
```

```sql
-- Facts (événements, transactions)
fct_orders              -- Fait : une commande passée
fct_payments            -- Fait : un paiement effectué
fct_page_views          -- Fait : une page vue
fct_signups             -- Fait : une inscription

-- Dimensions (entités, référentiels)
dim_customers           -- Dimension : les clients
dim_products            -- Dimension : les produits
dim_date                -- Dimension : le calendrier
dim_geography           -- Dimension : la géographie
```

### Tableau récapitulatif

```
┌─────────────────────────────────────────────────────────────────────┐
│                    EXEMPLES COMPLETS                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Source: Shopify (e-commerce)                                       │
│  ──────────────────────────────────────────────────────────────────  │
│  Staging:     stg_shopify__orders                                   │
│               stg_shopify__customers                                │
│               stg_shopify__products                                 │
│                                                                      │
│  Intermediate: int_orders_with_line_items                           │
│                int_customer_order_history                           │
│                                                                      │
│  Marts:       fct_orders                                            │
│               fct_order_line_items                                  │
│               dim_customers                                         │
│               dim_products                                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Nommage des colonnes

### Clés primaires et étrangères

```sql
-- Clé primaire : <entity>_id
customer_id     -- PK de dim_customers
order_id        -- PK de fct_orders
product_id      -- PK de dim_products

-- Clés étrangères : même nom que la PK référencée
SELECT
    order_id,           -- PK
    customer_id,        -- FK vers dim_customers
    product_id          -- FK vers dim_products
FROM fct_orders
```

### Colonnes booléennes

```sql
-- Préfixe is_, has_, ou was_
is_active           -- État actuel
is_deleted          -- Flag de suppression
has_subscription    -- Possession
was_refunded        -- Action passée

-- Éviter
active              -- Ambigu
subscription        -- Pas clair que c'est un booléen
```

### Colonnes de dates et timestamps

```sql
-- Suffixe _at pour les timestamps
created_at          -- Timestamp de création
updated_at          -- Timestamp de mise à jour
deleted_at          -- Timestamp de suppression
ordered_at          -- Timestamp de commande

-- Suffixe _date pour les dates
order_date          -- Date sans heure
birth_date          -- Date de naissance
start_date          -- Date de début

-- Préfixe pour les dates calculées
first_order_date    -- Première commande
last_login_at       -- Dernière connexion
```

### Colonnes de montants

```sql
-- Suffixe descriptif du type de montant
order_total             -- Montant total
order_subtotal          -- Sous-total
tax_amount              -- Montant taxe
discount_amount         -- Montant remise
revenue_amount          -- Montant revenu

-- Indiquer la devise si nécessaire
amount_usd              -- En dollars US
amount_eur              -- En euros
amount_cents            -- En centimes
```

### Colonnes de comptage

```sql
-- Préfixe count_ ou nb_ ou suffixe _count
order_count             -- Nombre de commandes
total_orders            -- Alternative acceptable
num_products            -- Nombre de produits
```

### Tableau des suffixes courants

| Suffixe | Usage | Exemple |
|---------|-------|---------|
| `_id` | Identifiant | `customer_id` |
| `_at` | Timestamp | `created_at` |
| `_date` | Date | `order_date` |
| `_name` | Nom textuel | `customer_name` |
| `_code` | Code court | `country_code` |
| `_status` | Statut | `order_status` |
| `_type` | Type/catégorie | `payment_type` |
| `_amount` | Montant | `tax_amount` |
| `_count` | Comptage | `order_count` |
| `_rate` | Taux/ratio | `conversion_rate` |
| `_pct` | Pourcentage | `discount_pct` |

---

## Nommage des fichiers

### Fichiers SQL

```
<layer_prefix>_<nom_descriptif>.sql
```

```
models/
├── staging/
│   └── shopify/
│       ├── stg_shopify__orders.sql
│       ├── stg_shopify__customers.sql
│       └── stg_shopify__products.sql
│
├── intermediate/
│   └── int_orders_enriched.sql
│
└── marts/
    ├── fct_orders.sql
    └── dim_customers.sql
```

### Fichiers YAML

```
_<source/domaine>__<type>.yml
```

```
models/
├── staging/
│   └── shopify/
│       ├── _shopify__sources.yml    # Définition des sources
│       └── _shopify__models.yml     # Documentation des modèles
│
└── marts/
    └── core/
        └── _core__models.yml
```

**Le préfixe `_`** :
- Place les fichiers en haut de la liste
- Distingue visuellement des fichiers SQL

### Fichiers de macros

```
<nom_descriptif>.sql
```

```
macros/
├── generate_schema_name.sql     # Macro standard DBT
├── cents_to_dollars.sql         # Macro utilitaire
├── get_custom_schema.sql        # Macro de schéma
│
└── tests/                       # Tests génériques custom
    ├── test_positive_value.sql
    └── test_not_empty_string.sql
```

### Fichiers de tests

```
assert_<description>.sql    # Tests singuliers
test_<description>.sql      # Tests génériques custom
```

```
tests/
├── assert_no_orphan_orders.sql
├── assert_revenue_positive.sql
└── assert_unique_customer_email.sql

macros/tests/
├── test_positive_value.sql
└── test_valid_email.sql
```

---

## Nommage des sources

### Dans le fichier sources.yml

```yaml
# _shopify__sources.yml

sources:
  - name: shopify                # Nom de la source (snake_case)
    description: "Données e-commerce Shopify"
    database: raw_data           # Base de données
    schema: shopify              # Schéma
    
    tables:
      - name: orders             # Nom de la table brute
        description: "Commandes Shopify"
        identifier: shopify_orders  # Nom réel si différent
        
      - name: customers
        description: "Clients Shopify"
```

### Référencement des sources

```sql
-- {{ source('<source_name>', '<table_name>') }}

SELECT *
FROM {{ source('shopify', 'orders') }}

SELECT *
FROM {{ source('stripe', 'payments') }}
```

---

## Autres conventions

### Tags

```yaml
# Utiliser des tags descriptifs en snake_case
models:
  - name: fct_orders
    config:
      tags: ['daily', 'core', 'finance']
```

**Tags courants :**
| Tag | Usage |
|-----|-------|
| `daily` | Exécution quotidienne |
| `hourly` | Exécution horaire |
| `core` | Modèle fondamental |
| `finance` | Domaine finance |
| `marketing` | Domaine marketing |
| `pii` | Contient des données sensibles |

### Variables

```yaml
# dbt_project.yml
vars:
  start_date: '2020-01-01'            # snake_case
  default_currency: 'USD'
  enable_pii_masking: true
```

```sql
-- Utilisation
{{ var('start_date') }}
{{ var('default_currency') }}
```

### Macros

```sql
-- Nom en snake_case
{% macro cents_to_dollars(column_name) %}
    ({{ column_name }} / 100)::numeric(10,2)
{% endmacro %}

{% macro generate_surrogate_key(columns) %}
    -- ...
{% endmacro %}
```

### Schémas

```
<environnement>_<domaine>
```

```yaml
# Exemples de schémas
staging                 # Données staging
marts                   # Données marts générales
finance_marts           # Marts finance
marketing_marts         # Marts marketing
snapshots               # Snapshots

# Avec préfixe environnement (selon config)
dev_staging
prod_marts
```

---

## Checklist de validation

### Avant de merger

- [ ] Tous les noms en snake_case
- [ ] Préfixes corrects (stg_, int_, fct_, dim_)
- [ ] Double underscore pour staging (`stg_source__table`)
- [ ] Colonnes ID suffixées `_id`
- [ ] Timestamps suffixés `_at`
- [ ] Dates suffixées `_date`
- [ ] Booléens préfixés `is_`, `has_`, `was_`
- [ ] Fichiers YAML préfixés `_`

---

## Résumé

| Élément | Convention | Exemple |
|---------|------------|---------|
| **Modèle staging** | `stg_<source>__<table>` | `stg_shopify__orders` |
| **Modèle intermediate** | `int_<description>` | `int_orders_enriched` |
| **Modèle fact** | `fct_<événement>` | `fct_orders` |
| **Modèle dimension** | `dim_<entité>` | `dim_customers` |
| **Clé primaire** | `<entity>_id` | `customer_id` |
| **Timestamp** | `<action>_at` | `created_at` |
| **Date** | `<type>_date` | `order_date` |
| **Booléen** | `is_/has_/was_<état>` | `is_active` |
| **Fichier YAML** | `_<scope>__<type>.yml` | `_shopify__sources.yml` |

---

## Prochaines étapes

→ [Concept des Models](../04-models/01-concept-models.md)


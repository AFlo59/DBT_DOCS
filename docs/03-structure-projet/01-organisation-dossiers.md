# Organisation des dossiers DBT

## 📋 Table des matières
1. [Structure par défaut](#structure-par-défaut)
2. [Les dossiers principaux](#les-dossiers-principaux)
3. [Organisation des models](#organisation-des-models)
4. [Structure recommandée](#structure-recommandée)
5. [Exemples de structures](#exemples-de-structures)

---

## Structure par défaut

### Après `dbt init`

```
my_dbt_project/
├── dbt_project.yml          # Configuration du projet
├── README.md                 # Documentation
│
├── models/                   # 📊 Modèles SQL (cœur du projet)
│   └── example/
│       ├── my_first_dbt_model.sql
│       ├── my_second_dbt_model.sql
│       └── schema.yml
│
├── seeds/                    # 🌱 Fichiers CSV statiques
│
├── snapshots/                # 📸 Snapshots (historisation)
│
├── tests/                    # 🧪 Tests singuliers (SQL custom)
│
├── macros/                   # ⚙️ Macros Jinja réutilisables
│
├── analyses/                 # 📈 Analyses SQL (non matérialisées)
│
└── target/                   # 🎯 Output (généré, gitignore)
    ├── compiled/
    ├── run/
    └── manifest.json
```

---

## Les dossiers principaux

### models/

**Rôle** : Contient tous les modèles SQL (transformations)

```
models/
├── staging/          # Nettoyage des sources
├── intermediate/     # Logique complexe
├── marts/            # Tables finales
└── schema.yml        # Documentation et tests
```

**Chaque fichier `.sql`** = Un modèle = Une table/vue

### seeds/

**Rôle** : Fichiers CSV chargés comme tables

```
seeds/
├── country_codes.csv
├── currency_rates.csv
└── schema.yml
```

**Cas d'usage** :
- Données de référence (pays, devises)
- Mappings statiques
- Données de configuration

### snapshots/

**Rôle** : Historisation des données (SCD Type 2)

```
snapshots/
├── snap_customers.sql
├── snap_products.sql
└── schema.yml
```

### tests/

**Rôle** : Tests SQL personnalisés (singuliers)

```
tests/
├── assert_total_revenue_positive.sql
└── assert_no_orphan_orders.sql
```

### macros/

**Rôle** : Fonctions Jinja réutilisables

```
macros/
├── generate_schema_name.sql
├── cents_to_dollars.sql
└── custom_tests/
    └── test_positive_value.sql
```

### analyses/

**Rôle** : Requêtes SQL compilées mais non matérialisées

```
analyses/
├── ad_hoc_revenue_analysis.sql
└── customer_cohort_query.sql
```

### target/

**Rôle** : Dossier de sortie (généré automatiquement)

```
target/
├── compiled/         # SQL compilé (Jinja → SQL pur)
│   └── my_project/
│       └── models/
├── run/              # SQL exécuté (avec CREATE TABLE)
├── manifest.json     # Métadonnées complètes
├── run_results.json  # Résultats de l'exécution
└── graph.gpickle     # DAG sérialisé
```

> ⚠️ **Important** : Ajouter `target/` dans `.gitignore`

---

## Organisation des models

### Architecture en couches (Layer Architecture)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ARCHITECTURE EN COUCHES                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                      MARTS (Business Layer)                    │  │
│  │   Dimensions et faits pour les utilisateurs finaux            │  │
│  │   Matérialisation : TABLE                                      │  │
│  │   fct_orders, dim_customers, dim_products                     │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              ▲                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   INTERMEDIATE (Logic Layer)                   │  │
│  │   Logique métier complexe, jointures                          │  │
│  │   Matérialisation : EPHEMERAL (ou VIEW)                       │  │
│  │   int_orders_enriched, int_customer_metrics                   │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              ▲                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    STAGING (Clean Layer)                       │  │
│  │   Nettoyage, renommage, typage                                │  │
│  │   Matérialisation : VIEW                                       │  │
│  │   stg_shopify__orders, stg_stripe__payments                   │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                              ▲                                       │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                     SOURCES (Raw Data)                         │  │
│  │   Données brutes (définies dans sources.yml)                  │  │
│  │   raw.shopify_orders, raw.stripe_payments                     │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Couche Staging

**Objectifs** :
- Renommer les colonnes
- Caster les types
- Supprimer les doublons évidents
- Pas de logique métier

```sql
-- models/staging/shopify/stg_shopify__orders.sql
SELECT
    id AS order_id,
    customer_id,
    CAST(total_price AS DECIMAL(10,2)) AS order_total,
    CAST(created_at AS TIMESTAMP) AS ordered_at,
    status AS order_status
FROM {{ source('shopify', 'orders') }}
WHERE id IS NOT NULL
```

### Couche Intermediate

**Objectifs** :
- Combiner les données de staging
- Appliquer la logique métier complexe
- Préparer pour les marts

```sql
-- models/intermediate/int_orders_enriched.sql
SELECT
    o.order_id,
    o.customer_id,
    c.customer_name,
    o.order_total,
    o.ordered_at,
    p.payment_method
FROM {{ ref('stg_shopify__orders') }} o
LEFT JOIN {{ ref('stg_shopify__customers') }} c
    ON o.customer_id = c.customer_id
LEFT JOIN {{ ref('stg_stripe__payments') }} p
    ON o.order_id = p.order_id
```

### Couche Marts

**Objectifs** :
- Tables finales pour les utilisateurs
- Optimisées pour la consommation
- Documentation complète

```sql
-- models/marts/core/fct_orders.sql
SELECT
    order_id,
    customer_id,
    customer_name,
    order_total,
    ordered_at,
    payment_method,
    DATE_TRUNC('month', ordered_at) AS order_month
FROM {{ ref('int_orders_enriched') }}
```

---

## Structure recommandée

### Structure complète

```
models/
│
├── staging/                      # Couche Staging
│   │
│   ├── shopify/                  # Par source
│   │   ├── _shopify__sources.yml
│   │   ├── _shopify__models.yml
│   │   ├── stg_shopify__orders.sql
│   │   ├── stg_shopify__customers.sql
│   │   └── stg_shopify__products.sql
│   │
│   ├── stripe/
│   │   ├── _stripe__sources.yml
│   │   ├── _stripe__models.yml
│   │   ├── stg_stripe__payments.sql
│   │   └── stg_stripe__refunds.sql
│   │
│   └── google_analytics/
│       ├── _ga__sources.yml
│       ├── _ga__models.yml
│       └── stg_ga__sessions.sql
│
├── intermediate/                 # Couche Intermediate
│   │
│   ├── finance/
│   │   ├── _int_finance__models.yml
│   │   ├── int_payments_combined.sql
│   │   └── int_revenue_by_customer.sql
│   │
│   └── marketing/
│       ├── _int_marketing__models.yml
│       └── int_campaign_performance.sql
│
└── marts/                        # Couche Marts
    │
    ├── core/                     # Marts partagés
    │   ├── _core__models.yml
    │   ├── dim_customers.sql
    │   ├── dim_products.sql
    │   └── fct_orders.sql
    │
    ├── finance/                  # Marts finance
    │   ├── _finance__models.yml
    │   ├── fct_revenue.sql
    │   └── fct_monthly_recurring_revenue.sql
    │
    └── marketing/                # Marts marketing
        ├── _marketing__models.yml
        ├── dim_campaigns.sql
        └── fct_campaign_conversions.sql
```

### Conventions de nommage des fichiers YAML

```
models/staging/shopify/
├── _shopify__sources.yml      # Définition des sources
├── _shopify__models.yml       # Documentation des modèles
├── stg_shopify__orders.sql
└── stg_shopify__customers.sql
```

**Le préfixe `_`** place les fichiers YAML en haut du dossier.

---

## Exemples de structures

### Projet simple (PME)

```
models/
├── staging/
│   ├── stg_orders.sql
│   ├── stg_customers.sql
│   └── sources.yml
│
├── marts/
│   ├── dim_customers.sql
│   ├── fct_orders.sql
│   └── schema.yml
│
└── schema.yml                  # Tests et docs globaux
```

### Projet moyen (Scale-up)

```
models/
├── staging/
│   ├── crm/
│   │   ├── _crm__sources.yml
│   │   └── stg_crm__*.sql
│   └── ecommerce/
│       ├── _ecommerce__sources.yml
│       └── stg_ecommerce__*.sql
│
├── intermediate/
│   └── int_*.sql
│
└── marts/
    ├── core/
    │   └── dim_*, fct_*
    └── sales/
        └── dim_*, fct_*
```

### Projet enterprise (Grande entreprise)

```
models/
├── staging/
│   ├── salesforce/
│   ├── netsuite/
│   ├── stripe/
│   ├── segment/
│   └── snowplow/
│
├── intermediate/
│   ├── finance/
│   ├── sales/
│   ├── marketing/
│   └── product/
│
├── marts/
│   ├── core/                   # Partagé
│   ├── finance/
│   ├── sales/
│   ├── marketing/
│   └── product/
│
└── utilities/                  # Modèles utilitaires
    ├── date_spine.sql
    └── calendar.sql
```

---

## Résumé

### Structure minimale

```
models/
├── staging/      # stg_*
├── marts/        # dim_*, fct_*
└── schema.yml
```

### Structure recommandée

```
models/
├── staging/        # Par source
├── intermediate/   # Par domaine
└── marts/          # Par domaine
```

### Bonnes pratiques

| Règle | Exemple |
|-------|---------|
| Staging par source | `staging/shopify/`, `staging/stripe/` |
| Marts par domaine métier | `marts/finance/`, `marts/marketing/` |
| Un fichier YAML par dossier | `_shopify__models.yml` |
| Préfixe `_` pour les YAML | Place en haut du dossier |

---

## Prochaines étapes

→ [Conventions de nommage](./02-conventions-nommage.md)


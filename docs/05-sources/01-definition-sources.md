# Définition des Sources dans DBT

## 📋 Table des matières
1. [Qu'est-ce qu'une source ?](#quest-ce-quune-source-)
2. [Configuration des sources](#configuration-des-sources)
3. [Utilisation de source()](#utilisation-de-source)
4. [Documentation des sources](#documentation-des-sources)
5. [Bonnes pratiques](#bonnes-pratiques)

---

## Qu'est-ce qu'une source ?

### Définition

Une **source** dans DBT représente une table de données brutes qui existe déjà dans votre data warehouse, gérée par un système externe (ETL, ingestion).

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SOURCES VS MODELS                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  SOURCES (Externes)                  MODELS (DBT)                    │
│  ──────────────────                  ────────────                    │
│                                                                      │
│  ┌─────────────────┐                ┌─────────────────┐             │
│  │  raw.orders     │   source()     │  stg_orders     │             │
│  │  raw.customers  │ ─────────────> │  fct_orders     │             │
│  │  raw.products   │                │  dim_customers  │             │
│  └─────────────────┘                └─────────────────┘             │
│                                                                      │
│  • Créées par Fivetran, Airbyte     • Créées par DBT                │
│  • DBT ne les modifie pas           • DBT les gère                  │
│  • Définies dans sources.yml        • Fichiers .sql                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Pourquoi définir des sources ?

| Avantage | Description |
|----------|-------------|
| **Documentation** | Décrire les tables brutes |
| **Lineage** | Visualiser l'origine des données |
| **Freshness** | Surveiller la fraîcheur |
| **Abstraction** | Un seul endroit pour changer le nom/schéma |
| **Tests** | Appliquer des tests sur les données brutes |

---

## Configuration des sources

### Emplacement

Les sources sont définies dans des fichiers YAML, généralement dans le dossier staging.

```
models/
└── staging/
    └── shopify/
        ├── _shopify__sources.yml    ◄── Définition des sources
        ├── _shopify__models.yml
        ├── stg_shopify__orders.sql
        └── stg_shopify__customers.sql
```

### Syntaxe de base

```yaml
# models/staging/shopify/_shopify__sources.yml

version: 2

sources:
  - name: shopify               # Nom de la source (utilisé dans source())
    description: "Données e-commerce Shopify"
    
    database: raw_data          # Base de données (optionnel)
    schema: shopify_raw         # Schéma contenant les tables
    
    tables:
      - name: orders            # Nom de la table
        description: "Commandes Shopify"
        
      - name: customers
        description: "Clients Shopify"
        
      - name: products
        description: "Catalogue produits"
```

### Syntaxe complète

```yaml
version: 2

sources:
  - name: shopify
    description: |
      Données e-commerce Shopify synchronisées par Fivetran.
      Mise à jour toutes les heures.
    
    database: "{{ env_var('RAW_DATABASE', 'RAW_DATA') }}"
    schema: shopify
    
    # Configuration par défaut pour toutes les tables
    loader: fivetran
    loaded_at_field: _fivetran_synced
    
    freshness:
      warn_after:
        count: 12
        period: hour
      error_after:
        count: 24
        period: hour
    
    # Tags appliqués à toutes les tables
    tags: ['shopify', 'ecommerce']
    
    # Configuration des tables
    tables:
      - name: orders
        description: "Commandes passées sur le site"
        identifier: shopify_orders  # Nom réel si différent
        
        # Override freshness pour cette table
        freshness:
          warn_after:
            count: 1
            period: hour
        
        # Colonnes documentées
        columns:
          - name: id
            description: "ID unique de la commande"
            tests:
              - unique
              - not_null
              
          - name: customer_id
            description: "ID du client"
            
          - name: total_price
            description: "Prix total en centimes"
            tests:
              - not_null
              
          - name: created_at
            description: "Date de création"
        
        # Tests au niveau de la table
        tests:
          - dbt_utils.recency:
              datepart: day
              field: created_at
              interval: 1
              
      - name: customers
        description: "Clients enregistrés"
        columns:
          - name: id
            description: "ID unique du client"
            tests:
              - unique
              - not_null
          - name: email
            description: "Email du client"
            tests:
              - unique
```

### Identifier (nom réel)

```yaml
tables:
  - name: orders              # Nom utilisé dans source()
    identifier: raw_orders    # Nom réel de la table dans le warehouse
```

```sql
-- source('shopify', 'orders') → raw_data.shopify.raw_orders
SELECT * FROM {{ source('shopify', 'orders') }}
```

### Quoting

```yaml
sources:
  - name: legacy_system
    quoting:
      database: true
      schema: true
      identifier: true
    tables:
      - name: Orders  # Sera quoté : "Orders"
```

---

## Utilisation de source()

### Syntaxe

```jinja
{{ source('source_name', 'table_name') }}
```

### Exemple dans un model staging

```sql
-- models/staging/shopify/stg_shopify__orders.sql

WITH source AS (
    SELECT * FROM {{ source('shopify', 'orders') }}
),

renamed AS (
    SELECT
        id AS order_id,
        customer_id,
        total_price AS order_total,
        created_at AS ordered_at
    FROM source
)

SELECT * FROM renamed
```

### Compilation

```sql
-- Ce que DBT compile
WITH source AS (
    SELECT * FROM "RAW_DATA"."shopify"."orders"
),
...
```

### source() vs ref()

| Fonction | Usage | Cible |
|----------|-------|-------|
| `source()` | Tables brutes externes | Tables raw (non-DBT) |
| `ref()` | Models DBT | Autres models |

```sql
-- ✅ CORRECT
SELECT * FROM {{ source('shopify', 'orders') }}     -- Table brute
SELECT * FROM {{ ref('stg_shopify__orders') }}      -- Model DBT

-- ❌ INCORRECT
SELECT * FROM {{ ref('shopify', 'orders') }}        -- source ≠ ref
```

---

## Documentation des sources

### Documentation des tables

```yaml
sources:
  - name: stripe
    description: |
      Données de paiement Stripe.
      
      ## Contexte
      Ces données sont synchronisées en temps réel par Segment.
      
      ## SLA
      - Latence maximale : 5 minutes
      - Disponibilité : 99.9%
      
      ## Contact
      - Owner : équipe Payment
      - Slack : #data-payments
    
    tables:
      - name: payments
        description: |
          Transactions de paiement.
          
          **Grain** : Une ligne par paiement
          **Mise à jour** : Temps réel
          **Volume** : ~100K lignes/jour
```

### Documentation des colonnes

```yaml
tables:
  - name: payments
    columns:
      - name: id
        description: |
          Identifiant unique du paiement Stripe.
          Format : `pi_xxxxx` (Payment Intent)
        
      - name: amount
        description: |
          Montant du paiement en **centimes**.
          Diviser par 100 pour obtenir la valeur en devise.
        
      - name: currency
        description: |
          Code devise ISO 4217 (3 lettres).
          Exemples : `usd`, `eur`, `gbp`
        
      - name: status
        description: |
          Statut du paiement Stripe.
          
          Valeurs possibles :
          - `succeeded` : Paiement réussi
          - `pending` : En attente
          - `failed` : Échoué
```

### Métadonnées (meta)

```yaml
sources:
  - name: salesforce
    meta:
      owner: sales-team
      tier: gold
      pii: true
      
    tables:
      - name: contacts
        meta:
          contains_pii: true
          gdpr_relevant: true
          retention_days: 365
        columns:
          - name: email
            meta:
              pii: true
              masking: hash
```

---

## Bonnes pratiques

### Organisation des fichiers

```
models/staging/
├── shopify/
│   ├── _shopify__sources.yml      # Sources Shopify
│   ├── _shopify__models.yml       # Models Shopify
│   └── stg_shopify__*.sql
│
├── stripe/
│   ├── _stripe__sources.yml       # Sources Stripe
│   ├── _stripe__models.yml
│   └── stg_stripe__*.sql
│
└── hubspot/
    ├── _hubspot__sources.yml
    ├── _hubspot__models.yml
    └── stg_hubspot__*.sql
```

### Convention de nommage

```yaml
# Nom de source = système source
sources:
  - name: shopify           # Pas "raw_shopify" ou "shopify_data"
    schema: shopify_raw     # Le schema peut être différent
```

### Une source = un système

```yaml
# ✅ CORRECT : Une source par système
sources:
  - name: shopify
    tables: [orders, customers, products]
    
  - name: stripe
    tables: [payments, refunds]

# ❌ ÉVITER : Mixer les systèmes
sources:
  - name: all_raw_data
    tables: [shopify_orders, stripe_payments]  # Mélange
```

### Tests sur les sources

```yaml
sources:
  - name: shopify
    tables:
      - name: orders
        columns:
          - name: id
            tests:
              - unique
              - not_null
          - name: customer_id
            tests:
              - not_null
              - relationships:
                  to: source('shopify', 'customers')
                  field: id
```

### Template de source complète

```yaml
version: 2

sources:
  - name: <system_name>
    description: |
      <Description du système source>
      
      ## Synchronisation
      - Outil : <Fivetran/Airbyte/Custom>
      - Fréquence : <Toutes les heures/Temps réel>
      
      ## Contact
      - Owner : <équipe>
      - Slack : <channel>
    
    database: "{{ env_var('RAW_DATABASE', 'RAW') }}"
    schema: <schema_name>
    
    loader: <fivetran/airbyte/custom>
    loaded_at_field: <_loaded_at>
    
    freshness:
      warn_after: {count: 12, period: hour}
      error_after: {count: 24, period: hour}
    
    tables:
      - name: <table_name>
        description: "<Description de la table>"
        
        columns:
          - name: <column_name>
            description: "<Description>"
            tests:
              - <test>
```

---

## Résumé

| Concept | Description |
|---------|-------------|
| **Source** | Table brute externe à DBT |
| **source()** | Fonction pour référencer une source |
| **Freshness** | Surveillance de la fraîcheur |
| **Identifier** | Nom réel de la table |

### Checklist sources

- [ ] Une source par système (Shopify, Stripe, etc.)
- [ ] Documentation des tables et colonnes
- [ ] Tests sur les colonnes clés (PK, FK)
- [ ] Configuration de la freshness
- [ ] Fichiers organisés par source

---

## Prochaines étapes

→ [Freshness (fraîcheur des données)](./02-freshness.md)


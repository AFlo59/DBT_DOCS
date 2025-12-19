# Concept SCD (Slowly Changing Dimensions)

## 📋 Table des matières
1. [Introduction aux SCD](#introduction-aux-scd)
2. [Types de SCD](#types-de-scd)
3. [SCD Type 2 en détail](#scd-type-2-en-détail)
4. [Implémentation avec DBT](#implémentation-avec-dbt)
5. [Cas d'usage](#cas-dusage)

---

## Introduction aux SCD

### Qu'est-ce qu'une Slowly Changing Dimension ?

Une **SCD** est une dimension dont les attributs changent lentement au fil du temps. La question est : comment gérer ces changements ?

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PROBLÈME DES SCD                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Le client "Alice" déménage de Paris à Lyon.                       │
│                                                                      │
│   AVANT :                          APRÈS :                          │
│   ┌─────────────────────────┐     ┌─────────────────────────┐      │
│   │ customer_id: 123        │     │ customer_id: 123        │      │
│   │ name: Alice             │     │ name: Alice             │      │
│   │ city: Paris ←──────────────── │ city: Lyon   ← Changé   │      │
│   └─────────────────────────┘     └─────────────────────────┘      │
│                                                                      │
│   QUESTION : Que faire de l'historique ?                            │
│                                                                      │
│   - Les commandes passées à Paris doivent-elles montrer "Paris" ?  │
│   - Ou doivent-elles montrer "Lyon" (valeur actuelle) ?            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Pourquoi c'est important ?

| Scénario | Impact |
|----------|--------|
| **Analyse historique** | "Combien de ventes à Paris en 2023 ?" |
| **Audit** | "Quel était le prix du produit au moment de la vente ?" |
| **Conformité** | "Quelle était l'adresse du client lors de la commande ?" |

---

## Types de SCD

### SCD Type 0 : Pas de changement

```
Pas de mise à jour. La valeur initiale est conservée pour toujours.

Usage : Données immuables (date de naissance, code pays d'origine)
```

### SCD Type 1 : Écrasement

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SCD TYPE 1 : OVERWRITE                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   AVANT                             APRÈS                            │
│   ┌─────────────────────────┐      ┌─────────────────────────┐     │
│   │ id   │ name  │ city    │      │ id   │ name  │ city    │     │
│   ├─────────────────────────┤      ├─────────────────────────┤     │
│   │ 123  │ Alice │ Paris   │  →   │ 123  │ Alice │ Lyon    │     │
│   └─────────────────────────┘      └─────────────────────────┘     │
│                                                                      │
│   ❌ Historique perdu                                                │
│   ✅ Simple à implémenter                                            │
│   ✅ Pas de duplication                                              │
│                                                                      │
│   Usage : Corrections d'erreurs, données non critiques              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### SCD Type 2 : Historisation

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SCD TYPE 2 : HISTORISATION                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   On garde TOUTES les versions avec des dates de validité           │
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐  │
│   │ id   │ name  │ city   │ valid_from │ valid_to   │ is_current │ │
│   ├──────────────────────────────────────────────────────────────┤  │
│   │ 123  │ Alice │ Paris  │ 2022-01-01 │ 2024-01-14 │ false      │ │
│   │ 123  │ Alice │ Lyon   │ 2024-01-15 │ NULL       │ true       │ │
│   └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│   ✅ Historique complet                                              │
│   ✅ Analyses temporelles possibles                                  │
│   ❌ Plus de lignes (duplication)                                    │
│   ❌ Jointures plus complexes                                        │
│                                                                      │
│   Usage : Dimensions critiques (clients, produits, employés)        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### SCD Type 3 : Colonnes historiques

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SCD TYPE 3 : COLONNES                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   On ajoute des colonnes pour les anciennes valeurs                 │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │ id   │ name  │ city_current │ city_previous │              │   │
│   ├─────────────────────────────────────────────────────────────┤   │
│   │ 123  │ Alice │ Lyon         │ Paris         │              │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   ✅ Simple                                                          │
│   ❌ Historique limité (1 version précédente)                       │
│   ❌ Schéma rigide                                                   │
│                                                                      │
│   Usage : Quand seule la valeur précédente importe                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Comparaison

| Type | Historique | Complexité | Usage |
|------|------------|------------|-------|
| Type 0 | ❌ Aucun | Minimale | Données immuables |
| Type 1 | ❌ Écrasé | Faible | Corrections |
| Type 2 | ✅ Complet | Moyenne | Dimensions critiques |
| Type 3 | ⚠️ Limité | Faible | Valeur précédente uniquement |

---

## SCD Type 2 en détail

### Structure de la table

```sql
CREATE TABLE dim_customers_scd2 (
    -- Clé de substitution (unique par version)
    dbt_scd_id            VARCHAR,
    
    -- Clé naturelle (peut avoir plusieurs lignes)
    customer_id           INTEGER,
    
    -- Attributs
    customer_name         VARCHAR,
    email                 VARCHAR,
    city                  VARCHAR,
    
    -- Métadonnées SCD
    dbt_valid_from        TIMESTAMP,  -- Début de validité
    dbt_valid_to          TIMESTAMP,  -- Fin de validité (NULL = actuel)
    dbt_updated_at        TIMESTAMP   -- Timestamp de modification source
);
```

### Colonnes SCD2 standards

| Colonne | Description |
|---------|-------------|
| `dbt_scd_id` | Clé de substitution unique par version |
| `dbt_valid_from` | Date de début de validité |
| `dbt_valid_to` | Date de fin de validité (NULL = actuel) |
| `dbt_updated_at` | Timestamp de la source |

### Requêtes sur SCD2

```sql
-- Obtenir la version actuelle
SELECT *
FROM dim_customers_scd2
WHERE dbt_valid_to IS NULL

-- Obtenir l'état à une date spécifique
SELECT *
FROM dim_customers_scd2
WHERE '2023-06-15' BETWEEN dbt_valid_from AND COALESCE(dbt_valid_to, '9999-12-31')

-- Historique complet d'un client
SELECT *
FROM dim_customers_scd2
WHERE customer_id = 123
ORDER BY dbt_valid_from
```

---

## Implémentation avec DBT

### Structure des snapshots

```
my_project/
└── snapshots/
    ├── snap_customers.sql
    ├── snap_products.sql
    └── schema.yml
```

### Syntaxe de base

```sql
-- snapshots/snap_customers.sql

{% snapshot snap_customers %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at'
    )
}}

SELECT
    customer_id,
    customer_name,
    email,
    city,
    updated_at
FROM {{ source('raw', 'customers') }}

{% endsnapshot %}
```

### Exécution

```bash
# Exécuter tous les snapshots
dbt snapshot

# Snapshot spécifique
dbt snapshot --select snap_customers
```

---

## Cas d'usage

### 1. Dimension clients

```sql
{% snapshot snap_customers %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at'
    )
}}

SELECT
    customer_id,
    customer_name,
    email,
    address,
    city,
    country,
    segment,
    updated_at
FROM {{ source('crm', 'customers') }}

{% endsnapshot %}
```

### 2. Dimension produits avec prix

```sql
{% snapshot snap_product_prices %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='price_updated_at'
    )
}}

SELECT
    product_id,
    product_name,
    category_id,
    price,
    cost,
    price_updated_at
FROM {{ source('catalog', 'products') }}

{% endsnapshot %}
```

### Utilisation dans un mart

```sql
-- models/marts/fct_orders.sql

SELECT
    o.order_id,
    o.order_date,
    o.customer_id,
    
    -- Informations client au moment de la commande
    c.customer_name,
    c.city AS customer_city_at_order,
    
    -- Prix du produit au moment de la commande
    p.price AS product_price_at_order
    
FROM {{ ref('stg_orders') }} o

-- Jointure SCD2 : état au moment de la commande
LEFT JOIN {{ ref('snap_customers') }} c
    ON o.customer_id = c.customer_id
    AND o.order_date BETWEEN c.dbt_valid_from 
        AND COALESCE(c.dbt_valid_to, '9999-12-31'::date)

LEFT JOIN {{ ref('snap_product_prices') }} p
    ON o.product_id = p.product_id
    AND o.order_date BETWEEN p.dbt_valid_from 
        AND COALESCE(p.dbt_valid_to, '9999-12-31'::date)
```

---

## Résumé

### Types de SCD

| Type | Historique | DBT |
|------|------------|-----|
| Type 1 | Écrasement | Model standard |
| Type 2 | Complet | Snapshot |
| Type 3 | Limité | Model avec colonnes |

### Colonnes SCD2 DBT

| Colonne | Description |
|---------|-------------|
| `dbt_scd_id` | ID unique par version |
| `dbt_valid_from` | Début validité |
| `dbt_valid_to` | Fin validité |
| `dbt_updated_at` | Timestamp source |

---

## Prochaines étapes

→ [Configuration des Snapshots](./02-configuration-snapshots.md)


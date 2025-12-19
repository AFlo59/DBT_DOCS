# Matérialisations dans DBT

## 📋 Table des matières
1. [Qu'est-ce qu'une matérialisation ?](#quest-ce-quune-matérialisation-)
2. [View](#view)
3. [Table](#table)
4. [Incremental](#incremental)
5. [Ephemeral](#ephemeral)
6. [Comparaison et choix](#comparaison-et-choix)

---

## Qu'est-ce qu'une matérialisation ?

### Définition

Une **matérialisation** définit **comment** DBT va créer le résultat d'un model dans le warehouse.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LES 4 MATÉRIALISATIONS                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐           │
│   │    VIEW     │     │    TABLE    │     │ INCREMENTAL │           │
│   ├─────────────┤     ├─────────────┤     ├─────────────┤           │
│   │ CREATE VIEW │     │CREATE TABLE │     │ INSERT INTO │           │
│   │ AS SELECT   │     │ AS SELECT   │     │ (new rows)  │           │
│   │             │     │             │     │             │           │
│   │ Pas de      │     │ Données     │     │ Ajout       │           │
│   │ stockage    │     │ stockées    │     │ uniquement  │           │
│   └─────────────┘     └─────────────┘     └─────────────┘           │
│                                                                     │
│   ┌──────────────┐                                                  │
│   │  EPHEMERAL   │                                                  │
│   ├──────────────┤                                                  │
│   │  Pas d'objet │                                                  │
│   │  CTE inline  │                                                  │
│   └──────────────┘                                                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Configuration

```sql
-- Méthode 1 : Dans le model
{{ config(materialized='table') }}

SELECT ...
```

```yaml
# Méthode 2 : Dans dbt_project.yml
models:
  my_project:
    marts:
      +materialized: table
```

---

## View

### Fonctionnement

Une **view** est une requête sauvegardée. Les données sont recalculées à chaque requête.

```sql
-- Ce que DBT génère
CREATE VIEW analytics.my_model AS (
    SELECT
        column_a,
        column_b
    FROM source_table
);
```

### Caractéristiques

| Aspect                | Description                    |
|-----------------------|--------------------------------|
| **Stockage**          | ❌ Aucun (requête stockée) ❌ |
| **Temps de création** | ⚡ Instantané ⚡              |
| **Temps de query**    | ⏱️ Recalculé à chaque fois ⏱️ |
| **Coût stockage**     | 💰 Aucun 💰                   |
| **Fraîcheur**         | ✅ Toujours à jour ✅         |

### Quand utiliser VIEW ?

```
✅ UTILISER POUR :
- Couche Staging (stg_*)
- Transformations légères
- Données toujours à jour
- Tables sources peu volumineuses

❌ ÉVITER POUR :
- Requêtes complexes (jointures multiples)
- Gros volumes de données
- Agrégations coûteuses
- Requêtes fréquentes
```

### Exemple

```sql
-- models/staging/stg_orders.sql
{{ config(materialized='view') }}

SELECT
    id AS order_id,
    customer_id,
    amount,
    created_at
FROM {{ source('raw', 'orders') }}
```

---

## Table

### Fonctionnement

Une **table** stocke physiquement les données. Elles sont recréées à chaque `dbt run`.

```sql
-- Ce que DBT génère
CREATE TABLE analytics.my_model AS (
    SELECT
        column_a,
        column_b
    FROM source_table
);

-- Ou avec remplacement
CREATE OR REPLACE TABLE analytics.my_model AS (...);
```

### Caractéristiques

| Aspect                | Description                    |
|-----------------------|--------------------------------|
| **Stockage**          | ✅ Données physiques ✅       |
| **Temps de création** | ⏱️ Proportionnel au volume ⏱️ |
| **Temps de query**    | ⚡ Rapide (pré-calculé) ⚡    |
| **Coût stockage**     | 💰 Payant 💰                  |
| **Fraîcheur**         | ⚠️ Dernière exécution ⚠️      |

### Quand utiliser TABLE ?

```
✅ UTILISER POUR :
- Marts (fct_*, dim_*)
- Transformations complexes
- Données consommées fréquemment
- Gros volumes avec agrégations
- Performance critique

❌ ÉVITER POUR :
- Données qui changent très souvent
- Tables intermédiaires peu utilisées
- Budgets stockage limités
```

### Exemple

```sql
-- models/marts/fct_orders.sql
{{ config(materialized='table') }}

SELECT
    o.order_id,
    o.customer_id,
    c.customer_name,
    o.amount,
    o.created_at,
    SUM(amount) OVER (PARTITION BY customer_id) AS customer_total
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('stg_customers') }} c
    ON o.customer_id = c.customer_id
```

---

## Incremental

### Fonctionnement

Un model **incremental** ajoute uniquement les nouvelles données à une table existante.

```sql
-- Première exécution : CREATE TABLE
CREATE TABLE analytics.my_model AS (
    SELECT * FROM source WHERE ...
);

-- Exécutions suivantes : INSERT/MERGE
INSERT INTO analytics.my_model (
    SELECT * FROM source 
    WHERE updated_at > (SELECT MAX(updated_at) FROM analytics.my_model)
);
```

### Caractéristiques

| Aspect                | Description                     |
|-----------------------|---------------------------------|
| **Stockage**          | ✅ Données physiques ✅        |
| **Temps de création** | ⚡ Rapide (delta uniquement) ⚡|
| **Coût compute**      | 💰 Réduit 💰                   |
| **Complexité**        | ⚠️ Plus élevée ⚠️              |

### Configuration

```sql
-- models/marts/fct_events.sql
{{
    config(
        materialized='incremental',
        unique_key='event_id',
        incremental_strategy='merge'
    )
}}

SELECT
    event_id,
    user_id,
    event_type,
    event_timestamp,
    properties
FROM {{ ref('stg_events') }}

-- Condition pour les runs incrémentaux
{% if is_incremental() %}
WHERE event_timestamp > (
    SELECT MAX(event_timestamp) FROM {{ this }}
)
{% endif %}
```

### La fonction is_incremental()

```sql
{% if is_incremental() %}
    -- Ce code s'exécute uniquement si :
    -- 1. Le model existe déjà
    -- 2. Ce n'est pas un --full-refresh
{% endif %}
```

### Stratégies incrémentales

| Stratégie          | Description             | Warehouse           |
|--------------------|-------------------------|---------------------|
| `append`           | INSERT simple           | Tous                |
| `merge`            | MERGE (upsert)          | Snowflake, BigQuery |
| `delete+insert`    | DELETE puis INSERT      | Redshift, Postgres  |
| `insert_overwrite` | Remplace des partitions | BigQuery, Spark     |

### Exemple avec MERGE

```sql
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',
        merge_update_columns=['status', 'updated_at']
    )
}}

SELECT
    order_id,
    customer_id,
    amount,
    status,
    created_at,
    updated_at
FROM {{ ref('stg_orders') }}

{% if is_incremental() %}
WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

### Quand utiliser INCREMENTAL ?

```
✅ UTILISER POUR :
- Tables très volumineuses (millions de lignes)
- Données avec timestamp fiable
- Tables d'événements (logs, clicks)
- Réduction des coûts compute

❌ ÉVITER POUR :
- Petites tables
- Données sans timestamp fiable
- Logique complexe de mise à jour
- Premières itérations (plus simple = mieux)
```

### Full Refresh

```bash
# Reconstruire complètement un model incremental
dbt run --select fct_events --full-refresh
```

---

## Ephemeral

### Fonctionnement

Un model **ephemeral** n'est pas matérialisé. Il est injecté comme CTE dans les models qui le référencent.

```sql
-- int_helper.sql (ephemeral)
{{ config(materialized='ephemeral') }}
SELECT * FROM {{ ref('stg_data') }}

-- fct_final.sql (qui ref() int_helper)
-- DBT compile en :
WITH int_helper AS (
    SELECT * FROM analytics.stg_data  -- Injecté ici
)
SELECT * FROM int_helper
```

### Caractéristiques

| Aspect          | Description                      |
|-----------------|----------------------------------|
| **Stockage**    | ❌ Aucun objet créé ❌          |
| **Visibilité**  | ❌ Non queryable directement ❌ |
| **Performance** | ⚠️ Réexécuté à chaque ref() ⚠️  |
| **Debug**       | ⚠️ Plus difficile ⚠️            |

### Quand utiliser EPHEMERAL ?

```
✅ UTILISER POUR :
- Models intermediate simples
- Éviter la prolifération de tables
- Logique réutilisée une seule fois
- Transformations légères

❌ ÉVITER POUR :
- Models utilisés par plusieurs autres
- Transformations lourdes
- Debug (pas de table à inspecter)
```

### Exemple

```sql
-- models/intermediate/int_orders_filtered.sql
{{ config(materialized='ephemeral') }}

SELECT *
FROM {{ ref('stg_orders') }}
WHERE status != 'cancelled'
```

---

## Comparaison et choix

### Tableau comparatif

| Critère         | View   | Table  | Incremental   | Ephemeral |
|-----------------|--------|--------|---------------|-----------|
| **Objet créé**  | Vue    | Table  | Table         | Aucun     |
| **Stockage**    | ❌❌  | ✅✅  | ✅✅         | ❌❌     |
| **Temps build** | ⚡⚡  | ⏱️⏱️  | ⚡⚡ (delta) | ⚡⚡     |
| **Temps query** | ⏱️⏱️  | ⚡⚡  | ⚡⚡         | N/A       |
| **Fraîcheur**   | ✅✅  | ⚠️⚠️  | ⚠️⚠️         | N/A       |
| **Complexité**  | Faible | Faible | Élevée        | Faible    |

### Guide de choix

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ARBRE DE DÉCISION                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  "Table volumineuse (> 10M lignes) ?"                               │
│      │                                                              │
│      ├── OUI → "Données avec timestamp fiable ?"                    │
│      │            │                                                 │
│      │            ├── OUI → INCREMENTAL                             │
│      │            └── NON → TABLE                                   │
│      │                                                              │
│      └── NON → "Utilisé par les utilisateurs finaux ?"              │
│                   │                                                 │
│                   ├── OUI → TABLE (marts)                           │
│                   │                                                 │
│                   └── NON → "Référencé par plusieurs models ?"      │
│                               │                                     │
│                               ├── OUI → VIEW                        │
│                               └── NON → EPHEMERAL                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Recommandations par couche

```yaml
# dbt_project.yml
models:
  my_project:
    staging:
      +materialized: view           # Léger, toujours à jour
    
    intermediate:
      +materialized: ephemeral      # Pas de table créée
      # Ou view si besoin de debug
    
    marts:
      +materialized: table          # Performance pour les users
      
      # Tables d'événements volumineuses
      events:
        +materialized: incremental
        +unique_key: event_id
```

### Configuration avancée Table

```sql
{{
    config(
        materialized='table',
        
        -- Snowflake : clustering
        cluster_by=['order_date'],
        
        -- BigQuery : partitionnement
        partition_by={
            "field": "order_date",
            "data_type": "date"
        },
        
        -- Redshift : distribution et sort keys
        dist='customer_id',
        sort='order_date'
    )
}}
```

---

## Résumé

| Matérialisation | Cas d'usage                 | Couche typique |
|-----------------|-----------------------------|----------------|
| **View**        | Transformations légères     | Staging        |
| **Table**       | Tables finales, performance | Marts          |
| **Incremental** | Gros volumes, événements    | Marts/Events   |
| **Ephemeral**   | Logique intermédiaire       | Intermediate   |

---

## Prochaines étapes

→ [Configuration des Models](./04-configuration-models.md)


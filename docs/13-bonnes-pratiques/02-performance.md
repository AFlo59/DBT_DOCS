# Performance DBT

## 📋 Table des matières
1. [Optimisation des models](#optimisation-des-models)
2. [Matérialisation stratégique](#matérialisation-stratégique)
3. [Optimisations warehouse-specific](#optimisations-warehouse-specific)
4. [Parallélisation](#parallélisation)
5. [Debugging et profiling](#debugging-et-profiling)

---

## Optimisation des models

### Filtrer tôt (Predicate Pushdown)

```sql
-- ✅ BON : Filtrer dans la CTE source
WITH source AS (
    SELECT *
    FROM {{ source('raw', 'events') }}
    WHERE event_date >= DATEADD('day', -30, CURRENT_DATE)  -- Filtre tôt
),

processed AS (
    SELECT
        event_id,
        user_id,
        event_type
    FROM source
)

SELECT * FROM processed

-- ❌ MAUVAIS : Filtrer à la fin
WITH source AS (
    SELECT * FROM {{ source('raw', 'events') }}  -- Lit tout
),

processed AS (
    SELECT * FROM source
)

SELECT * FROM processed
WHERE event_date >= DATEADD('day', -30, CURRENT_DATE)  -- Trop tard
```

### Limiter les colonnes

```sql
-- ✅ BON : Sélectionner uniquement les colonnes nécessaires
WITH orders AS (
    SELECT
        order_id,
        customer_id,
        order_total,
        created_at
    FROM {{ ref('stg_orders') }}
),

-- ❌ MAUVAIS : SELECT * sur des tables larges
WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}  -- 50+ colonnes non utilisées
),
```

### Éviter les sous-requêtes corrélées

```sql
-- ❌ MAUVAIS : Sous-requête corrélée (exécutée pour chaque ligne)
SELECT
    o.order_id,
    (SELECT SUM(amount) 
     FROM {{ ref('order_items') }} i 
     WHERE i.order_id = o.order_id) AS total_items
FROM {{ ref('orders') }} o

-- ✅ BON : Jointure avec agrégation
WITH order_totals AS (
    SELECT
        order_id,
        SUM(amount) AS total_items
    FROM {{ ref('order_items') }}
    GROUP BY 1
)

SELECT
    o.order_id,
    t.total_items
FROM {{ ref('orders') }} o
LEFT JOIN order_totals t
    ON o.order_id = t.order_id
```

### Optimiser les JOINs

```sql
-- ✅ BON : Filtrer avant de joindre
WITH recent_orders AS (
    SELECT * 
    FROM {{ ref('stg_orders') }}
    WHERE created_at >= '2024-01-01'  -- Réduire le dataset
),

active_customers AS (
    SELECT *
    FROM {{ ref('dim_customers') }}
    WHERE is_active = TRUE  -- Réduire le dataset
)

SELECT
    o.order_id,
    c.customer_name
FROM recent_orders o
JOIN active_customers c
    ON o.customer_id = c.customer_id
```

---

## Matérialisation stratégique

### Guide de choix

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CHOIX DE MATÉRIALISATION                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Volume faible + Lecture fréquente    → TABLE                      │
│   Volume faible + Lecture rare         → VIEW                       │
│   Volume élevé + Données append-only   → INCREMENTAL                │
│   Logique intermédiaire réutilisée     → VIEW ou TABLE              │
│   Logique intermédiaire unique         → EPHEMERAL                  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Configuration par couche

```yaml
# dbt_project.yml

models:
  my_project:
    staging:
      +materialized: view           # Léger, toujours frais
    
    intermediate:
      +materialized: ephemeral      # Pas de stockage
      # Ou view pour debug
    
    marts:
      +materialized: table          # Performance de lecture
      
      # Tables volumineuses
      events:
        +materialized: incremental
        +unique_key: event_id
```

### Incremental efficace

```sql
{{
    config(
        materialized='incremental',
        unique_key='event_id',
        incremental_strategy='merge',
        
        -- BigQuery : partitionnement
        partition_by={
            "field": "event_date",
            "data_type": "date"
        },
        
        -- Snowflake : clustering
        cluster_by=['event_date', 'user_id']
    )
}}

SELECT
    event_id,
    user_id,
    event_type,
    event_date,
    created_at
FROM {{ ref('stg_events') }}

{% if is_incremental() %}
WHERE created_at > (
    SELECT MAX(created_at) FROM {{ this }}
)
{% endif %}
```

---

## Optimisations warehouse-specific

### Snowflake

```sql
{{
    config(
        materialized='table',
        
        -- Clustering (améliore les scans)
        cluster_by=['order_date', 'customer_id'],
        
        -- Table transient (pas de Time Travel, moins cher)
        transient=true,
        
        -- Warehouse size pour ce model
        snowflake_warehouse='TRANSFORM_WH_L'
    )
}}
```

### BigQuery

```sql
{{
    config(
        materialized='table',
        
        -- Partitionnement (réduit les coûts de scan)
        partition_by={
            "field": "event_date",
            "data_type": "date",
            "granularity": "day"
        },
        
        -- Clustering (optimise les filtres)
        cluster_by=['user_id', 'event_type'],
        
        -- Expiration des partitions
        partition_expiration_days=90,
        
        -- Require partition filter
        require_partition_filter=true
    )
}}
```

### Redshift

```sql
{{
    config(
        materialized='table',
        
        -- Distribution (colocation des données)
        dist='customer_id',  -- ou 'all', 'even'
        
        -- Sort keys (améliore les scans)
        sort=['order_date', 'order_id'],
        sort_type='compound'  -- ou 'interleaved'
    )
}}
```

---

## Parallélisation

### Threads

```yaml
# profiles.yml

my_profile:
  target: prod
  outputs:
    prod:
      type: snowflake
      threads: 16  # Nombre de models en parallèle
      # ...
```

```bash
# Override en ligne de commande
dbt run --threads 32
```

### Optimiser le DAG

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DAG OPTIMISÉ                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ❌ DAG séquentiel (lent)           ✅ DAG parallélisé (rapide)    │
│                                                                      │
│   A                                  A ── B ── C                    │
│   │                                  │                               │
│   B                                  D ── E ── F                    │
│   │                                  │                               │
│   C                                  G ── H ── I                    │
│   │                                                                  │
│   D                                  Les branches indépendantes     │
│   │                                  s'exécutent en parallèle       │
│   ...                                                                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Éviter les goulots d'étranglement

```sql
-- ❌ MAUVAIS : Un model qui dépend de tout
-- fct_everything.sql dépend de 50 models → goulot

-- ✅ BON : Diviser en models spécialisés
-- fct_orders.sql → quelques dépendances
-- fct_customers.sql → quelques dépendances
-- Ces models peuvent s'exécuter en parallèle
```

---

## Debugging et profiling

### Voir le SQL compilé

```bash
# Compiler sans exécuter
dbt compile --select my_model

# Le SQL est dans target/compiled/
cat target/compiled/my_project/models/my_model.sql
```

### Analyser les temps d'exécution

```bash
# Les résultats sont dans target/run_results.json
cat target/run_results.json | jq '.results[] | {name: .unique_id, time: .execution_time}'
```

### Identifier les models lents

```bash
# Exécuter avec timing détaillé
dbt run --select my_model 2>&1 | tee run.log

# Ou utiliser dbt Cloud pour le monitoring
```

### Query profiling dans le warehouse

```sql
-- Snowflake : Query History
SELECT 
    query_id,
    query_text,
    execution_time,
    bytes_scanned,
    rows_produced
FROM snowflake.account_usage.query_history
WHERE query_text LIKE '%my_model%'
ORDER BY start_time DESC
LIMIT 10;

-- BigQuery : INFORMATION_SCHEMA
SELECT
    job_id,
    total_bytes_processed,
    total_slot_ms
FROM `region-us`.INFORMATION_SCHEMA.JOBS
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
```

### EXPLAIN plan

```sql
-- Snowflake
EXPLAIN SELECT * FROM {{ ref('my_model') }} WHERE ...;

-- BigQuery
-- Utiliser le Query Plan dans la console

-- PostgreSQL
EXPLAIN ANALYZE SELECT * FROM my_model WHERE ...;
```

---

## Résumé

### Checklist performance

```
□ OPTIMISATION SQL
  ├── Filtrer tôt (WHERE dans les CTEs sources)
  ├── Sélectionner uniquement les colonnes nécessaires
  ├── Éviter les sous-requêtes corrélées
  └── Filtrer avant de joindre

□ MATÉRIALISATION
  ├── view pour staging (léger)
  ├── table pour marts (performance lecture)
  ├── incremental pour gros volumes
  └── ephemeral pour intermédiaires

□ WAREHOUSE SPECIFIC
  ├── Partitionnement (BigQuery, Snowflake)
  ├── Clustering (BigQuery, Snowflake)
  ├── Distribution keys (Redshift)
  └── Sort keys (Redshift)

□ PARALLÉLISATION
  ├── Threads appropriés
  └── DAG optimisé (pas de goulots)
```

### Règles d'or

| Règle | Impact |
|-------|--------|
| Filtrer tôt | Réduit le volume traité |
| Limiter les colonnes | Réduit I/O |
| Partitionner | Réduit les scans |
| Clusterer | Optimise les filtres |
| Paralléliser | Réduit le temps total |

---

## Prochaines étapes

→ [Maintenance et CI/CD](./03-maintenance-ci-cd.md)


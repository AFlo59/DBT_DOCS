# Configuration des Models

## 📋 Table des matières
1. [Méthodes de configuration](#méthodes-de-configuration)
2. [Options de configuration](#options-de-configuration)
3. [Configuration par environnement](#configuration-par-environnement)
4. [Hooks (pre et post)](#hooks-pre-et-post)
5. [Grants et permissions](#grants-et-permissions)
6. [Configurations avancées](#configurations-avancées)

---

## Méthodes de configuration

### Les 3 niveaux de configuration

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HIÉRARCHIE DE CONFIGURATION                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  PRIORITÉ CROISSANTE                                                │
│  ───────────────────                                                │
│                                                                     │
│  1. dbt_project.yml (global)      ─── Moins prioritaire             │
│         │                                                           │
│         ▼                                                           │
│  2. schema.yml (par model)                                          │
│         │                                                           │
│         ▼                                                           │
│  3. config() dans le model        ─── Plus prioritaire              │
│                                                                     │
│  La config la plus spécifique l'emporte toujours.                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Niveau 1 : dbt_project.yml

```yaml
# dbt_project.yml

models:
  my_project:
    # Configuration globale
    +materialized: view
    +persist_docs:
      relation: true
      columns: true
    
    # Par dossier
    staging:
      +materialized: view
      +schema: staging
    
    marts:
      +materialized: table
      +schema: marts
      
      finance:
        +schema: finance_marts
        +tags: ['finance', 'sensitive']
```

### Niveau 2 : schema.yml

```yaml
# models/marts/core/_core__models.yml

version: 2

models:
  - name: fct_orders
    description: "Table de faits des commandes"
    config:
      materialized: table
      tags: ['core', 'daily']
      
  - name: dim_customers
    description: "Dimension clients"
    config:
      materialized: table
      unique_key: customer_id
```

### Niveau 3 : Bloc config()

```sql
-- models/marts/core/fct_orders.sql

{{
    config(
        materialized='table',
        schema='core_marts',
        alias='orders_fact',
        tags=['core', 'daily', 'critical'],
        persist_docs={'relation': true, 'columns': true}
    )
}}

SELECT ...
```

### Préfixe + vs sans préfixe

```yaml
# Dans dbt_project.yml

models:
  my_project:
    staging:
      # AVEC + : appliqué à tous les models du dossier
      +materialized: view
      +schema: staging
      
      # SANS + : crée un sous-dossier virtuel (rare)
      subfolder:
        +materialized: table
```

---

## Options de configuration

### Configurations courantes

| Option         | Description                | Valeurs                                     |
|----------------|----------------------------|---------------------------------------------|
| `materialized` | Type de matérialisation    | `view`, `table`, `incremental`, `ephemeral` |
| `schema`       | Schéma cible               | String                                      |
| `database`     | Base de données cible      | String                                      |
| `alias`        | Nom de la table (override) | String                                      |
| `tags`         | Tags pour sélection        | Liste                                       |
| `enabled`      | Activer/désactiver         | Boolean                                     |

### Configuration schema et alias

```sql
-- Le nom final de la table
-- database.schema.alias

{{
    config(
        database='ANALYTICS_DB',    -- Override la database
        schema='finance',           -- Schema personnalisé
        alias='fact_orders'         -- Nom de la table (sinon = nom du fichier)
    )
}}

-- Résultat : ANALYTICS_DB.finance.fact_orders
```

### Configuration enabled

```sql
-- Désactiver un model
{{
    config(
        enabled=false
    )
}}

-- Ou conditionnel
{{
    config(
        enabled=var('enable_legacy_models', false)
    )
}}
```

### Configuration tags

```sql
{{
    config(
        tags=['daily', 'finance', 'critical']
    )
}}
```

```bash
# Sélection par tag
dbt run --select tag:daily
dbt run --select tag:finance
dbt test --select tag:critical
```

### Configuration persist_docs

```yaml
# Persister la documentation dans le warehouse
models:
  my_project:
    +persist_docs:
      relation: true    # Description de la table
      columns: true     # Description des colonnes
```

---

## Configuration par environnement

### Utilisation de target

```sql
{{
    config(
        materialized = 'view' if target.name == 'dev' else 'table'
    )
}}

-- Ou plus verbeux
{% if target.name == 'dev' %}
    {{ config(materialized='view') }}
{% elif target.name == 'prod' %}
    {{ config(materialized='table') }}
{% endif %}
```

### Variables d'environnement

```sql
{{
    config(
        materialized = var('default_materialization', 'view'),
        schema = var('target_schema', 'analytics')
    )
}}
```

```bash
# Override en ligne de commande
dbt run --vars '{"default_materialization": "table"}'
```

### Configuration conditionnelle

```yaml
# dbt_project.yml

vars:
  is_production: "{{ target.name == 'prod' }}"

models:
  my_project:
    staging:
      +materialized: "{{ 'table' if var('is_production') else 'view' }}"
```

---

## Hooks (pre et post)

### Concept

Les **hooks** sont des commandes SQL exécutées avant ou après un model.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ORDRE D'EXÉCUTION                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. pre-hook       (avant la création de la table)                  │
│         │                                                           │
│         ▼                                                           │
│  2. CREATE TABLE AS SELECT ...                                      │
│         │                                                           │
│         ▼                                                           │
│  3. post-hook      (après la création de la table)                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Syntaxe

```sql
{{
    config(
        pre_hook=[
            "DELETE FROM {{ this }} WHERE date < DATEADD('day', -7, CURRENT_DATE)"
        ],
        post_hook=[
            "ANALYZE TABLE {{ this }}",
            "GRANT SELECT ON {{ this }} TO ROLE analyst"
        ]
    )
}}
```

### Cas d'usage courants

#### 1. Accorder des permissions

```sql
{{
    config(
        post_hook=[
            "GRANT SELECT ON {{ this }} TO ROLE analyst_role",
            "GRANT SELECT ON {{ this }} TO ROLE bi_role"
        ]
    )
}}
```

#### 2. Mettre à jour des statistiques

```sql
{{
    config(
        post_hook=[
            "ANALYZE {{ this }}"  -- PostgreSQL/Redshift
        ]
    )
}}
```

#### 3. Logging

```sql
{{
    config(
        pre_hook=[
            "INSERT INTO audit.run_log (model_name, started_at) VALUES ('{{ this.name }}', CURRENT_TIMESTAMP)"
        ],
        post_hook=[
            "UPDATE audit.run_log SET completed_at = CURRENT_TIMESTAMP WHERE model_name = '{{ this.name }}'"
        ]
    )
}}
```

#### 4. Nettoyage pour incremental

```sql
{{
    config(
        materialized='incremental',
        pre_hook=[
            "DELETE FROM {{ this }} WHERE _loaded_at < DATEADD('day', -90, CURRENT_DATE)"
        ]
    )
}}
```

### Hooks globaux

```yaml
# dbt_project.yml

on-run-start:
  - "CREATE SCHEMA IF NOT EXISTS {{ target.schema }}"

on-run-end:
  - "GRANT USAGE ON SCHEMA {{ target.schema }} TO ROLE analyst"

models:
  my_project:
    +post-hook:
      - "ANALYZE {{ this }}"
```

---

## Grants et permissions

### Configuration des grants

```yaml
# dbt_project.yml

models:
  my_project:
    +grants:
      select: ['analyst_role', 'bi_role']
      
    marts:
      +grants:
        select: ['analyst_role', 'bi_role', 'app_role']
        insert: ['etl_role']
```

### Dans le model

```sql
{{
    config(
        grants={
            'select': ['analyst', 'bi_team'],
            'insert': ['data_team']
        }
    )
}}
```

### Différence hooks vs grants

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HOOKS vs GRANTS                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  HOOKS (post_hook)                                                  │
│  ─────────────────                                                  │
│  • Exécuté à chaque run                                             │
│  • Flexible (n'importe quel SQL)                                    │
│  • Peut échouer silencieusement                                     │
│                                                                     │
│  GRANTS (config)                                                    │
│  ───────────────                                                    │
│  • Géré par DBT nativement                                          │
│  • Révocation automatique si supprimé                               │
│  • Meilleure traçabilité                                            │
│  • Recommandé pour les permissions                                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Configurations avancées

### Configurations spécifiques Snowflake

```sql
{{
    config(
        materialized='table',
        
        -- Transient table (pas de Time Travel)
        transient=true,
        
        -- Clustering
        cluster_by=['order_date', 'customer_id'],
        
        -- Copy grants lors du replace
        copy_grants=true,
        
        -- Secure view
        secure=true,  -- Pour les views
        
        -- Query tag
        query_tag='dbt_{{ this.name }}'
    )
}}
```

### Configurations spécifiques BigQuery

```sql
{{
    config(
        materialized='table',
        
        -- Partitionnement
        partition_by={
            "field": "created_date",
            "data_type": "date",
            "granularity": "day"
        },
        
        -- Clustering
        cluster_by=['customer_id', 'product_id'],
        
        -- Expiration
        partition_expiration_days=90,
        
        -- Labels
        labels={'team': 'analytics', 'env': 'prod'}
    )
}}
```

### Configurations spécifiques Redshift

```sql
{{
    config(
        materialized='table',
        
        -- Distribution style
        dist='customer_id',
        -- ou dist='all', dist='even'
        
        -- Sort keys
        sort=['order_date', 'order_id'],
        sort_type='interleaved',
        
        -- Bind parameters
        bind=false
    )
}}
```

### Configuration incremental avancée

```sql
{{
    config(
        materialized='incremental',
        unique_key='event_id',
        
        -- Stratégie
        incremental_strategy='merge',
        
        -- Colonnes à mettre à jour lors du merge
        merge_update_columns=['status', 'updated_at'],
        
        -- Ou colonnes à exclure
        merge_exclude_columns=['created_at'],
        
        -- Prédicat d'incrémental (BigQuery)
        incremental_predicates=[
            "DBT_INTERNAL_DEST.event_date >= DATEADD('day', -3, CURRENT_DATE)"
        ]
    )
}}
```

### on_schema_change

```sql
{{
    config(
        materialized='incremental',
        on_schema_change='append_new_columns'
        -- Options: 'ignore', 'fail', 'append_new_columns', 'sync_all_columns'
    )
}}
```

| Option | Comportement |
|--------|--------------|
| `ignore` | Ignore les nouvelles colonnes |
| `fail` | Erreur si le schéma change |
| `append_new_columns` | Ajoute les nouvelles colonnes |
| `sync_all_columns` | Synchronise le schéma complet |

---

## Résumé

### Priorité des configurations

1. `config()` dans le model (plus prioritaire)
2. `schema.yml`
3. `dbt_project.yml` (moins prioritaire)

### Options essentielles

| Option               | Usage                     |
|----------------------|---------------------------|
| `materialized`       | Type de table créée       |
| `schema`             | Schéma cible              |
| `tags`               | Sélection et organisation |
| `enabled`            | Activer/désactiver        |
| `grants`             | Permissions               |
| `pre_hook/post_hook` | SQL avant/après           |

### Checklist

- [ ] Définir les matérialisations par couche dans `dbt_project.yml`
- [ ] Utiliser des tags pour la sélection
- [ ] Configurer les grants pour les marts
- [ ] Utiliser `persist_docs` pour la documentation

---

## Prochaines étapes

→ [Définition des Sources](../05-sources/01-definition-sources.md)


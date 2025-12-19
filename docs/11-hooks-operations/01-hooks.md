# Hooks dans DBT

## 📋 Table des matières
1. [Concept des hooks](#concept-des-hooks)
2. [Types de hooks](#types-de-hooks)
3. [Pre-hooks et post-hooks](#pre-hooks-et-post-hooks)
4. [On-run hooks](#on-run-hooks)
5. [Cas d'usage pratiques](#cas-dusage-pratiques)

---

## Concept des hooks

### Qu'est-ce qu'un hook ?

Un **hook** est une commande SQL exécutée automatiquement à un moment précis du cycle de vie d'un model ou d'un run DBT.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CYCLE D'EXÉCUTION AVEC HOOKS                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   dbt run                                                           │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  on-run-start     ← Hook début de run                       │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│                              ▼                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  Pour chaque model :                                        │   │
│   │  ┌───────────────────────────────────────────────────────┐  │   │
│   │  │  pre-hook       ← Avant le model                      │  │   │
│   │  └───────────────────────────────────────────────────────┘  │   │
│   │                          │                                  │   │
│   │                          ▼                                  │   │
│   │  ┌───────────────────────────────────────────────────────┐  │   │
│   │  │  CREATE TABLE ... AS SELECT ...                       │  │   │
│   │  └───────────────────────────────────────────────────────┘  │   │
│   │                          │                                  │   │
│   │                          ▼                                  │   │
│   │  ┌───────────────────────────────────────────────────────┐  │   │
│   │  │  post-hook      ← Après le model                      │  │   │
│   │  └───────────────────────────────────────────────────────┘  │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                              │                                      │
│                              ▼                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  on-run-end       ← Hook fin de run                         │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Types de hooks

| Hook           | Portée | Moment                  |
|----------------|--------|-------------------------|
| `pre-hook`     | Model  | Avant création du model |
| `post-hook`    | Model  | Après création du model |
| `on-run-start` | Run    | Début du run complet    |
| `on-run-end`   | Run    | Fin du run complet      |

---

## Pre-hooks et post-hooks

### Syntaxe dans le model

```sql
-- models/marts/fct_orders.sql

{{
    config(
        materialized='table',
        pre_hook=[
            "DELETE FROM {{ this }} WHERE order_date < DATEADD('day', -90, CURRENT_DATE)"
        ],
        post_hook=[
            "GRANT SELECT ON {{ this }} TO ROLE analyst",
            "ANALYZE {{ this }}"
        ]
    )
}}

SELECT ...
```

### Syntaxe dans dbt_project.yml

```yaml
# dbt_project.yml

models:
  my_project:
    marts:
      +post-hook:
        - "GRANT SELECT ON {{ this }} TO ROLE analyst"
        - "ANALYZE {{ this }}"
    
    staging:
      +post-hook:
        - "COMMENT ON TABLE {{ this }} IS 'Staging table'"
```

### Hook unique vs liste

```sql
-- Hook unique (string)
{{ config(post_hook="GRANT SELECT ON {{ this }} TO ROLE analyst") }}

-- Plusieurs hooks (liste)
{{
    config(
        post_hook=[
            "GRANT SELECT ON {{ this }} TO ROLE analyst",
            "GRANT SELECT ON {{ this }} TO ROLE bi_team",
            "ANALYZE {{ this }}"
        ]
    )
}}
```

### Transaction et hooks

```yaml
# Exécuter le hook dans la même transaction que le model
models:
  my_project:
    +post-hook:
      sql: "GRANT SELECT ON {{ this }} TO ROLE analyst"
      transaction: true  # Défaut: true
```

---

## On-run hooks

### Syntaxe

```yaml
# dbt_project.yml

# Exécuté au début de chaque run
on-run-start:
  - "CREATE SCHEMA IF NOT EXISTS {{ target.schema }}"
  - "{{ log_run_start() }}"  # Appel de macro

# Exécuté à la fin de chaque run
on-run-end:
  - "GRANT USAGE ON SCHEMA {{ target.schema }} TO ROLE analyst"
  - "{{ log_run_end() }}"
```

### Variables disponibles

```yaml
on-run-end:
  # Accéder aux résultats du run
  - "{{ log('Run completed with ' ~ results|length ~ ' models') }}"
```

### Macros pour on-run hooks

```sql
-- macros/log_run.sql

{% macro log_run_start() %}
    INSERT INTO audit.run_log (run_id, started_at, target)
    VALUES (
        '{{ invocation_id }}',
        CURRENT_TIMESTAMP,
        '{{ target.name }}'
    )
{% endmacro %}

{% macro log_run_end() %}
    UPDATE audit.run_log
    SET 
        completed_at = CURRENT_TIMESTAMP,
        status = 'completed'
    WHERE run_id = '{{ invocation_id }}'
{% endmacro %}
```

---

## Cas d'usage pratiques

### 1. Accorder des permissions

```sql
{{
    config(
        post_hook=[
            "GRANT SELECT ON {{ this }} TO ROLE analyst",
            "GRANT SELECT ON {{ this }} TO ROLE bi_team"
        ]
    )
}}
```

**Ou avec grants (recommandé dbt 1.2+) :**

```sql
{{
    config(
        grants={
            'select': ['analyst', 'bi_team']
        }
    )
}}
```

### 2. Mettre à jour les statistiques

```sql
-- PostgreSQL / Redshift
{{
    config(
        post_hook="ANALYZE {{ this }}"
    )
}}

-- Snowflake (automatique, mais possible)
{{
    config(
        post_hook="ALTER TABLE {{ this }} SET DATA_RETENTION_TIME_IN_DAYS = 7"
    )
}}
```

### 3. Logging et audit

```sql
{{
    config(
        pre_hook=[
            "INSERT INTO audit.model_runs (model, started_at) VALUES ('{{ this.name }}', CURRENT_TIMESTAMP)"
        ],
        post_hook=[
            "UPDATE audit.model_runs SET completed_at = CURRENT_TIMESTAMP WHERE model = '{{ this.name }}' AND completed_at IS NULL"
        ]
    )
}}
```

### 4. Nettoyage pour incremental

```sql
{{
    config(
        materialized='incremental',
        pre_hook=[
            "{% if is_incremental() %}DELETE FROM {{ this }} WHERE _loaded_at < DATEADD('day', -90, CURRENT_DATE){% endif %}"
        ]
    )
}}
```

### 5. Swap de tables (blue-green)

```yaml
# dbt_project.yml

on-run-end:
  - "ALTER TABLE {{ target.schema }}.fct_orders_new SWAP WITH {{ target.schema }}.fct_orders"
```

### 6. Notifications

```sql
-- macros/notify.sql

{% macro send_slack_notification(message) %}
    {% if target.name == 'prod' %}
        {% do run_query("SELECT http_post('https://hooks.slack.com/...', '{ \"text\": \"" ~ message ~ "\" }')") %}
    {% endif %}
{% endmacro %}
```

```yaml
on-run-end:
  - "{{ send_slack_notification('DBT run completed!') }}"
```

### 7. Créer des schémas

```yaml
on-run-start:
  - "CREATE SCHEMA IF NOT EXISTS {{ target.schema }}_staging"
  - "CREATE SCHEMA IF NOT EXISTS {{ target.schema }}_marts"
  - "CREATE SCHEMA IF NOT EXISTS {{ target.schema }}_snapshots"
```

---

## Bonnes pratiques

### Ordre d'exécution

```yaml
# Les hooks sont exécutés dans l'ordre de définition
post_hook:
  - "ANALYZE {{ this }}"          # 1er
  - "GRANT SELECT ON {{ this }}"  # 2ème
```

### Hooks conditionnels

```sql
{{
    config(
        post_hook=[
            "{% if target.name == 'prod' %}GRANT SELECT ON {{ this }} TO ROLE prod_analysts{% endif %}"
        ]
    )
}}
```

### Gestion des erreurs

```sql
-- Les hooks échouent silencieusement par défaut
-- Utiliser des macros pour une meilleure gestion

{% macro safe_grant(role) %}
    {% set grant_sql %}
        GRANT SELECT ON {{ this }} TO ROLE {{ role }}
    {% endset %}
    
    {% do run_query(grant_sql) %}
    {{ log("Granted SELECT to " ~ role, info=true) }}
{% endmacro %}
```

### Ne pas abuser des hooks

```
✅ UTILISER POUR :
- Permissions (GRANT)
- Statistiques (ANALYZE)
- Logging simple
- Configuration warehouse

❌ ÉVITER POUR :
- Logique de transformation (→ models)
- Manipulation de données (→ models)
- Orchestration complexe (→ Airflow)
```

---

## Résumé

### Types de hooks

| Hook           | Quand       | Où configurer               |
|----------------|-------------|-----------------------------|
| `pre-hook`     | Avant model | config() ou dbt_project.yml |
| `post-hook`    | Après model | config() ou dbt_project.yml |
| `on-run-start` | Début run   | dbt_project.yml             |
| `on-run-end`   | Fin run     | dbt_project.yml             |

### Syntaxe rapide

```sql
-- Dans le model
{{ config(post_hook="SQL") }}

-- Liste
{{ config(post_hook=["SQL1", "SQL2"]) }}
```

```yaml
# Dans dbt_project.yml
models:
  +post-hook: "SQL"

on-run-start:
  - "SQL"
```

---

## Prochaines étapes

→ [Opérations on-run](./02-operations-on-run.md)


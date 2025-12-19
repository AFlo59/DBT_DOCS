# Opérations On-Run

## 📋 Table des matières
1. [dbt run-operation](#dbt-run-operation)
2. [Création d'opérations](#création-dopérations)
3. [Exemples pratiques](#exemples-pratiques)
4. [Intégration CI/CD](#intégration-cicd)

---

## dbt run-operation

### Concept

`dbt run-operation` permet d'exécuter une macro directement depuis la ligne de commande, sans exécuter de models.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RUN-OPERATION                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Commande :                                                         │
│   dbt run-operation my_macro --args '{"param": "value"}'            │
│                                                                      │
│                         │                                            │
│                         ▼                                            │
│                                                                      │
│   Macro exécutée :                                                   │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │  {% macro my_macro(param) %}                                │   │
│   │      {% do run_query("SQL utilisant " ~ param) %}          │   │
│   │  {% endmacro %}                                             │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   Usage : Tâches administratives, maintenance, scripts ponctuels   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Syntaxe

```bash
# Sans arguments
dbt run-operation my_macro

# Avec arguments
dbt run-operation my_macro --args '{"arg1": "value1", "arg2": "value2"}'

# Arguments JSON complexes
dbt run-operation my_macro --args '{"columns": ["col1", "col2"]}'
```

---

## Création d'opérations

### Structure de base

```sql
-- macros/operations/my_operation.sql

{% macro my_operation(param1, param2='default') %}

    {% set sql %}
        -- Votre SQL ici
        SELECT COUNT(*) FROM {{ ref('my_model') }}
    {% endset %}
    
    {% do run_query(sql) %}
    
    {{ log("Operation completed!", info=true) }}

{% endmacro %}
```

### Retourner des résultats

```sql
{% macro get_row_count(model_name) %}

    {% set query %}
        SELECT COUNT(*) AS cnt FROM {{ ref(model_name) }}
    {% endset %}
    
    {% set results = run_query(query) %}
    
    {% if execute %}
        {% set count = results.columns[0].values()[0] %}
        {{ log("Row count for " ~ model_name ~ ": " ~ count, info=true) }}
        {{ return(count) }}
    {% endif %}

{% endmacro %}
```

```bash
dbt run-operation get_row_count --args '{"model_name": "fct_orders"}'
```

---

## Exemples pratiques

### 1. Générer du code source (codegen)

```sql
-- macros/operations/generate_staging.sql

{% macro generate_staging_model(source_name, table_name) %}

    {% set source_relation = source(source_name, table_name) %}
    {% set columns = adapter.get_columns_in_relation(source_relation) %}
    
    {% set output %}
-- models/staging/stg_{{ source_name }}__{{ table_name }}.sql

WITH source AS (
    SELECT * FROM {{ source_relation }}
),

renamed AS (
    SELECT
        {% for column in columns %}
        {{ column.name | lower }} AS {{ column.name | lower }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM source
)

SELECT * FROM renamed
    {% endset %}
    
    {{ log(output, info=true) }}

{% endmacro %}
```

```bash
dbt run-operation generate_staging_model --args '{"source_name": "shopify", "table_name": "orders"}'
```

### 2. Nettoyer les anciens modèles

```sql
-- macros/operations/cleanup_old_models.sql

{% macro cleanup_old_models(schema_name, days_old=30) %}

    {% set cleanup_query %}
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = '{{ schema_name }}'
        AND table_name LIKE 'dbt_tmp_%'
        AND created < DATEADD('day', -{{ days_old }}, CURRENT_TIMESTAMP)
    {% endset %}
    
    {% set results = run_query(cleanup_query) %}
    
    {% if execute %}
        {% for row in results %}
            {% set drop_query %}
                DROP TABLE IF EXISTS {{ schema_name }}.{{ row['table_name'] }}
            {% endset %}
            {% do run_query(drop_query) %}
            {{ log("Dropped: " ~ row['table_name'], info=true) }}
        {% endfor %}
    {% endif %}

{% endmacro %}
```

### 3. Créer un utilisateur/rôle

```sql
-- macros/operations/create_bi_role.sql

{% macro create_bi_role() %}

    {% set statements = [
        "CREATE ROLE IF NOT EXISTS bi_reader",
        "GRANT USAGE ON WAREHOUSE compute_wh TO ROLE bi_reader",
        "GRANT USAGE ON DATABASE analytics TO ROLE bi_reader",
        "GRANT USAGE ON ALL SCHEMAS IN DATABASE analytics TO ROLE bi_reader",
        "GRANT SELECT ON ALL TABLES IN DATABASE analytics TO ROLE bi_reader"
    ] %}
    
    {% for statement in statements %}
        {% do run_query(statement) %}
        {{ log("Executed: " ~ statement, info=true) }}
    {% endfor %}

{% endmacro %}
```

### 4. Vérifier l'état des tables

```sql
-- macros/operations/table_stats.sql

{% macro table_stats(schema_name) %}

    {% set query %}
        SELECT
            table_name,
            row_count,
            bytes / 1024 / 1024 AS size_mb,
            last_altered
        FROM {{ schema_name }}.information_schema.tables
        WHERE table_schema = '{{ schema_name | upper }}'
        ORDER BY bytes DESC
    {% endset %}
    
    {% set results = run_query(query) %}
    
    {% if execute %}
        {{ log("=" * 80, info=true) }}
        {{ log("TABLE STATISTICS FOR " ~ schema_name, info=true) }}
        {{ log("=" * 80, info=true) }}
        
        {% for row in results %}
            {{ log(
                row['table_name'] ~ 
                " | Rows: " ~ row['row_count'] ~ 
                " | Size: " ~ row['size_mb'] ~ " MB" ~
                " | Updated: " ~ row['last_altered'], 
                info=true
            ) }}
        {% endfor %}
    {% endif %}

{% endmacro %}
```

### 5. Backup d'une table

```sql
-- macros/operations/backup_table.sql

{% macro backup_table(model_name) %}

    {% set timestamp = modules.datetime.datetime.now().strftime('%Y%m%d_%H%M%S') %}
    {% set backup_name = model_name ~ '_backup_' ~ timestamp %}
    
    {% set backup_query %}
        CREATE TABLE {{ target.schema }}_backups.{{ backup_name }} AS
        SELECT * FROM {{ ref(model_name) }}
    {% endset %}
    
    {% do run_query(backup_query) %}
    
    {{ log("Created backup: " ~ backup_name, info=true) }}

{% endmacro %}
```

```bash
dbt run-operation backup_table --args '{"model_name": "fct_orders"}'
```

### 6. Rafraîchir les masques de données

```sql
-- macros/operations/apply_masking_policies.sql

{% macro apply_masking_policies() %}

    {% set policies = [
        {"table": "dim_customers", "column": "email", "policy": "email_mask"},
        {"table": "dim_customers", "column": "phone", "policy": "phone_mask"},
        {"table": "fct_orders", "column": "customer_email", "policy": "email_mask"}
    ] %}
    
    {% for p in policies %}
        {% set apply_sql %}
            ALTER TABLE {{ target.schema }}.{{ p.table }}
            MODIFY COLUMN {{ p.column }}
            SET MASKING POLICY {{ p.policy }}
        {% endset %}
        
        {% do run_query(apply_sql) %}
        {{ log("Applied " ~ p.policy ~ " to " ~ p.table ~ "." ~ p.column, info=true) }}
    {% endfor %}

{% endmacro %}
```

---

## Intégration CI/CD

### Dans GitHub Actions

```yaml
# .github/workflows/maintenance.yml

name: DBT Maintenance

on:
  schedule:
    - cron: '0 2 * * 0'  # Dimanche 2h du matin

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install dbt
        run: pip install dbt-snowflake
      
      - name: Run cleanup operation
        run: |
          dbt run-operation cleanup_old_models \
            --args '{"schema_name": "analytics", "days_old": 30}'
        env:
          DBT_USER: ${{ secrets.DBT_USER }}
          DBT_PASSWORD: ${{ secrets.DBT_PASSWORD }}
```

### Dans Airflow

```python
# dags/dbt_maintenance.py

from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

with DAG('dbt_maintenance', schedule_interval='@weekly') as dag:
    
    cleanup_task = BashOperator(
        task_id='cleanup_old_models',
        bash_command="""
            cd /opt/dbt/my_project && \
            dbt run-operation cleanup_old_models \
                --args '{"schema_name": "analytics", "days_old": 30}'
        """
    )
    
    stats_task = BashOperator(
        task_id='table_stats',
        bash_command="""
            cd /opt/dbt/my_project && \
            dbt run-operation table_stats \
                --args '{"schema_name": "analytics"}'
        """
    )
    
    cleanup_task >> stats_task
```

---

## Résumé

### Commande

```bash
dbt run-operation <macro_name> --args '{"param": "value"}'
```

### Structure d'une opération

```sql
{% macro my_operation(param) %}
    {% set sql %}...{% endset %}
    {% do run_query(sql) %}
    {{ log("Done", info=true) }}
{% endmacro %}
```

### Cas d'usage

| Opération | Description |
|-----------|-------------|
| Génération de code | Créer des models automatiquement |
| Nettoyage | Supprimer les tables obsolètes |
| Administration | Créer des rôles, permissions |
| Monitoring | Statistiques, vérifications |
| Backup | Sauvegardes ponctuelles |

---

## Prochaines étapes

→ [Définition des Exposures](../12-exposures/01-definition-exposures.md)


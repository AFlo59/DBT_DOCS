# Macros Personnalisées

## 📋 Table des matières
1. [Concept des macros](#concept-des-macros)
2. [Création d'une macro](#création-dune-macro)
3. [Paramètres et arguments](#paramètres-et-arguments)
4. [Exemples pratiques](#exemples-pratiques)
5. [Macros avancées](#macros-avancées)
6. [Organisation et bonnes pratiques](#organisation-et-bonnes-pratiques)

---

## Concept des macros

### Qu'est-ce qu'une macro ?

Une **macro** est une fonction réutilisable écrite en Jinja qui génère du SQL.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONCEPT DE MACRO                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Définition (macros/)              Utilisation (models/)           │
│   ┌──────────────────────┐         ┌──────────────────────────────┐ │
│   │ {% macro             │         │ SELECT                       │ │
│   │   cents_to_dollars   │         │   {{ cents_to_dollars(       │ │
│   │   (column) %}        │  ──────>│     'price_cents'            │ │
│   │   ({{ column }}      │         │   ) }} AS price              │ │
│   │   / 100.0)           │         │ FROM table                   │ │
│   │ {% endmacro %}       │         └──────────────────────────────┘ │
│   └──────────────────────┘                                          │
│                                                                     │
│   Résultat compilé :                                                │
│   SELECT (price_cents / 100.0) AS price FROM table                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Avantages des macros

| Avantage           | Description                 |
|--------------------|-----------------------------|
| **DRY**            | Ne pas répéter le même code |
| **Maintenabilité** | Modifier en un seul endroit |
| **Lisibilité**     | Code plus propre            |
| **Tests**          | Logique testable            |

---

## Création d'une macro

### Emplacement

```
my_project/
├── macros/
│   ├── utils/
│   │   ├── cents_to_dollars.sql
│   │   └── generate_surrogate_key.sql
│   ├── schema_utils.sql
│   └── custom_tests.sql
└── models/
```

### Syntaxe de base

```sql
-- macros/cents_to_dollars.sql

{% macro cents_to_dollars(column_name) %}
    ({{ column_name }} / 100.0)
{% endmacro %}
```

### Utilisation

```sql
-- models/fct_orders.sql

SELECT
    order_id,
    {{ cents_to_dollars('price_cents') }} AS price,
    {{ cents_to_dollars('tax_cents') }} AS tax
FROM {{ ref('stg_orders') }}
```

### SQL compilé

```sql
SELECT
    order_id,
    (price_cents / 100.0) AS price,
    (tax_cents / 100.0) AS tax
FROM analytics.stg_orders
```

---

## Paramètres et arguments

### Paramètres positionnels

```sql
{% macro format_date(column_name, format) %}
    TO_CHAR({{ column_name }}, '{{ format }}')
{% endmacro %}

-- Utilisation
{{ format_date('created_at', 'YYYY-MM-DD') }}
```

### Paramètres avec valeur par défaut

```sql
{% macro safe_divide(numerator, denominator, default_value=0) %}
    CASE 
        WHEN {{ denominator }} = 0 THEN {{ default_value }}
        ELSE {{ numerator }} / {{ denominator }}
    END
{% endmacro %}

-- Utilisation
{{ safe_divide('revenue', 'orders') }}           -- default = 0
{{ safe_divide('revenue', 'orders', 'NULL') }}   -- default = NULL
```

### Paramètres nommés

```sql
{% macro generate_surrogate_key(columns) %}
    {{ dbt_utils.generate_surrogate_key(columns) }}
{% endmacro %}

-- Utilisation
{{ generate_surrogate_key(columns=['order_id', 'product_id']) }}
```

---

## Exemples pratiques

### 1. Conversion de centimes en dollars

```sql
-- macros/cents_to_dollars.sql

{% macro cents_to_dollars(column_name, precision=2) %}
    ROUND({{ column_name }} / 100.0, {{ precision }})
{% endmacro %}
```

### 2. Safe divide

```sql
-- macros/safe_divide.sql

{% macro safe_divide(numerator, denominator, default=0) %}
    COALESCE(
        {{ numerator }} / NULLIF({{ denominator }}, 0),
        {{ default }}
    )
{% endmacro %}
```

### 3. Date diff en jours

```sql
-- macros/date_diff_days.sql

{% macro date_diff_days(start_date, end_date) %}
    {% if target.type == 'snowflake' %}
        DATEDIFF('day', {{ start_date }}, {{ end_date }})
    {% elif target.type == 'bigquery' %}
        DATE_DIFF({{ end_date }}, {{ start_date }}, DAY)
    {% elif target.type == 'postgres' %}
        {{ end_date }}::date - {{ start_date }}::date
    {% else %}
        DATEDIFF(day, {{ start_date }}, {{ end_date }})
    {% endif %}
{% endmacro %}
```

### 4. Générer un CASE WHEN

```sql
-- macros/generate_case_when.sql

{% macro generate_case_when(column, mapping, else_value='NULL') %}
    CASE {{ column }}
    {% for key, value in mapping.items() %}
        WHEN '{{ key }}' THEN '{{ value }}'
    {% endfor %}
        ELSE {{ else_value }}
    END
{% endmacro %}
```

```sql
-- Utilisation
SELECT
    order_id,
    {{ generate_case_when(
        'status_code',
        {'P': 'Pending', 'S': 'Shipped', 'D': 'Delivered'},
        "'Unknown'"
    ) }} AS status_name
FROM orders
```

### 5. Pivot dynamique

```sql
-- macros/pivot.sql

{% macro pivot(column, values, agg='SUM', value_column='1') %}
    {% for value in values %}
    {{ agg }}(CASE WHEN {{ column }} = '{{ value }}' THEN {{ value_column }} ELSE 0 END) 
        AS {{ value | replace(' ', '_') | lower }}{% if not loop.last %},{% endif %}
    {% endfor %}
{% endmacro %}
```

```sql
-- Utilisation
SELECT
    customer_id,
    {{ pivot('product_category', ['Electronics', 'Clothing', 'Food'], 'SUM', 'amount') }}
FROM orders
GROUP BY 1
```

### 6. Générer un schema name dynamique

```sql
-- macros/generate_schema_name.sql

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

---

## Macros avancées

### Utiliser run_query()

```sql
-- macros/get_column_values.sql

{% macro get_column_values(table, column) %}
    {% set query %}
        SELECT DISTINCT {{ column }}
        FROM {{ table }}
        WHERE {{ column }} IS NOT NULL
        ORDER BY 1
    {% endset %}
    
    {% set results = run_query(query) %}
    
    {% if execute %}
        {% set values = results.columns[0].values() %}
        {{ return(values) }}
    {% else %}
        {{ return([]) }}
    {% endif %}
{% endmacro %}
```

```sql
-- Utilisation
{% set statuses = get_column_values(ref('stg_orders'), 'status') %}

SELECT
{% for status in statuses %}
    SUM(CASE WHEN status = '{{ status }}' THEN 1 END) AS {{ status }}_count{% if not loop.last %},{% endif %}
{% endfor %}
FROM {{ ref('stg_orders') }}
```

### Macro avec SQL multiligne

```sql
-- macros/create_metric.sql

{% macro create_metric(metric_name, aggregation, column, filter=none) %}
    {{ aggregation }}(
        {% if filter %}
        CASE WHEN {{ filter }} THEN {{ column }} END
        {% else %}
        {{ column }}
        {% endif %}
    ) AS {{ metric_name }}
{% endmacro %}
```

```sql
-- Utilisation
SELECT
    customer_id,
    {{ create_metric('total_revenue', 'SUM', 'amount') }},
    {{ create_metric('completed_revenue', 'SUM', 'amount', "status = 'completed'") }},
    {{ create_metric('avg_order_value', 'AVG', 'amount') }}
FROM {{ ref('fct_orders') }}
GROUP BY 1
```

### Macro récursive

```sql
-- macros/flatten_json.sql

{% macro flatten_json_keys(json_column, keys, prefix='') %}
    {% for key in keys %}
        {% if key is mapping %}
            {# Nested keys #}
            {% for parent_key, child_keys in key.items() %}
                {{ flatten_json_keys(json_column ~ '[\'' ~ parent_key ~ '\']', child_keys, prefix ~ parent_key ~ '_') }}
            {% endfor %}
        {% else %}
            {{ json_column }}['{{ key }}'] AS {{ prefix }}{{ key }}{% if not loop.last %},{% endif %}
        {% endif %}
    {% endfor %}
{% endmacro %}
```

---

## Organisation et bonnes pratiques

### Structure recommandée

```
macros/
├── _macros.yml             # Documentation des macros
├── schema_utils/
│   ├── generate_schema_name.sql
│   └── get_custom_alias.sql
├── transformations/
│   ├── cents_to_dollars.sql
│   ├── safe_divide.sql
│   └── date_utils.sql
├── tests/
│   ├── test_positive.sql
│   └── test_not_empty.sql
└── utils/
    ├── log_macro.sql
    └── get_column_values.sql
```

### Documentation

```yaml
# macros/_macros.yml

version: 2

macros:
  - name: cents_to_dollars
    description: |
      Convertit une valeur en centimes vers des dollars.
      
      **Paramètres** :
      - `column_name` (requis) : Nom de la colonne en centimes
      - `precision` (optionnel, défaut=2) : Nombre de décimales
      
      **Exemple** :
      ```sql
      {{ cents_to_dollars('price_cents') }}
      -- Résultat : ROUND(price_cents / 100.0, 2)
      ```
    arguments:
      - name: column_name
        type: string
        description: "Nom de la colonne à convertir"
      - name: precision
        type: integer
        description: "Précision décimale"
```

### Naming conventions

```sql
-- Verbes descriptifs
{% macro generate_surrogate_key(...) %}
{% macro create_metric(...) %}
{% macro calculate_running_total(...) %}
{% macro format_date(...) %}
{% macro get_column_values(...) %}

-- Préfixe pour les utilitaires internes
{% macro _helper_function(...) %}
```

### Gestion des whitespaces

```sql
-- Utiliser {%- et -%} pour supprimer les espaces
{% macro my_macro(param) -%}
    {{ param }}
{%- endmacro %}

-- Ou utiliser ~ pour concaténer
{% macro comma_list(items) %}
    {{ items | join(', ') }}
{% endmacro %}
```

---

## Résumé

### Syntaxe de base

```sql
{% macro nom_macro(param1, param2='default') %}
    -- SQL avec {{ param1 }} et {{ param2 }}
{% endmacro %}
```

### Checklist

- [ ] Un fichier par macro (ou grouper par thème)
- [ ] Nommer clairement (verbe + description)
- [ ] Documenter les paramètres
- [ ] Gérer les cas limites (NULL, division par 0)
- [ ] Tester la macro

### Macros à avoir

| Macro                  | Usage                |
|------------------------|----------------------|
| `cents_to_dollars`     | Conversion monétaire |
| `safe_divide`          | Division sécurisée   |
| `generate_schema_name` | Schéma dynamique     |
| `date_diff`            | Différence de dates  |
| `get_column_values`    | Valeurs dynamiques   |

---

## Prochaines étapes

→ [Packages DBT](./03-packages-dbt.md)


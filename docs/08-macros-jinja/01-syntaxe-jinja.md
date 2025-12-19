# Syntaxe Jinja dans DBT

## 📋 Table des matières
1. [Introduction à Jinja](#introduction-à-jinja)
2. [Syntaxe de base](#syntaxe-de-base)
3. [Variables et expressions](#variables-et-expressions)
4. [Structures de contrôle](#structures-de-contrôle)
5. [Filtres](#filtres)
6. [Fonctions DBT natives](#fonctions-dbt-natives)

---

## Introduction à Jinja

### Qu'est-ce que Jinja ?

**Jinja** est un moteur de templates Python intégré à DBT. Il permet d'ajouter de la logique dynamique dans vos fichiers SQL.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    JINJA DANS DBT                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Fichier .sql (avec Jinja)        SQL compilé                      │
│   ┌─────────────────────┐          ┌─────────────────────────────┐  │
│   │ SELECT *            │   dbt    │ SELECT *                    │  │
│   │ FROM {{ ref(       │ ──────> │ FROM "analytics"."stg_orders"│  │
│   │   'stg_orders'     │ compile │                              │  │
│   │ ) }}               │          │                              │  │
│   └─────────────────────┘          └─────────────────────────────┘  │
│                                                                      │
│   Jinja transforme le SQL dynamiquement avant exécution            │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Pourquoi utiliser Jinja ?

| Usage | Exemple |
|-------|---------|
| **Références** | `{{ ref('model') }}` |
| **Configuration** | `{{ config(materialized='table') }}` |
| **Variables** | `{{ var('start_date') }}` |
| **Conditions** | `{% if target.name == 'prod' %}` |
| **Boucles** | `{% for col in columns %}` |
| **Macros** | Code réutilisable |

---

## Syntaxe de base

### Les 3 types de délimiteurs

```sql
{# 1. COMMENTAIRES - Ignorés lors de la compilation #}
{# Ceci est un commentaire Jinja #}

{# 2. EXPRESSIONS - Retournent une valeur #}
{{ ref('stg_orders') }}
{{ var('start_date') }}
{{ 1 + 1 }}

{# 3. STATEMENTS - Logique de contrôle #}
{% if condition %}
    ...
{% endif %}

{% for item in list %}
    ...
{% endfor %}
```

### Tableau récapitulatif

| Délimiteur | Type | Usage |
|------------|------|-------|
| `{# ... #}` | Commentaire | Notes, désactivation de code |
| `{{ ... }}` | Expression | Afficher une valeur |
| `{% ... %}` | Statement | Logique (if, for, set) |

---

## Variables et expressions

### Définir une variable

```sql
{% set my_var = 'value' %}
{% set my_list = ['a', 'b', 'c'] %}
{% set my_dict = {'key': 'value'} %}
{% set my_number = 42 %}

-- Utilisation
SELECT '{{ my_var }}' AS my_column
-- Résultat : SELECT 'value' AS my_column
```

### Variables DBT natives

```sql
-- Variable de projet (dbt_project.yml)
{{ var('start_date') }}
{{ var('optional_var', 'default_value') }}

-- Variable d'environnement
{{ env_var('DB_USER') }}
{{ env_var('OPTIONAL_VAR', 'default') }}

-- Target (environnement actuel)
{{ target.name }}        -- 'dev', 'prod'
{{ target.database }}
{{ target.schema }}

-- This (model actuel)
{{ this }}              -- Référence complète
{{ this.database }}
{{ this.schema }}
{{ this.name }}
```

### Opérateurs

```sql
{# Arithmétique #}
{{ 1 + 2 }}     -- 3
{{ 10 - 5 }}    -- 5
{{ 3 * 4 }}     -- 12
{{ 10 / 3 }}    -- 3.333...
{{ 10 // 3 }}   -- 3 (division entière)
{{ 10 % 3 }}    -- 1 (modulo)

{# Comparaison #}
{{ 1 == 1 }}    -- true
{{ 1 != 2 }}    -- true
{{ 1 < 2 }}     -- true
{{ 2 > 1 }}     -- true
{{ 1 <= 1 }}    -- true

{# Logique #}
{{ true and false }}  -- false
{{ true or false }}   -- true
{{ not true }}        -- false

{# Concaténation #}
{{ 'Hello' ~ ' ' ~ 'World' }}  -- 'Hello World'
```

---

## Structures de contrôle

### Conditions (if/elif/else)

```sql
{% if target.name == 'prod' %}
    -- Code production
    SELECT * FROM {{ ref('fct_orders') }}
{% elif target.name == 'staging' %}
    -- Code staging
    SELECT * FROM {{ ref('fct_orders') }} LIMIT 10000
{% else %}
    -- Code dev
    SELECT * FROM {{ ref('fct_orders') }} LIMIT 100
{% endif %}
```

### Condition inline

```sql
SELECT
    order_id,
    {{ 'production_amount' if target.name == 'prod' else 'test_amount' }} AS amount
FROM orders
```

### Boucles (for)

```sql
{% set payment_methods = ['credit_card', 'paypal', 'bank_transfer'] %}

SELECT
    order_id,
    {% for method in payment_methods %}
    SUM(CASE WHEN payment_method = '{{ method }}' THEN amount ELSE 0 END) 
        AS {{ method }}_amount{% if not loop.last %},{% endif %}
    {% endfor %}
FROM {{ ref('stg_payments') }}
GROUP BY 1
```

**Résultat compilé :**
```sql
SELECT
    order_id,
    SUM(CASE WHEN payment_method = 'credit_card' THEN amount ELSE 0 END) AS credit_card_amount,
    SUM(CASE WHEN payment_method = 'paypal' THEN amount ELSE 0 END) AS paypal_amount,
    SUM(CASE WHEN payment_method = 'bank_transfer' THEN amount ELSE 0 END) AS bank_transfer_amount
FROM analytics.stg_payments
GROUP BY 1
```

### Variables de boucle

```sql
{% for item in items %}
    {{ loop.index }}      -- Index (1, 2, 3...)
    {{ loop.index0 }}     -- Index 0-based (0, 1, 2...)
    {{ loop.first }}      -- true si premier élément
    {{ loop.last }}       -- true si dernier élément
    {{ loop.length }}     -- Nombre d'éléments
{% endfor %}
```

### Boucle avec dictionnaire

```sql
{% set column_mappings = {
    'order_id': 'id',
    'customer_id': 'cust_id',
    'amount': 'order_amount'
} %}

SELECT
{% for new_name, old_name in column_mappings.items() %}
    {{ old_name }} AS {{ new_name }}{% if not loop.last %},{% endif %}
{% endfor %}
FROM source_table
```

---

## Filtres

### Concept

Les filtres transforment une valeur : `{{ value | filter }}`

### Filtres courants

```sql
{# Texte #}
{{ 'hello' | upper }}           -- HELLO
{{ 'HELLO' | lower }}           -- hello
{{ '  hello  ' | trim }}        -- hello
{{ 'hello' | capitalize }}      -- Hello
{{ 'hello' | replace('e', 'a') }}  -- hallo

{# Listes #}
{{ [1, 2, 3] | length }}        -- 3
{{ [3, 1, 2] | sort }}          -- [1, 2, 3]
{{ [1, 2, 3] | first }}         -- 1
{{ [1, 2, 3] | last }}          -- 3
{{ [1, 2, 3] | join(', ') }}    -- '1, 2, 3'

{# Valeurs par défaut #}
{{ undefined_var | default('fallback') }}

{# Conversion #}
{{ '42' | int }}                -- 42
{{ 42 | string }}               -- '42'
{{ '3.14' | float }}            -- 3.14
```

### Filtres chaînés

```sql
{{ '  HELLO WORLD  ' | trim | lower }}
-- Résultat : 'hello world'
```

### Exemple pratique

```sql
{% set columns = ['order_id', 'customer_id', 'amount'] %}

SELECT
    {{ columns | join(',\n    ') }}
FROM {{ ref('stg_orders') }}

-- Résultat :
-- SELECT
--     order_id,
--     customer_id,
--     amount
-- FROM analytics.stg_orders
```

---

## Fonctions DBT natives

### ref()

Référence un model DBT.

```sql
{{ ref('stg_orders') }}
-- → "database"."schema"."stg_orders"

-- Avec project (packages)
{{ ref('dbt_utils', 'date_spine') }}
```

### source()

Référence une source.

```sql
{{ source('shopify', 'orders') }}
-- → "raw_database"."shopify"."orders"
```

### config()

Configure le model.

```sql
{{ config(
    materialized='table',
    schema='marts',
    tags=['daily']
) }}
```

### var()

Accède aux variables.

```sql
{{ var('start_date') }}
{{ var('optional', 'default_value') }}
```

### env_var()

Accède aux variables d'environnement.

```sql
{{ env_var('DB_PASSWORD') }}
{{ env_var('OPTIONAL_VAR', 'default') }}
```

### is_incremental()

Vérifie si c'est un run incrémental.

```sql
{% if is_incremental() %}
    WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

### this

Référence le model actuel.

```sql
{{ this }}           -- Référence complète
{{ this.database }}  -- Nom de la database
{{ this.schema }}    -- Nom du schema
{{ this.name }}      -- Nom du model
{{ this.identifier }}-- Nom de la table
```

### target

Informations sur l'environnement cible.

```sql
{{ target.name }}      -- 'dev', 'prod'
{{ target.database }}
{{ target.schema }}
{{ target.type }}      -- 'snowflake', 'bigquery'
```

### run_query()

Exécute une requête et récupère le résultat.

```sql
{% set results = run_query("SELECT DISTINCT status FROM orders") %}

{% if execute %}
    {% set status_list = results.columns[0].values() %}
{% endif %}

SELECT
{% for status in status_list %}
    SUM(CASE WHEN status = '{{ status }}' THEN 1 ELSE 0 END) AS {{ status }}_count
    {% if not loop.last %},{% endif %}
{% endfor %}
FROM {{ ref('stg_orders') }}
```

### log()

Affiche un message dans les logs.

```sql
{{ log("Processing model: " ~ this.name, info=true) }}
```

---

## Résumé

### Syntaxe rapide

| Syntaxe | Usage |
|---------|-------|
| `{{ }}` | Expression (valeur) |
| `{% %}` | Statement (logique) |
| `{# #}` | Commentaire |
| `{% set x = y %}` | Variable |
| `{% if %}...{% endif %}` | Condition |
| `{% for %}...{% endfor %}` | Boucle |
| `{{ x \| filter }}` | Filtre |

### Fonctions clés

| Fonction | Usage |
|----------|-------|
| `ref()` | Référencer un model |
| `source()` | Référencer une source |
| `config()` | Configurer le model |
| `var()` | Variable de projet |
| `env_var()` | Variable d'environnement |
| `this` | Model actuel |
| `target` | Environnement cible |

---

## Prochaines étapes

→ [Macros personnalisées](./02-macros-personnalisees.md)


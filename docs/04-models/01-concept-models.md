# Concept des Models dans DBT

## 📋 Table des matières
1. [Qu'est-ce qu'un model ?](#quest-ce-quun-model-)
2. [Anatomie d'un model](#anatomie-dun-model)
3. [La fonction ref()](#la-fonction-ref)
4. [La fonction source()](#la-fonction-source)
5. [Configuration des models](#configuration-des-models)
6. [Exécution des models](#exécution-des-models)

---

## Qu'est-ce qu'un model ?

### Définition

Un **model** dans DBT est un fichier SQL contenant une instruction `SELECT` qui définit une transformation de données.

```
┌─────────────────────────────────────────────────────────────────────┐
│                      CONCEPT DE MODEL                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Fichier .sql                        Objet dans le Warehouse       │
│                                                                     │
│   ┌─────────────────┐                ┌─────────────────────────┐    │
│   │ stg_orders.sql  │   dbt run      │  Table ou View          │    │
│   │                 │ ─────────────> │  "stg_orders"           │    │
│   │ SELECT ...      │                │                         │    │
│   │ FROM ...        │                │  Résultat du SELECT     │    │
│   └─────────────────┘                └─────────────────────────┘    │
│                                                                     │
│   Un fichier = Un model = Une table ou view                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Ce qu'un model est

| Caractéristique          | Description                                  |
|--------------------------|----------------------------------------------|
| **Fichier SQL**          | Un fichier `.sql` dans le dossier `models/`  |
| **Une seule query**      | Une instruction SELECT (pas de CREATE TABLE) |
| **Nommé par le fichier** | `orders.sql` → table/vue `orders`            |
| **Transformable**        | Utilise Jinja pour la logique dynamique      |

### Ce qu'un model n'est PAS

```sql
-- ❌ PAS de DDL
CREATE TABLE orders AS ...

-- ❌ PAS de DML
INSERT INTO orders ...
UPDATE orders SET ...
DELETE FROM orders ...

-- ❌ PAS de procédures
BEGIN
    ...
END;
```

### Exemple simple

```sql
-- models/staging/stg_orders.sql

SELECT
    id AS order_id,
    user_id AS customer_id,
    amount,
    status,
    created_at AS ordered_at
FROM raw.orders
WHERE status != 'cancelled'
```

**DBT compile et exécute :**

```sql
-- Ce que DBT génère réellement
CREATE VIEW analytics.stg_orders AS (
    SELECT
        id AS order_id,
        user_id AS customer_id,
        amount,
        status,
        created_at AS ordered_at
    FROM raw.orders
    WHERE status != 'cancelled'
);
```

---

## Anatomie d'un model

### Structure d'un fichier model

```sql
-- models/marts/fct_orders.sql

-- ═══════════════════════════════════════════════════════════════════
-- BLOC CONFIG (optionnel)
-- ═══════════════════════════════════════════════════════════════════
{{
    config(
        materialized='table',
        schema='marts',
        tags=['daily', 'core']
    )
}}

-- ═══════════════════════════════════════════════════════════════════
-- DOCUMENTATION EN COMMENTAIRE (optionnel mais recommandé)
-- ═══════════════════════════════════════════════════════════════════
/*
    Modèle: fct_orders
    Description: Table de faits des commandes validées
    Grain: Une ligne par commande
    Fréquence: Daily
*/

-- ═══════════════════════════════════════════════════════════════════
-- CTEs (Common Table Expressions)
-- ═══════════════════════════════════════════════════════════════════
WITH orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

-- ═══════════════════════════════════════════════════════════════════
-- LOGIQUE DE TRANSFORMATION
-- ═══════════════════════════════════════════════════════════════════
enriched_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        c.customer_name,
        o.amount,
        o.ordered_at
    FROM orders o
    LEFT JOIN customers c
        ON o.customer_id = c.customer_id
)

-- ═══════════════════════════════════════════════════════════════════
-- SELECT FINAL
-- ═══════════════════════════════════════════════════════════════════
SELECT * FROM enriched_orders
```

### Bonnes pratiques CTEs

```sql
-- ✅ BON : CTEs nommées clairement
WITH source_orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

filtered_orders AS (
    SELECT * FROM source_orders
    WHERE status = 'completed'
),

final AS (
    SELECT
        order_id,
        customer_id,
        amount
    FROM filtered_orders
)

SELECT * FROM final

-- ❌ ÉVITER : Sous-requêtes imbriquées
SELECT *
FROM (
    SELECT *
    FROM (
        SELECT * FROM {{ ref('stg_orders') }}
    ) subquery1
    WHERE status = 'completed'
) subquery2
```

---

## La fonction ref()

### Syntaxe

```jinja
{{ ref('model_name') }}
```

### Rôle

La fonction `ref()` crée une **dépendance** entre les models et génère le nom qualifié de la table.

```sql
-- Ce que vous écrivez
SELECT * FROM {{ ref('stg_orders') }}

-- Ce que DBT compile (exemple Snowflake)
SELECT * FROM "ANALYTICS"."STAGING"."stg_orders"
```

### Construction du DAG

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DAG AUTOMATIQUE                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   stg_orders.sql                       fct_orders.sql               │
│   ┌─────────────────┐                 ┌─────────────────┐           │
│   │ SELECT *        │                 │ SELECT *        │           │
│   │ FROM source()   │─────────────────│ FROM ref(       │           │
│   │                 │   ref() crée    │   'stg_orders'  │           │
│   └─────────────────┘   la dépendance │ )               │           │
│          │                            └─────────────────┘           │
│          │                                    │                     │
│          ▼                                    ▼                     │
│   Exécuté EN PREMIER            Exécuté APRÈS stg_orders            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Avantages de ref()

| Avantage             | Description                                    |
|----------------------|------------------------------------------------|
| **Dépendances auto** | DBT sait quel model exécuter en premier        |
| **Noms qualifiés**   | Génère `database.schema.table` automatiquement |
| **Environnements**   | Même code, différents schémas (dev/prod)       |
| **Refactoring**      | Renommer un model = une seule modification     |

### Exemples

```sql
-- Référence simple
SELECT * FROM {{ ref('stg_customers') }}

-- Jointure entre models
SELECT
    o.*,
    c.customer_name
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('stg_customers') }} c
    ON o.customer_id = c.customer_id

-- Référence à un model d'un autre projet (packages)
SELECT * FROM {{ ref('dbt_utils', 'date_spine') }}
```

---

## La fonction source()

### Syntaxe

```jinja
{{ source('source_name', 'table_name') }}
```

### Définition des sources

```yaml
# models/staging/_sources.yml

sources:
  - name: raw_data
    database: raw_database
    schema: raw_schema
    tables:
      - name: orders
      - name: customers
      - name: products
```

### Utilisation

```sql
-- models/staging/stg_orders.sql

SELECT
    id AS order_id,
    customer_id,
    amount
FROM {{ source('raw_data', 'orders') }}
```

### Compilation

```sql
-- Compilé en
SELECT
    id AS order_id,
    customer_id,
    amount
FROM "raw_database"."raw_schema"."orders"
```

### source() vs ref()

| Fonction   | Usage                             | Cible      |
|------------|-----------------------------------|------------|
| `source()` | Données brutes (externes à DBT)   | Tables raw |
| `ref()`    | Données transformées (models DBT) | Models DBT |

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   SOURCES (externes)              MODELS DBT                        │
│                                                                     │
│   ┌──────────────┐               ┌──────────────┐                   │
│   │ raw.orders   │──source()───> │ stg_orders   │                   │
│   └──────────────┘               └──────┬───────┘                   │
│                                         │                           │
│   ┌──────────────┐               ┌──────▼───────┐                   │
│   │raw.customers │──source()───> │stg_customers │                   │
│   └──────────────┘               └──────┬───────┘                   │
│                                         │                           │
│                                   ┌─────▼────────┐                  │
│                                   │  fct_orders  │◄──ref()          │
│                                   └──────────────┘                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Configuration des models

### Méthode 1 : Bloc config()

```sql
-- Dans le fichier .sql
{{
    config(
        materialized='table',
        schema='marts',
        alias='orders_fact',
        tags=['daily'],
        persist_docs={'relation': true, 'columns': true}
    )
}}

SELECT ...
```

### Méthode 2 : Fichier YAML

```yaml
# schema.yml
models:
  - name: fct_orders
    config:
      materialized: table
      schema: marts
      tags: ['daily']
```

### Méthode 3 : dbt_project.yml

```yaml
# dbt_project.yml
models:
  my_project:
    marts:
      +materialized: table
      +schema: marts
```

### Priorité des configurations

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PRIORITÉ (croissante)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. dbt_project.yml (niveau projet)      ─── Moins prioritaire      │
│  2. dbt_project.yml (niveau dossier)                                │
│  3. Fichier schema.yml                                              │
│  4. Bloc config() dans le model          ─── Plus prioritaire       │
│                                                                     │
│  La configuration la plus spécifique l'emporte toujours.            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Options de configuration courantes

| Option         | Description | Valeurs |
|----------------|----------------------------|---------------------------------------------|
| `materialized` | Type de matérialisation    | `view`, `table`, `incremental`, `ephemeral` |
| `schema`       | Schéma cible               | String                                      |
| `alias`        | Nom de la table (override) | String                                      |
| `database`     | Base de données cible      | String                                      |
| `tags`         | Tags pour sélection        | Liste                                       |
| `enabled`      | Activer/désactiver         | Boolean                                     |
| `persist_docs` | Persister la documentation | Object                                      |

---

## Exécution des models

### Commandes de base

```bash
# Exécuter tous les models
dbt run

# Exécuter un model spécifique
dbt run --select fct_orders

# Exécuter avec dépendances amont
dbt run --select +fct_orders

# Exécuter avec dépendants aval
dbt run --select stg_orders+

# Exécuter la chaîne complète
dbt run --select +fct_orders+
```

### Sélecteurs avancés

```bash
# Par tag
dbt run --select tag:daily

# Par dossier
dbt run --select staging.*

# Par matérialisation
dbt run --select config.materialized:table

# Exclure des models
dbt run --exclude stg_legacy_*

# Combinaisons
dbt run --select tag:daily --exclude fct_debug
```

### Cycle d'exécution

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CYCLE D'EXÉCUTION                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. PARSING        Lecture des fichiers .sql et .yml                │
│         │                                                           │
│         ▼                                                           │
│  2. RESOLUTION     Construction du DAG (dépendances)                │
│         │                                                           │
│         ▼                                                           │
│  3. COMPILATION    Jinja → SQL pur                                  │
│         │          ref() → "schema"."table"                         │
│         ▼                                                           │
│  4. EXECUTION      Envoi du SQL au warehouse                        │
│         │          Ordre respecté selon le DAG                      │
│         ▼                                                           │
│  5. LOGGING        Résultats enregistrés                            │
│                    target/run_results.json                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Visualiser le SQL compilé

```bash
# Compiler sans exécuter
dbt compile

# Le SQL compilé est dans target/compiled/
cat target/compiled/my_project/models/fct_orders.sql
```

---

## Résumé

| Concept      | Description                          |
|--------------|--------------------------------------|
| **Model**    | Fichier .sql avec un SELECT          |
| **ref()**    | Référence un autre model DBT         |
| **source()** | Référence une table brute externe    |
| **DAG**      | Graphe de dépendances auto-construit |
| **config()** | Configuration du model               |

### Règles clés

1. Un fichier `.sql` = un model = une table/vue
2. Utiliser `ref()` pour les models DBT
3. Utiliser `source()` pour les données brutes
4. Ne jamais écrire de DDL (CREATE, DROP)
5. Structurer avec des CTEs

---

## Prochaines étapes

→ [Types de models (staging, intermediate, marts)](./02-types-models-staging-intermediate-marts.md)


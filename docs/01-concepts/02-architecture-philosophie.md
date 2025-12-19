# Architecture et Philosophie de DBT

## 📋 Table des matières
1. [Philosophie fondamentale](#philosophie-fondamentale)
2. [Architecture technique](#architecture-technique)
3. [Le DAG (Directed Acyclic Graph)](#le-dag-directed-acyclic-graph)
4. [Principes de conception](#principes-de-conception)
5. [Cycle de vie d'une exécution](#cycle-de-vie-dune-exécution)

---

## Philosophie fondamentale

### Les 4 piliers de DBT

```
                    ┌──────────────────────────────────────────┐
                    │        PHILOSOPHIE DBT                   │
                    ├──────────────────────────────────────────┤
                    │                                          │
                    │   1. SQL comme langage de transformation │
                    │   2. Versioning avec Git                 │
                    │   3. Qualité via les tests               │
                    │   4. Documentation comme code            │
                    │                                          │
                    └──────────────────────────────────────────┘
```

### 1. SQL comme langage universel

DBT part du principe que **SQL est le langage que tout le monde connaît** dans la data. Plutôt que d'inventer un nouveau langage ou d'utiliser Python pour les transformations, DBT capitalise sur SQL.

```sql
-- Un model DBT est simplement un SELECT
-- Pas besoin de CREATE TABLE, DBT s'en charge
SELECT
    customer_id,
    first_name,
    last_name,
    email
FROM {{ ref('stg_customers') }}
WHERE is_active = true
```

**Avantages :**
- Courbe d'apprentissage faible
- Lisible par les analystes métier
- Exécuté nativement dans le warehouse (performance)

### 2. Versioning avec Git

Chaque projet DBT est un **repository Git**. Cela signifie :

```bash
# Historique des changements
git log --oneline

# Branches pour les features
git checkout -b feature/new-customer-model

# Pull requests pour la review
# CI/CD automatisé
```

**Bénéfices :**
- Traçabilité des modifications
- Collaboration d'équipe
- Rollback possible
- Code review

### 3. Qualité via les tests

DBT intègre les tests comme **citoyens de première classe** :

```yaml
# Les tests sont définis à côté des modèles
models:
  - name: orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: amount
        tests:
          - not_null
          - positive_values  # Test custom
```

### 4. Documentation comme code

La documentation vit **avec le code** :

```yaml
# schema.yml
models:
  - name: dim_customers
    description: "Table de dimension des clients actifs"
    columns:
      - name: customer_id
        description: "Identifiant unique du client"
      - name: lifetime_value
        description: "Valeur totale des commandes du client"
```

---

## Architecture technique

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────┐
│                         ARCHITECTURE DBT                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐     ┌──────────────┐     ┌─────────────────────┐   │
│  │   Fichiers  │     │   Compileur  │     │    Data Warehouse   │   │
│  │    .sql     │────>│    Jinja     │────>│                     │   │
│  │    .yml     │     │      +       │     │  ┌──────────────┐   │   │
│  │             │     │    Parser    │     │  │  Exécuteur   │   │   │
│  └─────────────┘     └──────────────┘     │  │     SQL      │   │   │
│                                           │  └──────────────┘   │   │
│        ▲                   │              │         │           │   │
│        │                   ▼              │         ▼           │   │
│  ┌─────────────┐     ┌──────────────┐     │  ┌──────────────┐   │   │
│  │ dbt_project │     │   Manifest   │     │  │    Tables    │   │   │
│  │    .yml     │     │    .json     │     │  │    Views     │   │   │
│  └─────────────┘     └──────────────┘     │  └──────────────┘   │   │
│                                           │                     │   │
│                                           └─────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Composants clés

| Composant | Rôle |
|-----------|------|
| **Parser YAML** | Lit les configurations et métadonnées |
| **Compileur Jinja** | Transforme le SQL+Jinja en SQL pur |
| **Résolveur de dépendances** | Construit le DAG |
| **Exécuteur** | Envoie le SQL au warehouse |
| **Adaptateur** | Interface avec chaque type de warehouse |

### Les adaptateurs (Adapters)

DBT utilise un système d'**adaptateurs** pour supporter différents warehouses :

```python
# Chaque adapter implémente une interface commune
class SnowflakeAdapter:
    def execute(self, sql):
        # Logique spécifique Snowflake
        
class BigQueryAdapter:
    def execute(self, sql):
        # Logique spécifique BigQuery
```

**Adapters officiels :**
- `dbt-snowflake`
- `dbt-bigquery`
- `dbt-redshift`
- `dbt-postgres`
- `dbt-databricks`
- `dbt-spark`

---

## Le DAG (Directed Acyclic Graph)

### Concept

Le DAG est le **cœur de DBT**. C'est un graphe qui représente les dépendances entre les modèles.

```
                    ┌─────────────────────────────────────────┐
                    │              DAG EXEMPLE                │
                    └─────────────────────────────────────────┘
                    
    Sources                 Staging              Marts
    
┌─────────────┐        ┌─────────────┐     ┌─────────────────┐
│  raw.orders │───────>│ stg_orders  │────>│                 │
└─────────────┘        └─────────────┘     │                 │
                              │            │   fct_orders    │
                              ▼            │                 │
┌─────────────┐        ┌─────────────┐     │                 │
│raw.customers│───────>│stg_customers│────>│                 │
└─────────────┘        └─────────────┘     └────────┬────────┘
                              │                     │
                              │                     ▼
                              │            ┌─────────────────┐
                              └───────────>│  dim_customers  │
                                           └─────────────────┘
```

### Construction du DAG

Le DAG est construit automatiquement via les fonctions `ref()` et `source()` :

```sql
-- models/marts/fct_orders.sql
SELECT
    o.order_id,
    o.customer_id,
    c.customer_name,
    o.amount
FROM {{ ref('stg_orders') }} o          -- Dépendance 1
LEFT JOIN {{ ref('stg_customers') }} c  -- Dépendance 2
    ON o.customer_id = c.customer_id
```

**DBT analyse ce code et comprend :**
- `fct_orders` dépend de `stg_orders`
- `fct_orders` dépend de `stg_customers`
- `stg_orders` et `stg_customers` peuvent s'exécuter en parallèle

### Caractéristiques du DAG

| Propriété | Signification |
|-----------|---------------|
| **Directed** | Les arêtes ont une direction (A → B) |
| **Acyclic** | Pas de cycles (A → B → A interdit) |
| **Graph** | Structure de nœuds et arêtes |

### Exécution basée sur le DAG

```bash
# Exécuter tout le DAG
dbt run

# Exécuter un modèle et ses dépendances amont
dbt run --select +fct_orders

# Exécuter un modèle et ses dépendants aval
dbt run --select stg_customers+

# Exécuter toute la chaîne
dbt run --select +fct_orders+
```

---

## Principes de conception

### 1. Convention over Configuration

DBT favorise les **conventions** pour réduire la configuration :

```
# Convention : le nom du fichier = nom du modèle
models/
  staging/
    stg_customers.sql  --> Crée une table/vue nommée "stg_customers"
```

### 2. DRY (Don't Repeat Yourself)

Via les **macros** et **références** :

```sql
-- Macro réutilisable
{% macro cents_to_dollars(column_name) %}
    ({{ column_name }} / 100)::numeric(10,2)
{% endmacro %}

-- Utilisation
SELECT
    {{ cents_to_dollars('amount_cents') }} AS amount_dollars
FROM {{ ref('raw_payments') }}
```

### 3. Separation of Concerns

Structure recommandée en **couches** :

```
models/
├── staging/        # Nettoyage et typage
├── intermediate/   # Logique métier complexe
└── marts/          # Tables finales pour les utilisateurs
```

### 4. Idempotence

Chaque exécution DBT doit produire le **même résultat** :

```sql
-- DBT génère du SQL idempotent
CREATE OR REPLACE TABLE my_model AS (
    SELECT ...
)

-- Pas de INSERT INTO qui accumule
```

---

## Cycle de vie d'une exécution

### Étapes détaillées

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CYCLE D'EXÉCUTION DBT                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. PARSING                                                         │
│     └── Lecture des fichiers .sql et .yml                           │
│                                                                     │
│  2. RÉSOLUTION DES DÉPENDANCES                                      │
│     └── Construction du DAG                                         │
│                                                                     │
│  3. COMPILATION                                                     │
│     └── Jinja → SQL pur                                             │
│     └── ref('model') → "schema"."model"                             │
│                                                                     │
│  4. EXÉCUTION                                                       │
│     └── Envoi du SQL au warehouse                                   │
│     └── Respect de l'ordre du DAG                                   │
│     └── Parallélisation possible                                    │
│                                                                     │
│  5. LOGGING                                                         │
│     └── Enregistrement des résultats                                │
│     └── Temps d'exécution                                           │
│     └── Statut (success/error)                                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Fichiers générés

```
target/
├── compiled/           # SQL compilé (lisible)
│   └── models/
│       └── stg_customers.sql
├── run/                # SQL exécuté (avec CREATE TABLE)
│   └── models/
│       └── stg_customers.sql
├── manifest.json       # Métadonnées complètes du projet
├── run_results.json    # Résultats de la dernière exécution
└── graph.gpickle       # DAG sérialisé
```

### Le manifest.json

Fichier central contenant :
- Liste de tous les modèles
- Dépendances
- Tests
- Sources
- Documentation

```json
{
  "nodes": {
    "model.my_project.stg_customers": {
      "name": "stg_customers",
      "depends_on": ["source.my_project.raw.customers"],
      "columns": {...},
      "config": {...}
    }
  }
}
```

---

## Résumé

| Concept | Description |
|---------|-------------|
| **Philosophie** | SQL + Git + Tests + Docs |
| **Architecture** | Compilation Jinja → Exécution SQL |
| **DAG** | Graphe des dépendances auto-construit |
| **Idempotence** | Résultat identique à chaque run |
| **Adapters** | Support multi-warehouse |

---

## Prochaines étapes

→ [Paradigme ELT vs ETL](./03-paradigme-elt-vs-etl.md)


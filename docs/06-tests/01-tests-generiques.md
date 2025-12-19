# Tests Génériques dans DBT

## 📋 Table des matières
1. [Concept de tests](#concept-de-tests)
2. [Les 4 tests génériques natifs](#les-4-tests-génériques-natifs)
3. [Configuration des tests](#configuration-des-tests)
4. [Tests avec packages](#tests-avec-packages)
5. [Exécution des tests](#exécution-des-tests)

---

## Concept de tests

### Qu'est-ce qu'un test DBT ?

Un **test** dans DBT est une assertion sur vos données. Si le test retourne des lignes, il échoue.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LOGIQUE DES TESTS DBT                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Test = requête SQL                                                 │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  SELECT * FROM my_table WHERE condition_invalide            │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                         │                                           │
│                         ▼                                           │
│          ┌──────────────┴──────────────┐                            │
│          │                             │                            │
│    0 lignes retournées          > 0 lignes retournées               │
│          │                             │                            │
│          ▼                             ▼                            │
│       ✅ PASS                       ❌ FAIL                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Types de tests

| Type           | Description             | Définition                  |
|----------------|-------------------------|-----------------------------|
| **Génériques** | Tests réutilisables     | Dans fichiers YAML          |
| **Singuliers** | Tests SQL personnalisés | Fichiers .sql dans `tests/` |

---

## Les 4 tests génériques natifs

### 1. unique

Vérifie qu'une colonne n'a pas de doublons.

```yaml
models:
  - name: dim_customers
    columns:
      - name: customer_id
        tests:
          - unique
```

**SQL généré :**
```sql
SELECT customer_id
FROM analytics.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1
```

### 2. not_null

Vérifie qu'une colonne n'a pas de valeurs NULL.

```yaml
models:
  - name: fct_orders
    columns:
      - name: order_id
        tests:
          - not_null
```

**SQL généré :**
```sql
SELECT order_id
FROM analytics.fct_orders
WHERE order_id IS NULL
```

### 3. accepted_values

Vérifie qu'une colonne contient uniquement des valeurs autorisées.

```yaml
models:
  - name: fct_orders
    columns:
      - name: status
        tests:
          - accepted_values:
              values: ['pending', 'shipped', 'delivered', 'cancelled']
```

**SQL généré :**
```sql
SELECT status
FROM analytics.fct_orders
WHERE status NOT IN ('pending', 'shipped', 'delivered', 'cancelled')
  AND status IS NOT NULL
```

### 4. relationships

Vérifie l'intégrité référentielle (clé étrangère).

```yaml
models:
  - name: fct_orders
    columns:
      - name: customer_id
        tests:
          - relationships:
              to: ref('dim_customers')
              field: customer_id
```

**SQL généré :**
```sql
SELECT customer_id
FROM analytics.fct_orders
WHERE customer_id IS NOT NULL
  AND customer_id NOT IN (
    SELECT customer_id 
    FROM analytics.dim_customers
  )
```

### Tableau récapitulatif

| Test              | Vérifie                 | Paramètres    |
|-------------------|-------------------------|---------------|
| `unique`          | Pas de doublons         | -             |
| `not_null`        | Pas de NULL             | -             |
| `accepted_values` | Valeurs dans une liste  | `values`      |
| `relationships`   | Intégrité référentielle | `to`, `field` |

---

## Configuration des tests

### Syntaxe de base

```yaml
version: 2

models:
  - name: fct_orders
    description: "Table de faits des commandes"
    
    columns:
      - name: order_id
        description: "ID unique de la commande"
        tests:
          - unique
          - not_null
          
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
              
      - name: status
        tests:
          - accepted_values:
              values: ['pending', 'shipped', 'delivered']
```

### Configuration avancée

```yaml
columns:
  - name: order_id
    tests:
      - unique:
          # Nom personnalisé du test
          name: orders_unique_order_id
          
          # Sévérité
          severity: error  # ou warn
          
          # Tags
          tags: ['critical', 'daily']
          
          # Activer/désactiver
          enabled: true
          
          # Stocker les échecs
          store_failures: true
          
          # Limite d'échecs avant arrêt
          limit: 100
          
          # Condition WHERE
          where: "order_date >= '2024-01-01'"
```

### Sévérité (severity)

```yaml
columns:
  - name: email
    tests:
      # Erreur bloquante
      - unique:
          severity: error
      
      # Avertissement (n'échoue pas le pipeline)
      - not_null:
          severity: warn
```

| Sévérité | Comportement       | Exit code |
|----------|--------------------|-----------|
| `error`  | Bloque le pipeline | 1         |
| `warn`   | Avertit uniquement | 0         |

### Threshold (seuil)

```yaml
columns:
  - name: email
    tests:
      - not_null:
          # Tolérer jusqu'à 10 NULL
          error_if: ">10"
          warn_if: ">5"
```

### Condition WHERE

```yaml
columns:
  - name: customer_id
    tests:
      - not_null:
          # Tester uniquement les commandes actives
          where: "status = 'active'"
```

### Store failures

```yaml
# dbt_project.yml
tests:
  my_project:
    +store_failures: true
    +schema: test_failures
```

Les lignes en échec sont stockées dans une table pour analyse.

---

## Tests avec packages

### dbt_utils

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.1.1
```

```bash
dbt deps
```

#### Tests dbt_utils courants

```yaml
columns:
  - name: customer_id
    tests:
      # Expression régulière
      - dbt_utils.not_constant
      
      # Valeur dans une plage
      - dbt_utils.accepted_range:
          min_value: 0
          max_value: 1000000
          inclusive: true
          
      # Longueur de chaîne
      - dbt_utils.not_empty_string
      
  - name: email
    tests:
      # Expression régulière
      - dbt_utils.expression_is_true:
          expression: "email LIKE '%@%.%'"
          
  - name: created_at
    tests:
      # Données récentes
      - dbt_utils.recency:
          datepart: day
          field: created_at
          interval: 1
```

#### Tests au niveau table

```yaml
models:
  - name: fct_orders
    tests:
      # Combinaison unique
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - order_id
            - line_item_id
      
      # Égalité entre tables
      - dbt_utils.equality:
          compare_model: ref('fct_orders_legacy')
          compare_columns:
            - order_id
            - amount
      
      # Au moins une ligne
      - dbt_utils.at_least_one:
          column_name: order_id
```

### dbt_expectations

```yaml
# packages.yml
packages:
  - package: calogica/dbt_expectations
    version: 0.10.1
```

```yaml
columns:
  - name: email
    tests:
      - dbt_expectations.expect_column_values_to_match_regex:
          regex: '^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
          
  - name: amount
    tests:
      - dbt_expectations.expect_column_values_to_be_between:
          min_value: 0
          max_value: 10000
          
  - name: status
    tests:
      - dbt_expectations.expect_column_distinct_count_to_equal:
          value: 4
```

---

## Exécution des tests

### Commandes de base

```bash
# Exécuter tous les tests
dbt test

# Tester un model spécifique
dbt test --select fct_orders

# Tester avec dépendances
dbt test --select +fct_orders

# Par tag
dbt test --select tag:critical

# Par type
dbt test --select test_type:generic
dbt test --select test_type:singular
```

### Combinaison avec run

```bash
# Build = run + test
dbt build

# Build un model spécifique
dbt build --select fct_orders

# Workflow complet
dbt run && dbt test
```

### Sortie des tests

```
Running tests...

test unique_fct_orders_order_id ............................ [PASS]
test not_null_fct_orders_order_id .......................... [PASS]
test relationships_fct_orders_customer_id .................. [PASS]
test accepted_values_fct_orders_status ..................... [FAIL]

Failure in test accepted_values_fct_orders_status:
  Got 5 results, configured to fail if != 0
  
  compiled SQL at target/compiled/.../accepted_values_...sql

Completed with 1 error and 0 warnings:
```

### Analyser les échecs

```bash
# Voir le SQL compilé
cat target/compiled/my_project/models/schema.yml/accepted_values_fct_orders_status.sql

# Voir les résultats
cat target/run_results.json
```

```sql
-- SQL pour reproduire manuellement
SELECT status
FROM analytics.fct_orders
WHERE status NOT IN ('pending', 'shipped', 'delivered', 'cancelled')
```

---

## Résumé

### Les 4 tests natifs

| Test              | Usage           | Exemple          |
|-------------------|-----------------|------------------|
| `unique`          | Clé primaire    | `customer_id`    |
| `not_null`        | Champs requis   | `order_id`       |
| `accepted_values` | Énumérations    | `status`         |
| `relationships`   | Clés étrangères | `FK → dim_table` |

### Packages recommandés

| Package            | Tests populaires                                  |
|--------------------|---------------------------------------------------|
| `dbt_utils`        | `unique_combination`, `recency`, `accepted_range` |
| `dbt_expectations` | `regex`, `between`, `row_count`                   |

### Checklist tests

- [ ] `unique` + `not_null` sur toutes les PK
- [ ] `relationships` sur toutes les FK
- [ ] `accepted_values` sur les colonnes enum
- [ ] Tests de fraîcheur (recency)
- [ ] Sévérité adaptée (`error` vs `warn`)

---

## Prochaines étapes

→ [Tests singuliers](./02-tests-singuliers.md)


# Unit Tests dans DBT (v1.8+)

## 📋 Table des matières
1. [Introduction aux Unit Tests](#introduction-aux-unit-tests)
2. [Structure d'un Unit Test](#structure-dun-unit-test)
3. [Définir les données de test](#définir-les-données-de-test)
4. [Exemples pratiques](#exemples-pratiques)
5. [Bonnes pratiques](#bonnes-pratiques)

---

## Introduction aux Unit Tests

### Qu'est-ce qu'un Unit Test DBT ?

Les **Unit Tests** sont une fonctionnalité introduite dans **DBT 1.8** qui permet de tester la logique de transformation de vos modèles de manière isolée, sans dépendre des données réelles du warehouse.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    UNIT TESTS vs DATA TESTS                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  DATA TESTS (tests existants)         UNIT TESTS (nouveauté 1.8)    │
│ ┌──────────────────────────────┐    ┌─────────────────────────────┐ │
│ │ • Testent les DONNÉES        │    │ • Testent la LOGIQUE        │ │
│ │ • Après l'exécution (dbt run)│    │ • Avant l'exécution         │ │
│ │ • Dépendent du warehouse     │    │ • Indépendants des données  │ │
│ │ • Ex: unique, not_null       │    │ • Ex: calculs, conditions   │ │
│ └──────────────────────────────┘    └─────────────────────────────┘ │
│                                                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │                        WORKFLOW                                 │ │
│ │  given (input) → model (transformation) → expect (output)       │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Pourquoi utiliser les Unit Tests ?

| Avantage           | Description                                     |
|--------------------|-------------------------------------------------|
| **Rapidité**       | Pas besoin d'accéder au warehouse               |
| **Isolation**      | Test de la logique pure, pas des données        |
| **CI/CD**          | Exécution dans les pipelines sans credentials   |
| **Documentation**  | Les tests documentent le comportement attendu   |
| **Régression**     | Détection précoce des bugs lors des changements |

### Prérequis

```yaml
# dbt_project.yml
require-dbt-version: [">=1.8.0", "<2.0.0"]
```

---

## Structure d'un Unit Test

### Syntaxe de base

Les unit tests sont définis dans les fichiers YAML de vos modèles :

```yaml
# models/marts/_core__models.yml

unit_tests:
  - name: test_customer_revenue_calculation
    description: "Vérifie le calcul du revenu client"
    model: dim_customers
    
    # Données d'entrée simulées
    given:
      - input: ref('stg_orders')
        rows:
          - {order_id: 1, customer_id: 100, amount: 50.00}
          - {order_id: 2, customer_id: 100, amount: 30.00}
          - {order_id: 3, customer_id: 200, amount: 100.00}
    
    # Résultat attendu
    expect:
      rows:
        - {customer_id: 100, total_revenue: 80.00}
        - {customer_id: 200, total_revenue: 100.00}
```

### Composants d'un Unit Test

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ANATOMIE D'UN UNIT TEST                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  name: string              # Nom unique du test                     │
│  description: string       # Description du test                    │
│  model: string             # Modèle à tester                        │
│                                                                     │
│  given:                    # Données d'entrée (fixtures)            │
│    - input: ref/source     # Référence au modèle ou source          │
│      rows: [...]           # Lignes de données simulées             │
│                                                                     │
│  expect:                   # Résultat attendu                       │
│    rows: [...]             # Lignes attendues en sortie             │
│                                                                     │
│  overrides:                # Optionnel : variables, macros          │
│    vars: {...}                                                      │
│    macros: [...]                                                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Définir les données de test

### Format inline (simple)

```yaml
given:
  - input: ref('stg_products')
    rows:
      - {product_id: 1, name: "Widget", price: 19.99, is_active: true}
      - {product_id: 2, name: "Gadget", price: 29.99, is_active: false}
```

### Format explicite (lisible)

```yaml
given:
  - input: ref('stg_products')
    rows:
      - product_id: 1
        name: "Widget"
        price: 19.99
        is_active: true
      - product_id: 2
        name: "Gadget"
        price: 29.99
        is_active: false
```

### Format CSV (fichiers externes)

```yaml
given:
  - input: ref('stg_orders')
    format: csv
    fixture: orders_test_data  # Référence à tests/fixtures/orders_test_data.csv
```

```csv
# tests/fixtures/orders_test_data.csv
order_id,customer_id,amount,status
1,100,50.00,completed
2,100,30.00,completed
3,200,100.00,pending
```

### Tester avec des sources

```yaml
given:
  - input: source('ecommerce', 'raw_customers')
    rows:
      - {id: 1, first_name: "Alice", last_name: "Smith"}
```

### Valeurs spéciales

```yaml
given:
  - input: ref('stg_orders')
    rows:
      # NULL values
      - {order_id: 1, shipped_at: null}
      
      # Dates
      - {order_id: 2, created_at: "2024-01-15"}
      
      # Timestamps
      - {order_id: 3, created_at: "2024-01-15T10:30:00"}
      
      # Boolean
      - {order_id: 4, is_active: true}
```

---

## Exemples pratiques

### Exemple 1 : Tester un calcul simple

```sql
-- models/marts/fct_orders.sql
SELECT
    order_id,
    quantity,
    unit_price,
    quantity * unit_price AS total_amount
FROM {{ ref('stg_orders') }}
```

```yaml
unit_tests:
  - name: test_total_amount_calculation
    description: "Vérifie le calcul du montant total"
    model: fct_orders
    
    given:
      - input: ref('stg_orders')
        rows:
          - {order_id: 1, quantity: 2, unit_price: 10.00}
          - {order_id: 2, quantity: 5, unit_price: 3.50}
    
    expect:
      rows:
        - {order_id: 1, quantity: 2, unit_price: 10.00, total_amount: 20.00}
        - {order_id: 2, quantity: 5, unit_price: 3.50, total_amount: 17.50}
```

### Exemple 2 : Tester une logique conditionnelle

```sql
-- models/marts/dim_customers.sql
SELECT
    customer_id,
    total_orders,
    CASE 
        WHEN total_orders >= 10 THEN 'VIP'
        WHEN total_orders >= 5 THEN 'Regular'
        ELSE 'New'
    END AS customer_tier
FROM {{ ref('int_customer_orders') }}
```

```yaml
unit_tests:
  - name: test_customer_tier_vip
    description: "Vérifie qu'un client avec 10+ commandes est VIP"
    model: dim_customers
    given:
      - input: ref('int_customer_orders')
        rows:
          - {customer_id: 1, total_orders: 15}
    expect:
      rows:
        - {customer_id: 1, total_orders: 15, customer_tier: "VIP"}

  - name: test_customer_tier_regular
    description: "Vérifie qu'un client avec 5-9 commandes est Regular"
    model: dim_customers
    given:
      - input: ref('int_customer_orders')
        rows:
          - {customer_id: 2, total_orders: 7}
    expect:
      rows:
        - {customer_id: 2, total_orders: 7, customer_tier: "Regular"}

  - name: test_customer_tier_new
    description: "Vérifie qu'un client avec <5 commandes est New"
    model: dim_customers
    given:
      - input: ref('int_customer_orders')
        rows:
          - {customer_id: 3, total_orders: 2}
    expect:
      rows:
        - {customer_id: 3, total_orders: 2, customer_tier: "New"}
```

### Exemple 3 : Tester une jointure

```sql
-- models/marts/fct_orders.sql
SELECT
    o.order_id,
    o.customer_id,
    c.customer_name,
    o.amount
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('dim_customers') }} c 
    ON o.customer_id = c.customer_id
```

```yaml
unit_tests:
  - name: test_order_customer_join
    description: "Vérifie la jointure orders-customers"
    model: fct_orders
    
    given:
      - input: ref('stg_orders')
        rows:
          - {order_id: 1, customer_id: 100, amount: 50.00}
          - {order_id: 2, customer_id: 999, amount: 30.00}  # Client inexistant
      
      - input: ref('dim_customers')
        rows:
          - {customer_id: 100, customer_name: "Alice"}
    
    expect:
      rows:
        - {order_id: 1, customer_id: 100, customer_name: "Alice", amount: 50.00}
        - {order_id: 2, customer_id: 999, customer_name: null, amount: 30.00}
```

### Exemple 4 : Tester avec des variables

```sql
-- models/staging/stg_orders.sql
SELECT *
FROM {{ source('raw', 'orders') }}
{% if var('filter_test_orders', false) %}
WHERE is_test = false
{% endif %}
```

```yaml
unit_tests:
  - name: test_filter_test_orders_enabled
    description: "Vérifie le filtrage des commandes test"
    model: stg_orders
    
    overrides:
      vars:
        filter_test_orders: true
    
    given:
      - input: source('raw', 'orders')
        rows:
          - {order_id: 1, is_test: false}
          - {order_id: 2, is_test: true}
    
    expect:
      rows:
        - {order_id: 1, is_test: false}
```

### Exemple 5 : Tester les cas limites (edge cases)

```yaml
unit_tests:
  - name: test_division_by_zero_handling
    description: "Vérifie la gestion de la division par zéro"
    model: fct_metrics
    
    given:
      - input: ref('stg_sales')
        rows:
          - {id: 1, revenue: 100, orders: 0}  # Division par zéro potentielle
          - {id: 2, revenue: 200, orders: 4}
    
    expect:
      rows:
        - {id: 1, revenue: 100, orders: 0, avg_order_value: null}
        - {id: 2, revenue: 200, orders: 4, avg_order_value: 50.00}

  - name: test_null_handling
    description: "Vérifie la gestion des valeurs NULL"
    model: fct_metrics
    
    given:
      - input: ref('stg_sales')
        rows:
          - {id: 1, revenue: null, orders: 5}
    
    expect:
      rows:
        - {id: 1, revenue: null, orders: 5, avg_order_value: null}
```

---

## Exécution des Unit Tests

### Commandes

```bash
# Exécuter tous les unit tests
dbt test --select test_type:unit

# Exécuter les unit tests d'un modèle spécifique
dbt test --select dim_customers,test_type:unit

# Exécuter un test spécifique
dbt test --select test_customer_tier_vip

# Build complet (run + tous les tests)
dbt build
```

### Sortie

```
Running unit tests...

PASS test_total_amount_calculation ............................ [PASS]
PASS test_customer_tier_vip .................................. [PASS]
PASS test_customer_tier_regular .............................. [PASS]
FAIL test_order_customer_join ................................ [FAIL]

Failure in unit test test_order_customer_join:
  Expected:
    - {order_id: 1, customer_name: "Alice"}
  Actual:
    - {order_id: 1, customer_name: "alice"}  # lowercase!

Completed with 1 error
```

---

## Bonnes pratiques

### 1. Nommage des tests

```yaml
# ✅ Bon : Descriptif et spécifique
- name: test_vip_customer_has_10_plus_orders
- name: test_null_shipping_date_when_not_shipped
- name: test_revenue_calculation_with_discount

# ❌ Mauvais : Trop vague
- name: test_customers
- name: test_calculation
```

### 2. Un test = Un comportement

```yaml
# ✅ Bon : Tests séparés pour chaque cas
unit_tests:
  - name: test_tier_vip_boundary
    # Test spécifique pour la limite VIP
    
  - name: test_tier_regular_boundary
    # Test spécifique pour la limite Regular

# ❌ Mauvais : Tout mélangé
unit_tests:
  - name: test_all_tiers
    # Trop de cas dans un seul test
```

### 3. Tester les cas limites

```yaml
unit_tests:
  # Valeurs normales
  - name: test_normal_calculation
  
  # Cas limites
  - name: test_zero_quantity
  - name: test_negative_price
  - name: test_null_values
  - name: test_empty_string
  - name: test_boundary_values
```

### 4. Données minimales

```yaml
# ✅ Bon : Seulement les colonnes nécessaires
given:
  - input: ref('stg_orders')
    rows:
      - {order_id: 1, amount: 100}  # Seulement ce qui est utilisé

# ❌ Mauvais : Toutes les colonnes
given:
  - input: ref('stg_orders')
    rows:
      - {order_id: 1, customer_id: 1, product_id: 1, amount: 100, 
         status: "completed", created_at: "2024-01-01", ...}
```

### 5. Organisation des fichiers

```
models/
├── marts/
│   ├── core/
│   │   ├── dim_customers.sql
│   │   ├── fct_orders.sql
│   │   └── _core__models.yml      # Contient les unit_tests
│   │
│   └── _marts__unit_tests.yml     # Ou fichier dédié aux unit tests

tests/
└── fixtures/                       # Fichiers CSV pour les fixtures
    ├── orders_test_data.csv
    └── customers_test_data.csv
```

---

## Résumé

### Quand utiliser chaque type de test ?

| Type de test        | Quand l'utiliser                          |
|---------------------|-------------------------------------------|
| **Unit tests**      | Logique de transformation, calculs, CASE  |
| **Data tests**      | Intégrité des données (unique, not_null)  |
| **Singular tests**  | Règles métier complexes spécifiques       |

### Structure de base

```yaml
unit_tests:
  - name: test_descriptive_name
    description: "Ce que le test vérifie"
    model: my_model
    given:
      - input: ref('source_model')
        rows:
          - {col1: value1, col2: value2}
    expect:
      rows:
        - {col1: expected1, col2: expected2}
```

### Checklist

- [ ] Tests nommés de manière descriptive
- [ ] Un test par comportement
- [ ] Cas limites couverts (NULL, zéro, vide)
- [ ] Données de test minimales
- [ ] Tests organisés dans les fichiers YAML appropriés
- [ ] Tests intégrés au pipeline CI/CD

---

## Prochaines étapes

→ [Documentation des models](../07-documentation/01-documentation-models.md)


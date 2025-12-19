# Tests Singuliers dans DBT

## 📋 Table des matières
1. [Qu'est-ce qu'un test singulier ?](#quest-ce-quun-test-singulier-)
2. [Création de tests singuliers](#création-de-tests-singuliers)
3. [Exemples pratiques](#exemples-pratiques)
4. [Configuration](#configuration)
5. [Quand utiliser les tests singuliers](#quand-utiliser-les-tests-singuliers)

---

## Qu'est-ce qu'un test singulier ?

### Définition

Un **test singulier** est un fichier SQL personnalisé qui vérifie une assertion spécifique sur vos données.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TESTS SINGULIERS                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  tests/                                                             │
│  ├── assert_total_revenue_matches.sql      ◄── Fichier SQL          │
│  ├── assert_no_negative_amounts.sql                                 │
│  └── assert_orders_have_customers.sql                               │
│                                                                     │
│  Règle : Le test ÉCHOUE si la requête retourne des lignes           │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  SELECT *                                                   │    │
│  │  FROM {{ ref('fct_orders') }}                               │    │
│  │  WHERE amount < 0   -- Condition d'échec                    │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                         │                                           │
│       Si résultat = 0 lignes → ✅ PASS ✅                          │
│       Si résultat > 0 lignes → ❌ FAIL ❌                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Différence avec les tests génériques

| Aspect           | Tests Génériques      | Tests Singuliers |
|------------------|-----------------------|------------------|
| **Définition**   | Dans YAML             | Fichier .sql     |
| **Réutilisable** | Oui (avec paramètres) | Non (spécifique) |
| **Complexité**   | Limitée               | Illimitée        |
| **Usage**        | Validations standard  | Logique métier   |

---

## Création de tests singuliers

### Emplacement

Les tests singuliers sont placés dans le dossier `tests/`.

```
my_project/
├── models/
├── tests/                              ◄── Dossier des tests singuliers
│   ├── assert_positive_revenue.sql
│   ├── assert_orders_balance.sql
│   └── finance/
│       └── assert_monthly_close.sql
└── dbt_project.yml
```

### Structure d'un test

```sql
-- tests/assert_no_orphan_orders.sql

/*
    Test : Vérifie que toutes les commandes ont un client valide
    Attend : 0 lignes (sinon échec)
*/

SELECT
    o.order_id,
    o.customer_id
FROM {{ ref('fct_orders') }} o
LEFT JOIN {{ ref('dim_customers') }} c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL  -- Orphelins
```

### Convention de nommage

```
assert_<description_claire>.sql
```

Exemples :
- `assert_revenue_is_positive.sql`
- `assert_no_duplicate_invoices.sql`
- `assert_orders_after_customers.sql`

---

## Exemples pratiques

### 1. Vérification de cohérence entre tables

```sql
-- tests/assert_order_totals_match_line_items.sql

/*
    Vérifie que le total de la commande = somme des lignes
*/

WITH order_totals AS (
    SELECT
        order_id,
        order_total
    FROM {{ ref('fct_orders') }}
),

line_item_totals AS (
    SELECT
        order_id,
        SUM(line_total) AS calculated_total
    FROM {{ ref('fct_order_line_items') }}
    GROUP BY 1
)

SELECT
    o.order_id,
    o.order_total,
    l.calculated_total,
    o.order_total - l.calculated_total AS difference
FROM order_totals o
JOIN line_item_totals l
    ON o.order_id = l.order_id
WHERE ABS(o.order_total - l.calculated_total) > 0.01  -- Tolérance
```

### 2. Validation de règle métier

```sql
-- tests/assert_discounts_within_limits.sql

/*
    Règle métier : Les remises ne peuvent pas dépasser 50%
*/

SELECT
    order_id,
    discount_amount,
    order_subtotal,
    (discount_amount / NULLIF(order_subtotal, 0)) * 100 AS discount_pct
FROM {{ ref('fct_orders') }}
WHERE discount_amount > 0
  AND (discount_amount / NULLIF(order_subtotal, 0)) > 0.50  -- > 50%
```

### 3. Vérification de séquence temporelle

```sql
-- tests/assert_ship_date_after_order_date.sql

/*
    La date d'expédition doit être après la date de commande
*/

SELECT
    order_id,
    order_date,
    ship_date
FROM {{ ref('fct_orders') }}
WHERE ship_date IS NOT NULL
  AND ship_date < order_date  -- Incohérence temporelle
```

### 4. Vérification de complétude

```sql
-- tests/assert_all_products_have_category.sql

/*
    Tous les produits doivent avoir une catégorie assignée
*/

SELECT
    product_id,
    product_name,
    category_id
FROM {{ ref('dim_products') }}
WHERE category_id IS NULL
   OR category_id NOT IN (
       SELECT category_id FROM {{ ref('dim_categories') }}
   )
```

### 5. Balance financière

```sql
-- tests/assert_debits_equal_credits.sql

/*
    En comptabilité, débits = crédits
*/

WITH totals AS (
    SELECT
        SUM(CASE WHEN entry_type = 'debit' THEN amount ELSE 0 END) AS total_debits,
        SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE 0 END) AS total_credits
    FROM {{ ref('fct_journal_entries') }}
    WHERE is_posted = TRUE
)

SELECT
    total_debits,
    total_credits,
    total_debits - total_credits AS imbalance
FROM totals
WHERE ABS(total_debits - total_credits) > 0.01
```

### 6. Fraîcheur des données

```sql
-- tests/assert_recent_orders_exist.sql

/*
    Vérifie qu'il y a des commandes récentes (< 24h)
*/

SELECT 1 AS check_failed
WHERE NOT EXISTS (
    SELECT 1
    FROM {{ ref('fct_orders') }}
    WHERE ordered_at >= DATEADD('hour', -24, CURRENT_TIMESTAMP)
)
```

### 7. Unicité composite

```sql
-- tests/assert_unique_customer_email_per_region.sql

/*
    Un email ne peut être associé qu'à un seul client par région
*/

SELECT
    email,
    region,
    COUNT(*) AS count
FROM {{ ref('dim_customers') }}
WHERE email IS NOT NULL
GROUP BY 1, 2
HAVING COUNT(*) > 1
```

---

## Configuration

### Dans le fichier SQL

```sql
-- tests/assert_revenue_positive.sql

{{
    config(
        severity='error',
        tags=['finance', 'critical'],
        enabled=true
    )
}}

SELECT *
FROM {{ ref('fct_revenue') }}
WHERE amount < 0
```

### Dans dbt_project.yml

```yaml
# dbt_project.yml

tests:
  my_project:
    # Configuration par défaut
    +severity: error
    +store_failures: true
    
    # Par dossier
    finance:
      +tags: ['finance']
      +severity: error
```

### Dans un fichier YAML (schema.yml)

```yaml
# tests/schema.yml (optionnel)

version: 2

tests:
  - name: assert_revenue_positive
    description: "Vérifie que tous les revenus sont positifs"
    config:
      severity: error
      tags: ['finance', 'critical']
```

### Store failures

```yaml
# dbt_project.yml

tests:
  my_project:
    +store_failures: true
    +schema: test_results
```

Les lignes en échec sont stockées pour analyse :
```
analytics.test_results.assert_revenue_positive
```

---

## Quand utiliser les tests singuliers

### Cas d'usage appropriés

```
✅ UTILISER DES TESTS SINGULIERS POUR :

• Règles métier complexes
  - "Les remises VIP ne peuvent pas dépasser 30%"
  - "Le montant total doit correspondre à la somme des lignes"

• Validation cross-table
  - Cohérence entre facts et dimensions
  - Balance entre systèmes

• Assertions spécifiques au domaine
  - Contraintes comptables (débits = crédits)
  - Règles réglementaires

• Tests avec logique conditionnelle
  - "Si statut = X, alors champ Y doit être rempli"
```

### Quand préférer les tests génériques

```
✅ UTILISER DES TESTS GÉNÉRIQUES POUR :

• Validations standard (unique, not_null)
• Tests réutilisables
• Validation simple de colonnes

❌ NE PAS CRÉER DE TEST SINGULIER POUR :

• Un simple test not_null
• Un test unique
• Tests couverts par dbt_utils
```

### Arbre de décision

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CHOISIR LE TYPE DE TEST                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  "Le test est-il standard (unique, not_null, etc.) ?"               │
│      │                                                              │
│      ├── OUI → Test générique natif                                 │
│      │                                                              │
│      └── NON → "Existe-t-il dans dbt_utils ou dbt_expectations ?"   │
│                   │                                                 │
│                   ├── OUI → Test générique du package               │
│                   │                                                 │
│                   └── NON → "Est-ce réutilisable ?"                 │
│                               │                                     │
│                               ├── OUI → Créer un test générique     │
│                               │         personnalisé (macro)        │
│                               │                                     │
│                               └── NON → Test singulier              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Résumé

### Structure

```sql
-- tests/<nom_du_test>.sql

-- Retourne les lignes qui violent la règle
SELECT <colonnes>
FROM {{ ref('model') }}
WHERE <condition_violation>
```

### Règle d'or

> **Le test échoue si la requête retourne des lignes.**

### Checklist

- [ ] Nommer clairement : `assert_<description>.sql`
- [ ] Documenter avec un commentaire en haut du fichier
- [ ] Configurer la sévérité appropriée
- [ ] Utiliser `store_failures` pour le debug
- [ ] Organiser par domaine dans des sous-dossiers

---

## Prochaines étapes

→ [Tests personnalisés](./03-tests-personnalises.md)


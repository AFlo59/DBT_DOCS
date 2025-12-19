# Tests Personnalisés (Generic Tests Custom)

## 📋 Table des matières
1. [Concept](#concept)
2. [Création d'un test générique personnalisé](#création-dun-test-générique-personnalisé)
3. [Exemples de tests personnalisés](#exemples-de-tests-personnalisés)
4. [Tests avec plusieurs arguments](#tests-avec-plusieurs-arguments)
5. [Bonnes pratiques](#bonnes-pratiques)

---

## Concept

### Qu'est-ce qu'un test générique personnalisé ?

Un **test générique personnalisé** est une macro réutilisable qui définit un test pouvant être appliqué à n'importe quelle colonne ou table.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    TEST GÉNÉRIQUE PERSONNALISÉ                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  macros/tests/                                                       │
│  └── test_positive_value.sql    ◄── Définition de la macro          │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  {% test positive_value(model, column_name) %}              │    │
│  │      SELECT *                                               │    │
│  │      FROM {{ model }}                                       │    │
│  │      WHERE {{ column_name }} < 0                            │    │
│  │  {% endtest %}                                              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Utilisation (YAML) :                                               │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  columns:                                                   │    │
│  │    - name: amount                                           │    │
│  │      tests:                                                 │    │
│  │        - positive_value   ◄── Appliqué comme test natif    │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Avantages

| Avantage | Description |
|----------|-------------|
| **Réutilisabilité** | Un test, plusieurs colonnes/tables |
| **Maintenabilité** | Logique centralisée |
| **Lisibilité** | YAML déclaratif |
| **Paramétrable** | Arguments personnalisables |

---

## Création d'un test générique personnalisé

### Emplacement

```
macros/
├── tests/                       ◄── Dossier conventionnel
│   ├── test_positive_value.sql
│   ├── test_valid_email.sql
│   └── test_not_in_future.sql
└── other_macros/
```

### Syntaxe de base

```sql
-- macros/tests/test_<nom_du_test>.sql

{% test <nom_du_test>(model, column_name) %}

SELECT *
FROM {{ model }}
WHERE <condition_echec_avec_{{ column_name }}>

{% endtest %}
```

### Exemple simple : test_positive_value

```sql
-- macros/tests/test_positive_value.sql

{% test positive_value(model, column_name) %}

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} < 0

{% endtest %}
```

### Utilisation

```yaml
# schema.yml

models:
  - name: fct_orders
    columns:
      - name: amount
        tests:
          - positive_value  # ← Nom du test (sans "test_")
      
      - name: quantity
        tests:
          - positive_value
```

---

## Exemples de tests personnalisés

### 1. test_not_in_future

```sql
-- macros/tests/test_not_in_future.sql

{% test not_in_future(model, column_name) %}

/*
    Vérifie qu'une date n'est pas dans le futur
*/

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} > CURRENT_TIMESTAMP

{% endtest %}
```

```yaml
columns:
  - name: created_at
    tests:
      - not_in_future
```

### 2. test_valid_email

```sql
-- macros/tests/test_valid_email.sql

{% test valid_email(model, column_name) %}

/*
    Vérifie le format basique d'un email
*/

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL
  AND {{ column_name }} NOT LIKE '%@%.%'

{% endtest %}
```

### 3. test_string_length

```sql
-- macros/tests/test_string_length.sql

{% test string_length(model, column_name, min_length=1, max_length=255) %}

/*
    Vérifie la longueur d'une chaîne
*/

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL
  AND (
    LENGTH({{ column_name }}) < {{ min_length }}
    OR LENGTH({{ column_name }}) > {{ max_length }}
  )

{% endtest %}
```

```yaml
columns:
  - name: product_code
    tests:
      - string_length:
          min_length: 5
          max_length: 10
```

### 4. test_percentage_range

```sql
-- macros/tests/test_percentage_range.sql

{% test percentage_range(model, column_name, min_value=0, max_value=100) %}

/*
    Vérifie qu'une valeur est un pourcentage valide
*/

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL
  AND (
    {{ column_name }} < {{ min_value }}
    OR {{ column_name }} > {{ max_value }}
  )

{% endtest %}
```

### 5. test_valid_currency_code

```sql
-- macros/tests/test_valid_currency_code.sql

{% test valid_currency_code(model, column_name) %}

/*
    Vérifie les codes devise ISO 4217
*/

{% set valid_currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'CHF'] %}

SELECT
    {{ column_name }}
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL
  AND {{ column_name }} NOT IN (
    {% for currency in valid_currencies %}
        '{{ currency }}'{% if not loop.last %},{% endif %}
    {% endfor %}
  )

{% endtest %}
```

---

## Tests avec plusieurs arguments

### Test avec référence à une autre table

```sql
-- macros/tests/test_referential_integrity.sql

{% test referential_integrity(model, column_name, reference_model, reference_column) %}

/*
    Vérifie l'intégrité référentielle (version personnalisée)
*/

SELECT
    {{ column_name }} AS orphan_value
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL
  AND {{ column_name }} NOT IN (
    SELECT {{ reference_column }}
    FROM {{ ref(reference_model) }}
  )

{% endtest %}
```

```yaml
columns:
  - name: customer_id
    tests:
      - referential_integrity:
          reference_model: dim_customers
          reference_column: customer_id
```

### Test avec conditions multiples

```sql
-- macros/tests/test_conditional_not_null.sql

{% test conditional_not_null(model, column_name, condition_column, condition_value) %}

/*
    Si condition_column = condition_value, alors column_name ne doit pas être NULL
    Exemple : Si status = 'shipped', alors ship_date ne doit pas être NULL
*/

SELECT *
FROM {{ model }}
WHERE {{ condition_column }} = '{{ condition_value }}'
  AND {{ column_name }} IS NULL

{% endtest %}
```

```yaml
columns:
  - name: ship_date
    tests:
      - conditional_not_null:
          condition_column: status
          condition_value: shipped
```

### Test avec seuil de tolérance

```sql
-- macros/tests/test_value_within_tolerance.sql

{% test value_within_tolerance(model, column_name, compare_column, tolerance_pct=1) %}

/*
    Vérifie que deux colonnes sont égales à X% près
*/

SELECT
    {{ column_name }} AS value1,
    {{ compare_column }} AS value2,
    ABS({{ column_name }} - {{ compare_column }}) / NULLIF({{ compare_column }}, 0) * 100 AS diff_pct
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL
  AND {{ compare_column }} IS NOT NULL
  AND ABS({{ column_name }} - {{ compare_column }}) / NULLIF({{ compare_column }}, 0) * 100 > {{ tolerance_pct }}

{% endtest %}
```

---

## Bonnes pratiques

### Nommage

```
test_<action>_<description>.sql

Exemples :
- test_is_positive.sql
- test_has_valid_format.sql
- test_not_in_future.sql
- test_matches_pattern.sql
```

### Documentation

```sql
-- macros/tests/test_example.sql

{% test example(model, column_name, param1, param2='default') %}

/*
    Description : Ce que le test vérifie
    
    Paramètres :
    - model       : Le modèle à tester (automatique)
    - column_name : La colonne à tester (automatique)
    - param1      : Description du paramètre (requis)
    - param2      : Description du paramètre (défaut: 'default')
    
    Exemple d'utilisation :
    tests:
      - example:
          param1: 'value'
          param2: 'other'
    
    Échoue si : <condition d'échec>
*/

SELECT ...

{% endtest %}
```

### Organisation

```
macros/
└── tests/
    ├── _test_helpers.sql        # Macros utilitaires pour les tests
    ├── test_data_quality.sql    # Tests de qualité générale
    ├── test_business_rules.sql  # Tests de règles métier
    └── test_format_validation.sql # Tests de format
```

### Gestion des NULL

```sql
{% test my_test(model, column_name) %}

SELECT *
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL  -- Ignorer les NULL
  AND <condition_echec>

{% endtest %}
```

### Valeurs par défaut

```sql
{% test range_check(model, column_name, min_value=0, max_value=none) %}

SELECT *
FROM {{ model }}
WHERE {{ column_name }} < {{ min_value }}
  {% if max_value is not none %}
  OR {{ column_name }} > {{ max_value }}
  {% endif %}

{% endtest %}
```

### Réutiliser les macros utilitaires

```sql
-- macros/tests/_test_helpers.sql

{% macro get_valid_values(type) %}
    {% if type == 'status' %}
        ('active', 'inactive', 'pending')
    {% elif type == 'currency' %}
        ('USD', 'EUR', 'GBP')
    {% endif %}
{% endmacro %}
```

```sql
-- macros/tests/test_valid_status.sql

{% test valid_status(model, column_name) %}

SELECT *
FROM {{ model }}
WHERE {{ column_name }} NOT IN {{ get_valid_values('status') }}

{% endtest %}
```

---

## Résumé

### Structure d'un test personnalisé

```sql
{% test nom_du_test(model, column_name, [params...]) %}
    SELECT *
    FROM {{ model }}
    WHERE <condition_echec>
{% endtest %}
```

### Checklist

- [ ] Nom de fichier : `test_<nom>.sql`
- [ ] Emplacement : `macros/tests/`
- [ ] Documentation en commentaire
- [ ] Gestion des NULL
- [ ] Valeurs par défaut pour les paramètres optionnels

### Quand créer un test personnalisé ?

| Situation | Recommandation |
|-----------|----------------|
| Test standard (unique, not_null) | Utiliser les tests natifs |
| Test dans dbt_utils | Utiliser le package |
| Test réutilisable spécifique | Créer un test personnalisé |
| Test unique à un cas | Test singulier (.sql dans tests/) |

---

## Prochaines étapes

→ [Documentation des models](../07-documentation/01-documentation-models.md)


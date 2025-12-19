# Data Contracts (Contrats de Données)

## 📋 Table des matières
1. [Qu'est-ce qu'un Data Contract ?](#quest-ce-quun-data-contract-)
2. [Configuration d'un contrat](#configuration-dun-contrat)
3. [Définition du schéma](#définition-du-schéma)
4. [Contraintes (constraints)](#contraintes-constraints)
5. [Bonnes pratiques](#bonnes-pratiques)

---

## Qu'est-ce qu'un Data Contract ?

### Définition

Un **Data Contract** est un accord formel qui définit la structure attendue d'un modèle DBT. Quand `contract: enforced` est activé, DBT vérifie que le schéma du modèle correspond exactement aux spécifications.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DATA CONTRACTS                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  SANS CONTRAT                        AVEC CONTRAT                   │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐ │
│  │ • Schéma flexible           │    │ • Schéma strict             │ │
│  │ • Colonnes peuvent changer  │    │ • Types de données vérifiés │ │
│  │ • Pas de validation         │    │ • Erreur si non conforme    │ │
│  │ • Risque de breaking changes│    │ • API stable garantie       │ │
│  └─────────────────────────────┘    └─────────────────────────────┘ │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                       WORKFLOW                                 │ │
│  │ 1. Définir schema YAML → 2. dbt run → 3. Validation schema     │ │
│  │                                       → ✅ Success ou ❌ Fail │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Pourquoi utiliser les Data Contracts ?

| Avantage                    | Description                                       |
|-----------------------------|---------------------------------------------------|
| **Fiabilité**               | Garantit la structure des données                 |
| **Communication**           | Documentation formelle du schéma                  |
| **Breaking changes**        | Détection précoce des changements incompatibles   |
| **Intégration**             | API stable pour les consommateurs downstream      |
| **Gouvernance**             | Contrôle strict sur les modèles exposés           |

### Prérequis

```yaml
# dbt_project.yml
require-dbt-version: [">=1.5.0", "<2.0.0"]
```

---

## Configuration d'un contrat

### Activation au niveau du modèle

```yaml
# models/marts/_core__models.yml

models:
  - name: dim_customers
    description: "Dimension clients avec métriques"
    
    config:
      contract:
        enforced: true   # ← Active le contrat
    
    columns:
      - name: customer_id
        data_type: integer
        description: "ID unique du client"
        constraints:
          - type: not_null
          - type: primary_key
```

### Activation au niveau du projet

```yaml
# dbt_project.yml

models:
  my_project:
    marts:
      +contract:
        enforced: true   # Tous les modèles marts ont un contrat
```

### Activation dans le modèle SQL

```sql
-- models/marts/dim_customers.sql

{{ config(
    materialized='table',
    contract={'enforced': true}
) }}

SELECT ...
```

---

## Définition du schéma

### Types de données supportés

Les types de données dépendent de votre adapter (warehouse). Voici les types courants :

#### Snowflake

```yaml
columns:
  - name: id
    data_type: integer
  - name: name
    data_type: varchar(100)
  - name: amount
    data_type: number(10,2)
  - name: is_active
    data_type: boolean
  - name: created_at
    data_type: timestamp_ntz
  - name: metadata
    data_type: variant
```

#### BigQuery

```yaml
columns:
  - name: id
    data_type: int64
  - name: name
    data_type: string
  - name: amount
    data_type: numeric
  - name: is_active
    data_type: bool
  - name: created_at
    data_type: timestamp
  - name: metadata
    data_type: json
```

#### PostgreSQL

```yaml
columns:
  - name: id
    data_type: integer
  - name: name
    data_type: text
  - name: amount
    data_type: numeric(10,2)
  - name: is_active
    data_type: boolean
  - name: created_at
    data_type: timestamp
  - name: metadata
    data_type: jsonb
```

### Exemple complet

```yaml
models:
  - name: fct_orders
    description: "Fact table des commandes"
    
    config:
      contract:
        enforced: true
    
    columns:
      # Clé primaire
      - name: order_id
        data_type: varchar(50)
        description: "Identifiant unique de la commande"
        constraints:
          - type: not_null
          - type: primary_key
      
      # Clés étrangères
      - name: customer_id
        data_type: integer
        description: "ID du client"
        constraints:
          - type: not_null
          - type: foreign_key
            to: ref('dim_customers')
            to_columns: [customer_id]
      
      # Métriques
      - name: order_total
        data_type: number(12,2)
        description: "Montant total de la commande"
        constraints:
          - type: not_null
      
      # Dates
      - name: ordered_at
        data_type: timestamp_ntz
        description: "Date et heure de la commande"
        constraints:
          - type: not_null
      
      - name: shipped_at
        data_type: timestamp_ntz
        description: "Date et heure d'expédition"
        # Nullable car peut ne pas être expédiée
      
      # Flags
      - name: is_cancelled
        data_type: boolean
        description: "Indicateur d'annulation"
        constraints:
          - type: not_null
```

---

## Contraintes (constraints)

### Types de contraintes

| Contrainte      | Description                          | Exemple                    |
|-----------------|--------------------------------------|----------------------------|
| `not_null`      | La colonne ne peut pas être NULL     | `- type: not_null`         |
| `primary_key`   | Clé primaire (unique + not_null)     | `- type: primary_key`      |
| `unique`        | Valeurs uniques                      | `- type: unique`           |
| `check`         | Condition personnalisée              | `- type: check`            |
| `foreign_key`   | Clé étrangère vers une autre table   | `- type: foreign_key`      |

### Syntaxe des contraintes

```yaml
columns:
  - name: status
    data_type: varchar(20)
    constraints:
      # Contrainte simple
      - type: not_null
      
      # Contrainte avec expression (check)
      - type: check
        expression: "status IN ('pending', 'shipped', 'delivered')"
        name: valid_status_check
      
      # Contrainte avec warn_* (ne bloque pas)
      - type: not_null
        warn_unenforced: true
        warn_unsupported: true
```

### Clé étrangère

```yaml
columns:
  - name: customer_id
    data_type: integer
    constraints:
      - type: foreign_key
        to: ref('dim_customers')
        to_columns: [customer_id]
```

### Contrainte check

```yaml
columns:
  - name: discount_percent
    data_type: number(5,2)
    constraints:
      - type: check
        expression: "discount_percent >= 0 AND discount_percent <= 100"
        name: valid_discount_range

  - name: email
    data_type: varchar(255)
    constraints:
      - type: check
        expression: "email LIKE '%@%.%'"
        name: valid_email_format
```

### Support par warehouse

| Contrainte    | Snowflake | BigQuery | PostgreSQL | Redshift |
|---------------|-----------|----------|------------|----------|
| `not_null`    | ✅        | ✅       | ✅         | ✅       |
| `primary_key` | ⚠️*       | ❌       | ✅         | ⚠️*      |
| `unique`      | ⚠️*       | ❌       | ✅         | ⚠️*      |
| `check`       | ❌        | ❌       | ✅         | ❌       |
| `foreign_key` | ⚠️*       | ❌       | ✅         | ⚠️*      |

*⚠️ = Syntaxiquement supporté mais non enforced par le warehouse

---

## Exemples pratiques

### Dimension client avec contrat

```yaml
# models/marts/core/_core__models.yml

models:
  - name: dim_customers
    description: "Dimension clients enrichie"
    
    config:
      contract:
        enforced: true
      materialized: table
    
    columns:
      - name: customer_id
        data_type: integer
        description: "ID unique du client (clé primaire)"
        constraints:
          - type: not_null
          - type: primary_key
      
      - name: customer_key
        data_type: varchar(64)
        description: "Clé de substitution hash"
        constraints:
          - type: not_null
          - type: unique
      
      - name: first_name
        data_type: varchar(100)
        description: "Prénom du client"
        constraints:
          - type: not_null
      
      - name: last_name
        data_type: varchar(100)
        description: "Nom de famille"
        constraints:
          - type: not_null
      
      - name: email
        data_type: varchar(255)
        description: "Adresse email"
      
      - name: country_code
        data_type: varchar(3)
        description: "Code pays ISO"
      
      - name: customer_segment
        data_type: varchar(20)
        description: "Segment client"
        constraints:
          - type: check
            expression: "customer_segment IN ('VIP', 'Regular', 'New')"
      
      - name: total_orders
        data_type: integer
        description: "Nombre total de commandes"
        constraints:
          - type: not_null
      
      - name: lifetime_value
        data_type: number(12,2)
        description: "Valeur vie client"
        constraints:
          - type: not_null
      
      - name: first_order_date
        data_type: date
        description: "Date de première commande"
      
      - name: last_order_date
        data_type: date
        description: "Date de dernière commande"
      
      - name: is_active
        data_type: boolean
        description: "Client actif"
        constraints:
          - type: not_null
```

### Modèle SQL correspondant

```sql
-- models/marts/core/dim_customers.sql

{{ config(
    materialized='table',
    contract={'enforced': true}
) }}

SELECT
    -- Colonnes doivent correspondre EXACTEMENT au contrat
    customer_id::integer AS customer_id,
    {{ dbt_utils.generate_surrogate_key(['customer_id']) }}::varchar(64) AS customer_key,
    first_name::varchar(100) AS first_name,
    last_name::varchar(100) AS last_name,
    email::varchar(255) AS email,
    country_code::varchar(3) AS country_code,
    customer_segment::varchar(20) AS customer_segment,
    total_orders::integer AS total_orders,
    lifetime_value::number(12,2) AS lifetime_value,
    first_order_date::date AS first_order_date,
    last_order_date::date AS last_order_date,
    is_active::boolean AS is_active

FROM {{ ref('int_customers_enriched') }}
```

---

## Erreurs courantes

### 1. Colonne manquante

```
Contract violation: Column 'email' is in the contract but not in the model
```

**Solution** : Ajouter la colonne au SELECT ou la retirer du contrat.

### 2. Type de données incorrect

```
Contract violation: Column 'order_total' has type 'float' but contract specifies 'number(12,2)'
```

**Solution** : Caster la colonne au bon type :

```sql
order_total::number(12,2) AS order_total
```

### 3. Colonne supplémentaire non déclarée

```
Contract violation: Column 'extra_column' is in the model but not in the contract
```

**Solution** : Ajouter la colonne au contrat ou la retirer du SELECT.

### 4. Ordre des colonnes (optionnel)

Par défaut, l'ordre n'est pas vérifié. Pour l'activer :

```yaml
config:
  contract:
    enforced: true
    alias_types: true
```

---

## Bonnes pratiques

### 1. Quand utiliser les contrats ?

```
✅ UTILISER POUR :
- Modèles marts exposés aux équipes BI
- Tables consommées par des applications externes
- APIs de données publiques
- Modèles critiques pour le business

❌ NE PAS UTILISER POUR :
- Modèles staging (structure peut changer)
- Modèles intermédiaires internes
- Prototypage rapide
- Modèles en développement actif
```

### 2. Activation progressive

```yaml
# dbt_project.yml

models:
  my_project:
    staging:
      +contract:
        enforced: false  # Pas de contrat staging
    
    intermediate:
      +contract:
        enforced: false  # Pas de contrat intermediate
    
    marts:
      +contract:
        enforced: true   # Contrats pour les marts
      
      internal:
        +contract:
          enforced: false  # Sauf marts internes
```

### 3. Documentation des types

```yaml
columns:
  - name: amount
    data_type: number(12,2)  # ← Type explicite
    description: |
      Montant de la transaction en dollars.
      - Précision : 12 chiffres total
      - Échelle : 2 décimales
      - Exemple : 1234567890.99
```

### 4. Gestion des changements (breaking changes)

```yaml
# Avant de modifier un contrat :
# 1. Communiquer avec les consommateurs
# 2. Versionner si nécessaire
# 3. Prévoir une période de transition

# Option : créer une nouvelle version
models:
  - name: dim_customers_v2  # Nouvelle version
    config:
      contract:
        enforced: true
```

### 5. Tests complémentaires

Les contrats vérifient la structure, les tests vérifient les données :

```yaml
models:
  - name: dim_customers
    config:
      contract:
        enforced: true  # Vérifie la structure
    
    columns:
      - name: customer_id
        data_type: integer
        tests:
          - unique       # Vérifie les données
          - not_null     # Vérifie les données
```

---

## Résumé

### Configuration minimale

```yaml
models:
  - name: my_model
    config:
      contract:
        enforced: true
    columns:
      - name: id
        data_type: integer
        constraints:
          - type: not_null
```

### Checklist contrats

- [ ] Activer les contrats sur les modèles exposés (marts)
- [ ] Définir les types de données pour chaque colonne
- [ ] Ajouter les contraintes appropriées (not_null, primary_key)
- [ ] Documenter les colonnes
- [ ] Tester localement avant de pusher
- [ ] Communiquer les changements aux consommateurs

### Contraintes supportées

| Contrainte      | Usage                          |
|-----------------|--------------------------------|
| `not_null`      | Colonnes obligatoires          |
| `primary_key`   | Identifiants uniques           |
| `unique`        | Valeurs distinctes             |
| `check`         | Validations personnalisées     |
| `foreign_key`   | Relations entre tables         |

---

## Prochaines étapes

→ [Définition des Sources](../05-sources/01-definition-sources.md)


# Utilisation des Seeds

## 📋 Table des matières
1. [Concept des seeds](#concept-des-seeds)
2. [Création d'un seed](#création-dun-seed)
3. [Configuration](#configuration)
4. [Bonnes pratiques](#bonnes-pratiques)
5. [Cas d'usage](#cas-dusage)

---

## Concept des seeds

### Qu'est-ce qu'un seed ?

Un **seed** est un fichier CSV qui est chargé dans votre data warehouse comme une table.

```
┌──────────────────────────────────────────────────────────────────────┐
│                    CONCEPT DE SEED                                   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   seeds/                               Warehouse                     │
│   ┌───────────────────┐                ┌───────────────────────────┐ │
│   │ country_codes.csv │   dbt seed     │  analytics.country_codes  │ │
│   │                   │ ────────────>  │  ┌────────┬───────────┐   │ │
│   │ code,name         │                │  │ code   │ name      │   │ │
│   │ US,United States  │                │  │ US     │ United... │   │ │
│   │ FR,France         │                │  │ FR     │ France    │   │ │
│   └───────────────────┘                │  └────────┴───────────┘   │ │
│                                        └───────────────────────────┘ │
│                                                                      │
│   Le CSV devient une table dans le warehouse                         │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Quand utiliser les seeds ?

| ✅ Utiliser pour ✅           | ❌ Ne pas utiliser pour ❌           |
|--------------------------------|---------------------------------------|
| Données de référence statiques | Données volumineuses (> 10000 lignes) |
| Mappings (codes, catégories)   | Données changeant fréquemment         |
| Listes de valeurs              | Données sensibles (PII)               |
| Configurations métier          | Données de source externe             |

---

## Création d'un seed

### Structure

```
my_project/
└── seeds/
    ├── country_codes.csv
    ├── currency_rates.csv
    └── mappings/
        └── product_categories.csv
```

### Format CSV

```csv
# seeds/country_codes.csv

code,name,region,currency
US,United States,North America,USD
CA,Canada,North America,CAD
FR,France,Europe,EUR
DE,Germany,Europe,EUR
JP,Japan,Asia,JPY
```

**Règles :**
- Première ligne = noms des colonnes
- Séparateur = virgule (,)
- Encodage = UTF-8
- Pas de lignes vides

### Commande dbt seed

```bash
# Charger tous les seeds
dbt seed

# Charger un seed spécifique
dbt seed --select country_codes

# Full refresh (recréer la table)
dbt seed --full-refresh
```

### Utilisation dans les models

```sql
-- models/marts/dim_customers.sql

SELECT
    c.customer_id,
    c.customer_name,
    c.country_code,
    cc.name AS country_name,
    cc.region
FROM {{ ref('stg_customers') }} c
LEFT JOIN {{ ref('country_codes') }} cc  -- Référence au seed
    ON c.country_code = cc.code
```

---

## Configuration

### Dans dbt_project.yml

```yaml
# dbt_project.yml

seeds:
  my_project:
    # Configuration globale
    +schema: reference_data
    +quote_columns: true
    
    # Par dossier
    mappings:
      +schema: mappings
    
    # Par fichier
    country_codes:
      +column_types:
        code: varchar(3)
        name: varchar(100)
```

### Types de colonnes

```yaml
seeds:
  my_project:
    product_prices:
      +column_types:
        product_id: integer
        price: numeric(10,2)
        effective_date: date
        is_active: boolean
```

### Dans un fichier properties.yml

```yaml
# seeds/schema.yml

version: 2

seeds:
  - name: country_codes
    description: "Table de référence des codes pays ISO"
    config:
      schema: reference
      column_types:
        code: varchar(3)
    columns:
      - name: code
        description: "Code ISO 3166-1 alpha-2"
        tests:
          - unique
          - not_null
      - name: name
        description: "Nom complet du pays"
      - name: region
        description: "Région géographique"
```

### Options de configuration

| Option          | Description         | Exemple              |
|-----------------|---------------------|----------------------|
| `schema`        | Schéma cible        | `reference_data`     |
| `alias`         | Nom de la table     | `ref_countries`      |
| `column_types`  | Types de colonnes   | `{code: varchar(3)}` |
| `quote_columns` | Quoter les colonnes | `true`               |
| `enabled`       | Activer/désactiver  | `true`               |
| `tags`          | Tags                | `['reference']`      |

---

## Bonnes pratiques

### Taille des fichiers

```
✅ RECOMMANDÉ : < 1000 lignes
⚠️ ACCEPTABLE : 1000 - 10000 lignes
❌ ÉVITER : > 10000 lignes → utiliser source() + ETL
```

### Versioning

```gitignore
# NE PAS ajouter les seeds au .gitignore
# Les seeds doivent être versionnés !
```

### Organisation

```
seeds/
├── reference/           # Données de référence
│   ├── country_codes.csv
│   ├── currency_codes.csv
│   └── timezone_mapping.csv
├── mappings/            # Mappings métier
│   ├── product_categories.csv
│   └── status_codes.csv
└── config/              # Configuration
    └── feature_flags.csv
```

### Documentation

```yaml
# seeds/schema.yml

version: 2

seeds:
  - name: country_codes
    description: |
      Codes pays ISO 3166-1.
      
      **Source** : https://www.iso.org/iso-3166-country-codes.html
      **Dernière mise à jour** : 2024-01-15
      
    columns:
      - name: code
        description: "Code ISO 3166-1 alpha-2 (2 lettres)"
        tests:
          - unique
          - not_null
          - accepted_values:
              values: ['US', 'CA', 'FR', 'DE', 'JP', 'GB', 'AU']
```

### Tests sur les seeds

```yaml
seeds:
  - name: product_categories
    columns:
      - name: category_id
        tests:
          - unique
          - not_null
      - name: category_name
        tests:
          - not_null
      - name: parent_category_id
        tests:
          - relationships:
              to: ref('product_categories')
              field: category_id
```

---

## Cas d'usage

### 1. Codes pays

```csv
# seeds/country_codes.csv
code,name,region,currency,language
US,United States,North America,USD,en
CA,Canada,North America,CAD,en
FR,France,Europe,EUR,fr
DE,Germany,Europe,EUR,de
JP,Japan,Asia,JPY,ja
```

### 2. Mapping de statuts

```csv
# seeds/order_status_mapping.csv
status_code,status_name,status_category,is_final
P,Pending,In Progress,false
C,Confirmed,In Progress,false
S,Shipped,In Progress,false
D,Delivered,Completed,true
X,Cancelled,Completed,true
R,Refunded,Completed,true
```

```sql
-- Utilisation
SELECT
    o.order_id,
    o.status_code,
    sm.status_name,
    sm.status_category,
    sm.is_final
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('order_status_mapping') }} sm
    ON o.status_code = sm.status_code
```

### 3. Taux de change

```csv
# seeds/currency_rates.csv
from_currency,to_currency,rate,effective_date
USD,EUR,0.92,2024-01-01
USD,GBP,0.79,2024-01-01
USD,JPY,148.50,2024-01-01
EUR,USD,1.09,2024-01-01
```

### 4. Configuration feature flags

```csv
# seeds/feature_flags.csv
feature_name,is_enabled,rollout_percentage,description
new_checkout,true,100,New checkout flow
dark_mode,true,50,Dark mode UI
beta_features,false,0,Beta features access
```

```sql
-- Utilisation conditionnelle
{% set feature_flags = run_query("SELECT * FROM " ~ ref('feature_flags')) %}

{% if execute %}
    {% set new_checkout_enabled = feature_flags.columns['is_enabled'].values()[0] %}
{% endif %}
```

### 5. Calendrier fiscal

```csv
# seeds/fiscal_calendar.csv
calendar_date,fiscal_year,fiscal_quarter,fiscal_month,fiscal_week,is_holiday
2024-01-01,FY2024,Q3,M7,W27,true
2024-01-02,FY2024,Q3,M7,W27,false
2024-01-03,FY2024,Q3,M7,W27,false
```

### 6. Seeds comme simulation de données (développement/test)

Dans un contexte de **développement**, **formation** ou **démonstration**, vous pouvez utiliser des seeds pour simuler des données brutes qui seraient normalement chargées par un ETL.

```
┌─────────────────────────────────────────────────────────────────────┐
│              SEEDS COMME SIMULATION DE SOURCES                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  seeds/                            models/staging/                  │
│  ┌─────────────────────────┐      ┌─────────────────────────────┐   │
│  │ sample_data/            │      │ _sources.yml                │   │
│  │   raw_customers.csv ────┼──────┼─► identifier: raw_customers │   │
│  │   raw_orders.csv ───────┼──────┼─► identifier: raw_orders    │   │
│  └─────────────────────────┘      └─────────────────────────────┘   │
│                                                                     │
│  Les sources pointent vers les seeds via l'attribut `identifier`    │
│                                                                     │
│  ATTENTION : Cette approche est pour le DEV/TEST uniquement !       │
│  En production, les sources pointent vers les vraies tables.        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Configuration sources.yml :**

```yaml
sources:
  - name: ecommerce
    description: "Données e-commerce (simulées via seeds en dev)"
    
    # En production, utiliser :
    # database: RAW_DATA
    # schema: ECOMMERCE_RAW
    
    tables:
      - name: customers
        identifier: raw_customers  # Pointe vers le seed raw_customers
      
      - name: orders
        identifier: raw_orders     # Pointe vers le seed raw_orders
```

**Usage dans les modèles :**

```sql
-- models/staging/stg_customers.sql
SELECT *
FROM {{ source('ecommerce', 'customers') }}
-- En dev : pointe vers le seed raw_customers
-- En prod : pointe vers la vraie table raw.customers
```

> ⚠️ **Important** : Cette technique est utile pour les projets de démonstration, les formations ou les tests sans accès aux données réelles. En production, assurez-vous que les sources pointent vers les tables chargées par votre ETL.

---

## Résumé

### Workflow

```bash
# 1. Créer le fichier CSV dans seeds/
# 2. Configurer dans dbt_project.yml ou schema.yml
# 3. Charger avec dbt seed
# 4. Utiliser avec {{ ref('seed_name') }}
```

### Commandes

| Commande                  | Action                     |
|---------------------------|----------------------------|
| `dbt seed`                | Charger tous les seeds     |
| `dbt seed --select X`     | Charger un seed spécifique |
| `dbt seed --full-refresh` | Recréer les tables         |

### Checklist

- [ ] Fichiers CSV en UTF-8
- [ ] < 1000 lignes par fichier
- [ ] Types de colonnes définis
- [ ] Tests sur les clés
- [ ] Documentation complète
- [ ] Versionné dans Git

---

## Prochaines étapes

→ [Concept SCD (Snapshots)](../10-snapshots/01-concept-scd.md)


# Configuration des Snapshots

## 📋 Table des matières
1. [Syntaxe complète](#syntaxe-complète)
2. [Stratégies de détection](#stratégies-de-détection)
3. [Options de configuration](#options-de-configuration)
4. [Gestion des suppressions](#gestion-des-suppressions)
5. [Bonnes pratiques](#bonnes-pratiques)

---

## Syntaxe complète

### Structure d'un snapshot

```sql
-- snapshots/snap_customers.sql

{% snapshot snap_customers %}

{{
    config(
        -- Obligatoire
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        
        -- Selon la stratégie
        updated_at='updated_at',  -- Pour strategy='timestamp'
        -- check_cols=['col1', 'col2'],  -- Pour strategy='check'
        
        -- Optionnel
        target_database='analytics',
        invalidate_hard_deletes=true
    )
}}

SELECT
    customer_id,
    customer_name,
    email,
    city,
    updated_at
FROM {{ source('raw', 'customers') }}

{% endsnapshot %}
```

### Plusieurs snapshots dans un fichier

```sql
-- snapshots/crm_snapshots.sql

{% snapshot snap_customers %}
{{ config(...) }}
SELECT ... FROM {{ source('crm', 'customers') }}
{% endsnapshot %}


{% snapshot snap_contacts %}
{{ config(...) }}
SELECT ... FROM {{ source('crm', 'contacts') }}
{% endsnapshot %}
```

---

## Stratégies de détection

### Strategy: timestamp

Détecte les changements via une colonne de timestamp.

```sql
{% snapshot snap_products %}

{{
    config(
        target_schema='snapshots',
        unique_key='product_id',
        strategy='timestamp',
        updated_at='modified_at'  -- Colonne de timestamp
    )
}}

SELECT
    product_id,
    product_name,
    price,
    modified_at
FROM {{ source('catalog', 'products') }}

{% endsnapshot %}
```

**Fonctionnement :**
```
┌─────────────────────────────────────────────────────────────────────┐
│                    STRATEGY: TIMESTAMP                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Source                           Snapshot                         │
│   ┌──────────────────────────┐    ┌──────────────────────────────┐  │
│   │ id │ name  │ updated_at  │    │ id │ name  │ dbt_updated_at  │  │
│   │ 1  │ Apple │ 2024-01-15  │    │ 1  │ Apple │ 2024-01-10      │  │
│   └──────────────────────────┘    └──────────────────────────────┘  │
│          │                                                 │        │
│          │   Comparaison des timestamps                    │        │
│          │   2024-01-15 > 2024-01-10 ?                     │        │
│          │            ✅ OUI ✅                           │        │
│          │                                                 │        │
│          └───────────> Nouvelle version créée ◄────────────┘        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Avantages :**
- Plus performant (comparaison simple)
- Logique claire

**Inconvénients :**
- Nécessite une colonne `updated_at` fiable
- Ne détecte pas les changements si `updated_at` n'est pas mis à jour

### Strategy: check

Détecte les changements en comparant les valeurs des colonnes.

```sql
{% snapshot snap_employees %}

{{
    config(
        target_schema='snapshots',
        unique_key='employee_id',
        strategy='check',
        check_cols=['department', 'title', 'salary']  -- Colonnes à surveiller
    )
}}

SELECT
    employee_id,
    employee_name,
    department,
    title,
    salary
FROM {{ source('hr', 'employees') }}

{% endsnapshot %}
```

**check_cols options :**

```sql
-- Colonnes spécifiques
check_cols=['department', 'title', 'salary']

-- Toutes les colonnes
check_cols='all'
```

**Fonctionnement :**
```
┌─────────────────────────────────────────────────────────────────────┐
│                    STRATEGY: CHECK                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Source                           Snapshot                         │
│   ┌────────────────────────────┐  ┌────────────────────────────┐    │
│   │ id │ name │ dept │ salary  │  │ id │ name │ dept │ salary  │    │
│   │ 1  │ Bob  │ IT   │ 60000   │  │ 1  │ Bob  │ HR   │ 55000   │    │
│   └────────────────────────────┘  └────────────────────────────┘    │
│          │                                              │           │
│          │   Comparaison des colonnes check             │           │
│          │   ✅ dept: IT != HR ? ✅                    │           │
│          │   ✅ salary: 60000 != 55000 ? ✅            │           │
│          │                                              │           │
│          └───────────> Nouvelle version créée ◄─────────┘          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Avantages :**
- Pas besoin de colonne `updated_at`
- Détecte tous les changements

**Inconvénients :**
- Plus lent (compare toutes les colonnes)
- Plus de CPU/IO

---

## Options de configuration

### Configuration complète

```sql
{{
    config(
        -- Localisation
        target_database='analytics',      -- Base de données cible
        target_schema='snapshots',        -- Schéma cible
        
        -- Identité
        unique_key='customer_id',         -- Clé naturelle (peut être une liste)
        
        -- Stratégie
        strategy='timestamp',
        updated_at='updated_at',
        -- OU
        -- strategy='check',
        -- check_cols=['col1', 'col2'],
        
        -- Gestion des suppressions
        invalidate_hard_deletes=true,
        
        -- Autres
        tags=['daily', 'critical'],
        enabled=true
    )
}}
```

### unique_key composite

```sql
{{
    config(
        unique_key=['order_id', 'line_item_id'],  -- Clé composite
        strategy='timestamp',
        updated_at='updated_at'
    )
}}
```

### Configuration dans dbt_project.yml

```yaml
# dbt_project.yml

snapshots:
  my_project:
    +target_schema: snapshots
    +strategy: timestamp
    
    # Par dossier
    crm:
      +target_schema: crm_snapshots
    
    finance:
      +target_schema: finance_snapshots
      +invalidate_hard_deletes: true
```

---

## Gestion des suppressions

### invalidate_hard_deletes

Quand une ligne disparaît de la source, DBT peut l'invalider dans le snapshot.

```sql
{{
    config(
        ...
        invalidate_hard_deletes=true
    )
}}
```

**Comportement :**

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HARD DELETES                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Source (après suppression)     Snapshot                           │
│   ┌──────────────────────┐      ┌─────────────────────────────────┐ │
│   │ id │ name            │      │ id │ name │ valid_to            │ │
│   │ 1  │ Alice           │      │ 1  │ Alice│ NULL                │ │
│   │    │ (Bob supprimé)  │      │ 2  │ Bob  │ 2024-01-15 ← Fermé  │ │
│   └──────────────────────┘      └─────────────────────────────────┘ │
│                                                                     │
│   Avec invalidate_hard_deletes=true :                               │
│   La ligne de Bob est "fermée" (valid_to = date courante)           │
│                                                                     │
│   Avec invalidate_hard_deletes=false (défaut) :                     │
│   La ligne de Bob reste ouverte (valid_to = NULL)                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Soft deletes

Si votre source utilise des soft deletes (flag `is_deleted`), incluez-le dans le snapshot :

```sql
{% snapshot snap_customers %}

{{
    config(
        unique_key='customer_id',
        strategy='check',
        check_cols=['name', 'email', 'is_deleted']  -- Inclure le flag
    )
}}

SELECT
    customer_id,
    name,
    email,
    is_deleted,
    updated_at
FROM {{ source('crm', 'customers') }}

{% endsnapshot %}
```

---

## Bonnes pratiques

### Nommage

```
snap_<nom_de_la_source>

Exemples :
- snap_customers
- snap_products
- snap_employee_salaries
```

### Organisation

```
snapshots/
├── crm/
│   ├── snap_customers.sql
│   └── snap_contacts.sql
├── catalog/
│   └── snap_products.sql
└── schema.yml
```

### Documentation

```yaml
# snapshots/schema.yml

version: 2

snapshots:
  - name: snap_customers
    description: |
      Snapshot SCD Type 2 des clients.
      
      **Stratégie** : timestamp (updated_at)
      **Fréquence** : Quotidienne
      
    columns:
      - name: customer_id
        description: "Clé naturelle du client"
      - name: dbt_valid_from
        description: "Début de validité de cette version"
      - name: dbt_valid_to
        description: "Fin de validité (NULL = version actuelle)"
```

### Filtrage des données

```sql
{% snapshot snap_active_customers %}

{{
    config(
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at'
    )
}}

SELECT
    customer_id,
    customer_name,
    email,
    updated_at
FROM {{ source('crm', 'customers') }}
WHERE is_active = true  -- Filtrer en amont

{% endsnapshot %}
```

### Tests sur les snapshots

```yaml
# snapshots/schema.yml

snapshots:
  - name: snap_customers
    columns:
      - name: customer_id
        tests:
          - not_null
      - name: dbt_scd_id
        tests:
          - unique
          - not_null
```

### Vue pour la version courante

```sql
-- models/dims/dim_customers.sql

SELECT
    customer_id,
    customer_name,
    email,
    city
FROM {{ ref('snap_customers') }}
WHERE dbt_valid_to IS NULL  -- Version courante uniquement
```

---

## Résumé

### Stratégies

| Stratégie   | Quand utiliser                                 |
|-------------|------------------------------------------------|
| `timestamp` | Colonne `updated_at` fiable                    |
| `check`     | Pas de timestamp, ou besoin de tout surveiller |

### Configuration minimale

```sql
{% snapshot snap_example %}
{{
    config(
        target_schema='snapshots',
        unique_key='id',
        strategy='timestamp',
        updated_at='updated_at'
    )
}}
SELECT * FROM {{ source('raw', 'table') }}
{% endsnapshot %}
```

### Commandes

| Commande                  | Action                      |
|---------------------------|-----------------------------|
| `dbt snapshot`            | Exécuter tous les snapshots |
| `dbt snapshot --select X` | Snapshot spécifique         |

### Checklist

- [ ] Choisir la stratégie appropriée
- [ ] Définir la `unique_key`
- [ ] Configurer `target_schema`
- [ ] Considérer `invalidate_hard_deletes`
- [ ] Documenter le snapshot
- [ ] Créer une vue pour la version courante

---

## Prochaines étapes

→ [Hooks](../11-hooks-operations/01-hooks.md)


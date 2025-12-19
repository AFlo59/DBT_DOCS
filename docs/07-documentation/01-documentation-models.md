# Documentation des Models

## 📋 Table des matières
1. [Importance de la documentation](#importance-de-la-documentation)
2. [Documentation dans les fichiers YAML](#documentation-dans-les-fichiers-yaml)
3. [Documentation dans les fichiers SQL](#documentation-dans-les-fichiers-sql)
4. [Blocs de documentation](#blocs-de-documentation)
5. [Persist docs](#persist-docs)

---

## Importance de la documentation

### Pourquoi documenter ?

```
┌─────────────────────────────────────────────────────────────────────┐
│                    VALEUR DE LA DOCUMENTATION                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  SANS DOCUMENTATION                    AVEC DOCUMENTATION           │
│  ──────────────────                    ───────────────────          │
│                                                                     │
│  "C'est quoi cette               ┌─────────────────────────┐        │
│   colonne 'amt_ttc' ?"           │ fct_orders              │        │
│                                  │                         │        │
│  "Quelle est la source           │ Description:            │        │
│   de ces données ?"              │ Commandes validées      │        │
│                                  │                         │        │
│  "Ce montant est en              │ Colonnes:               │        │
│   TTC ou HT ?"                   │ • order_total: Montant  │        │
│                                  │   TTC en EUR            │        │
│  "Qui maintient ce               │ • customer_id: FK vers  │        │
│   modèle ?"                      │   dim_customers         │        │
│                                  └─────────────────────────┘        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Avantages

| Bénéfice        | Description                               |
|-----------------|-------------------------------------------|
| **Autonomie**   | Utilisateurs trouvent les infos seuls     |
| **Onboarding**  | Nouveaux membres opérationnels rapidement |
| **Qualité**     | Moins d'erreurs d'interprétation          |
| **Maintenance** | Code plus facile à reprendre              |
| **Confiance**   | Données traçables et comprises            |

---

## Documentation dans les fichiers YAML

### Structure de base

```yaml
# models/marts/core/_core__models.yml

version: 2

models:
  - name: fct_orders
    description: |
      Table de faits des commandes.
      
      **Grain** : Une ligne par commande
      **Mise à jour** : Quotidienne à 6h UTC
      **Source** : Système e-commerce Shopify
      
    columns:
      - name: order_id
        description: "Identifiant unique de la commande (clé primaire)"
        
      - name: customer_id
        description: "Référence vers dim_customers"
        
      - name: order_total
        description: "Montant total TTC en EUR"
```

### Documentation enrichie (Markdown)

```yaml
models:
  - name: dim_customers
    description: |
      # Dimension Clients
      
      Cette table contient tous les clients ayant passé au moins une commande.
      
      ## Utilisation
      
      - Segmentation marketing
      - Analyse de la valeur client (LTV)
      - Rapports de rétention
      
      ## Notes importantes
      
      - Les clients sont dédupliqués par email
      - Le `customer_segment` est recalculé quotidiennement
      
      ## Colonnes clés
      
      | Colonne        | Description                   |
      |----------------|-------------------------------|
      | customer_id    | Clé primaire                  |
      | lifetime_value | Somme de toutes les commandes |
      
    columns:
      - name: customer_id
        description: |
          Identifiant unique du client.
          
          - **Format** : UUID
          - **Source** : Shopify customer ID
          - **Contrainte** : NOT NULL, UNIQUE
```

### Documentation des colonnes

```yaml
columns:
  - name: order_status
    description: |
      Statut actuel de la commande.
      
      **Valeurs possibles :**
      - `pending` : Commande en attente de paiement
      - `confirmed` : Paiement reçu, en préparation
      - `shipped` : Commande expédiée
      - `delivered` : Commande livrée
      - `cancelled` : Commande annulée
      - `refunded` : Commande remboursée
      
  - name: created_at
    description: |
      Date et heure de création de la commande.
      
      - **Timezone** : UTC
      - **Format** : TIMESTAMP
      
  - name: amount_eur
    description: |
      Montant de la commande en euros.
      
      ⚠️ **Attention** : Montant TTC (TVA incluse)
      
      Pour obtenir le HT : `amount_eur / 1.20`
```

### Métadonnées (meta)

```yaml
models:
  - name: fct_orders
    description: "Table des commandes"
    
    meta:
      owner: "data-team@company.com"
      tier: "gold"
      sla: "24h"
      pii: false
      tags:
        - finance
        - core
    
    columns:
      - name: customer_email
        description: "Email du client"
        meta:
          pii: true
          masking: "hash"
```

---

## Documentation dans les fichiers SQL

### Commentaires en haut de fichier

```sql
-- models/marts/core/fct_orders.sql

/*
╔═══════════════════════════════════════════════════════════════════╗
║                         FCT_ORDERS                                ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  Description : Table de faits des commandes validées              ║
║                                                                   ║
║  Grain : Une ligne par commande (order_id)                        ║
║                                                                   ║
║  Source :                                                         ║
║    - stg_shopify__orders                                          ║
║    - stg_stripe__payments                                         ║
║                                                                   ║
║  Mise à jour : Quotidienne (job: daily_transform)                 ║
║                                                                   ║
║  Owner : @data-team                                               ║
║                                                                   ║
║  Changelog :                                                      ║
║    - 2024-01-15 : Ajout colonne payment_method                    ║
║    - 2023-12-01 : Création initiale                               ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
*/

{{ config(materialized='table') }}

WITH ...
```

### Commentaires inline

```sql
SELECT
    order_id,
    customer_id,
    
    -- Montant total TTC (TVA 20% incluse)
    order_total,
    
    -- Convertir de centimes en euros
    order_total / 100.0 AS order_total_eur,
    
    -- Flag calculé : nouvelle commande si < 24h
    CASE 
        WHEN ordered_at >= DATEADD('hour', -24, CURRENT_TIMESTAMP) 
        THEN TRUE 
        ELSE FALSE 
    END AS is_recent,
    
    ordered_at  -- Timezone: UTC
FROM {{ ref('stg_orders') }}
```

---

## Blocs de documentation

### Concept

Les **doc blocks** permettent de créer des descriptions réutilisables.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DOC BLOCKS                                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Définition (docs/descriptions.md)                                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  {% docs order_status %}                                    │    │
│  │  Statut de la commande : pending, shipped, delivered...     │    │
│  │  {% enddocs %}                                              │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Utilisation (schema.yml)                                           │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  columns:                                                   │    │
│  │    - name: status                                           │    │
│  │      description: "{{ doc('order_status') }}"               │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Création d'un doc block

```markdown
{# models/docs/descriptions.md #}

{% docs order_status %}

Statut de la commande dans le cycle de vie.

| Valeur      | Description            |
|-------------|------------------------|
| `pending`   | En attente de paiement |
| `confirmed` | Paiement reçu          |
| `shipped`   | Expédiée               |
| `delivered` | Livrée                 |
| `cancelled` | Annulée                |

{% enddocs %}


{% docs customer_id %}

Identifiant unique du client.

- **Format** : UUID v4
- **Source** : Généré par Shopify
- **Référence** : `dim_customers.customer_id`

{% enddocs %}


{% docs amount_convention %}

## Convention des montants

Tous les montants monétaires dans ce projet suivent ces règles :

1. **Devise** : EUR (sauf indication contraire)
2. **Précision** : 2 décimales
3. **Type** : DECIMAL(10,2)
4. **TVA** : Les montants sont en TTC sauf suffixe `_ht`

{% enddocs %}
```

### Utilisation des doc blocks

```yaml
# schema.yml

version: 2

models:
  - name: fct_orders
    description: "{{ doc('amount_convention') }}"
    
    columns:
      - name: order_status
        description: "{{ doc('order_status') }}"
        
      - name: customer_id
        description: "{{ doc('customer_id') }}"
```

### Organisation des doc blocks

```
models/
├── docs/
│   ├── __overview__.md           # Page d'accueil de la doc
│   ├── columns.md                # Descriptions des colonnes communes
│   ├── business_terms.md         # Glossaire métier
│   └── conventions.md            # Conventions du projet
```

### Page d'accueil (__overview__.md)

```markdown
{# models/docs/__overview__.md #}

{% docs __overview__ %}

# Data Warehouse Documentation

Bienvenue dans la documentation du Data Warehouse de **Company Inc.**

## 🏗️ Architecture

Notre warehouse est organisé en couches :
- **Staging** : Données brutes nettoyées
- **Intermediate** : Logique métier
- **Marts** : Tables finales pour l'analyse

## 📊 Marts disponibles

| Mart      | Description                  |
|-----------|------------------------------|
| Core      | Dimensions et faits partagés |
| Finance   | Métriques financières        |
| Marketing | Performance des campagnes    |

## 📞 Contact

- **Data Team** : data-team@company.com
- **Slack** : #data-support

{% enddocs %}
```

---

## Persist docs

### Concept

**persist_docs** permet de pousser la documentation dans les métadonnées du warehouse.

```yaml
# dbt_project.yml

models:
  my_project:
    +persist_docs:
      relation: true    # Description de la table
      columns: true     # Description des colonnes
```

### Résultat dans le warehouse

```sql
-- Snowflake : la description est visible
SHOW TABLES LIKE 'fct_orders';
-- COMMENT: "Table de faits des commandes..."

DESCRIBE TABLE fct_orders;
-- COLUMN_NAME | DATA_TYPE | COMMENT
-- order_id    | NUMBER    | Identifiant unique...
```

### Par model

```sql
{{
    config(
        materialized='table',
        persist_docs={
            'relation': true,
            'columns': true
        }
    )
}}
```

### Support par warehouse

| Warehouse  | Relation | Columns |
|------------|----------|---------|
| Snowflake  | ✅✅    | ✅✅   |
| BigQuery   | ✅✅    | ✅✅   |
| Redshift   | ✅✅    | ❌❌   |
| PostgreSQL | ✅✅    | ✅✅   |

---

## Résumé

### Où documenter ?

| Type                | Emplacement        |
|---------------------|--------------------|
| Description model   | `schema.yml`       |
| Description colonne | `schema.yml`       |
| Texte réutilisable  | Doc blocks (`.md`) |
| Notes techniques    | Commentaires SQL   |

### Template de documentation

```yaml
models:
  - name: <model_name>
    description: |
      # <Titre>
      
      <Description courte>
      
      ## Grain
      <Une ligne par X>
      
      ## Sources
      - <source 1>
      - <source 2>
      
      ## Notes
      <Informations importantes>
      
    meta:
      owner: <email>
      tier: <bronze/silver/gold>
      
    columns:
      - name: <column>
        description: "<description>"
```

### Checklist

- [ ] Description de chaque model
- [ ] Description des colonnes importantes
- [ ] Grain explicite
- [ ] Sources listées
- [ ] Métadonnées (owner, tier)
- [ ] persist_docs activé
- [ ] Page __overview__.md créée

---

## Prochaines étapes

→ [Génération de la documentation](./02-generation-doc.md)


# Introduction à DBT (Data Build Tool)

## 📋 Table des matières
1. [Qu'est-ce que DBT ?](#quest-ce-que-dbt-)
2. [Pourquoi DBT ?](#pourquoi-dbt-)
3. [Positionnement dans l'écosystème Data](#positionnement-dans-lécosystème-data)
4. [Les deux versions de DBT](#les-deux-versions-de-dbt)
5. [Cas d'usage](#cas-dusage)

---

## Qu'est-ce que DBT ?

**DBT (Data Build Tool)** est un outil open-source de transformation de données qui permet aux analystes et ingénieurs data d'appliquer les bonnes pratiques du génie logiciel à leur travail de transformation.

### Définition technique

DBT est un **outil en ligne de commande** qui :
- Compile du code SQL (avec Jinja templating)
- Exécute les transformations directement dans votre data warehouse
- Gère les dépendances entre les transformations
- Documente et teste les données

```
┌─────────────────────────────────────────────────────────────────┐
│                        Data Warehouse                           │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌───────────┐  │
│  │  Sources │ -> │ Staging  │ -> │   Marts  │ -> │ Analytics │  │
│  │  (Raw)   │    │ (Clean)  │    │(Business)│    │  (Final)  │  │
│  └──────────┘    └──────────┘    └──────────┘    └───────────┘  │
│                                                                 │
│                    ▲ DBT opère ici ▲                            │
└─────────────────────────────────────────────────────────────────┘
```

### Ce que DBT fait

| Fonctionnalité              | Description                                           |
|-----------------------------|-------------------------------------------------------|
| **Transformation (T)**      | Transforme les données brutes en données exploitables |
| **Modélisation**            | Crée des vues et tables via des SELECT SQL            |
| **Tests**                   | Valide la qualité des données                         |
| **Documentation**           | Génère une documentation automatique                  |
| **Gestion des dépendances** | Ordonne les exécutions via un DAG                     |
| **Versioning**              | Compatible Git pour le contrôle de version            |

### Ce que DBT ne fait PAS

- ❌ **Extraction** : Ne récupère pas les données depuis les sources
- ❌ **Chargement** : Ne charge pas les données dans le warehouse
- ❌ **Orchestration** : N'est pas un orchestrateur (utiliser Airflow, Prefect, etc.)
- ❌ **Stockage** : N'est pas une base de données

---

## Pourquoi DBT ?

### Les problèmes résolus

#### 1. Transformations SQL non maintenables
**Avant DBT :**
```sql
-- Script monolithique de 2000 lignes
-- Aucune modularité
-- Dépendances implicites
-- Impossible à tester
CREATE TABLE final_report AS
SELECT ... FROM (
    SELECT ... FROM (
        SELECT ... FROM raw_data
    )
)
```

**Avec DBT :**
```sql
-- models/staging/stg_customers.sql
SELECT
    id AS customer_id,
    TRIM(name) AS customer_name,
    created_at
FROM {{ source('raw', 'customers') }}

-- models/marts/dim_customers.sql
SELECT * FROM {{ ref('stg_customers') }}
WHERE customer_id IS NOT NULL
```

#### 2. Absence de tests sur les données
```yaml
# DBT permet de définir des tests déclaratifs
models:
  - name: stg_customers
    columns:
      - name: customer_id
        tests:
          - unique
          - not_null
```

#### 3. Documentation inexistante
DBT génère automatiquement :
- Un site de documentation
- Un graphe des dépendances (Lineage)
- Les descriptions des colonnes et tables

---

## Positionnement dans l'écosystème Data

### Le Modern Data Stack

```
┌──────────────────────────────────────────────────────────────────────┐
│                     MODERN DATA STACK                                │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   SOURCES          INGESTION         WAREHOUSE        TRANSFORMATION │
│  ┌────────┐       ┌────────┐        ┌─────────┐       ┌────────┐     │
│  │Postgres│──┐    │        │        │         │       │        │     │
│  └────────┘  │    │Fivetran│        │Snowflake│       │  DBT   │     │
│  ┌────────┐  ├───>│   or   │──────> │   or    │─────> │        │     │
│  │  APIs  │──┤    │ Airbyte│        │BigQuery │       │        │     │
│  └────────┘  │    │        │        │   or    │       │        │     │
│  ┌────────┐  │    └────────┘        │Redshift │       └────────┘     │
│  │  Files │──┘                      └─────────┘           │          │
│  └────────┘                                               │          │
│                                                           ▼          │
│                                              ┌───────────────────┐   │
│   BI & ANALYTICS                             │  Tables/Vues      │   │
│  ┌────────────────────────────────────────── │  prêtes pour      │   │
│  │ Looker | Tableau | Metabase | PowerBI     │  l'analyse        │   │
│  └────────────────────────────────────────── └───────────────────┘   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Intégrations supportées

| Catégorie            | Plateformes                               |
|----------------------|-------------------------------------------|
| **Cloud Warehouses** | Snowflake, BigQuery, Redshift, Databricks |
| **On-premise**       | PostgreSQL, SQL Server, Oracle            |
| **Data Lakes**       | Spark, Trino, Starburst                   |

---

## Les deux versions de DBT

### DBT Core (Open Source)

```bash
# Installation via pip
pip install dbt-core dbt-snowflake

# Utilisation en ligne de commande
dbt run
dbt test
dbt docs generate
```

**Caractéristiques :**
- Gratuit et open-source
- Exécution locale ou sur serveur
- Nécessite une infrastructure propre
- Communauté active

### DBT Cloud (SaaS)

**Caractéristiques :**
- Interface web
- IDE intégré
- Scheduling intégré
- CI/CD automatisé
- Gestion des environnements
- Logs et monitoring
- Version gratuite (développeur) et payante (équipe)

### Comparaison

| Fonctionnalité | DBT Core   | DBT Cloud |
|----------------|------------|-----------|
| Prix           | Gratuit    | Freemium |
| Installation   | Locale     | Cloud |
| IDE            | VS Code + extensions | Intégré |
| Scheduling     | Manuel (Airflow, etc.) | Intégré |
| CI/CD          | Configuration manuelle | Automatisé |
| Support        | Communauté | Commercial |

---

## Cas d'usage

### 1. Construction d'un Data Warehouse analytique

```
Sources brutes → Staging → Intermediate → Marts → Dashboards
```

### 2. Nettoyage et normalisation des données

```sql
-- Transformation typique
SELECT
    UPPER(country_code) AS country_code,
    COALESCE(revenue, 0) AS revenue,
    DATE_TRUNC('day', created_at) AS created_date
FROM {{ source('raw', 'sales') }}
```

### 3. Création de métriques métier

```sql
-- models/marts/fct_revenue.sql
SELECT
    DATE_TRUNC('month', order_date) AS month,
    SUM(amount) AS total_revenue,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM {{ ref('stg_orders') }}
GROUP BY 1
```

### 4. Alimentation d'outils BI

DBT crée des tables/vues optimisées pour :
- Tableau
- Looker
- Power BI
- Metabase

---

## Résumé

| Aspect | Description |
|--------|-------------|
| **Type** | Outil de transformation SQL |
| **Paradigme** | ELT (pas ETL) |
| **Langage** | SQL + Jinja |
| **Exécution** | Dans le data warehouse |
| **Forces** | Tests, docs, modularité, versioning |
| **Cible** | Analytics Engineers, Data Analysts |

---

## Prochaines étapes

→ [Architecture et philosophie de DBT](./02-architecture-philosophie.md)


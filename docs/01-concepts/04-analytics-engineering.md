# Analytics Engineering

## 📋 Table des matières
1. [Définition](#définition)
2. [Origine du métier](#origine-du-métier)
3. [Responsabilités](#responsabilités)
4. [Compétences clés](#compétences-clés)
5. [Analytics Engineer vs autres rôles](#analytics-engineer-vs-autres-rôles)
6. [Workflows et outils](#workflows-et-outils)

---

## Définition

### Qu'est-ce que l'Analytics Engineering ?

L'**Analytics Engineering** est une discipline qui fait le pont entre l'ingénierie des données (Data Engineering) et l'analyse des données (Data Analytics).

```
┌──────────────────────────────────────────────────────────────────────┐
│                    LE SPECTRE DATA                                   │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Data Engineering        Analytics Engineering      Data Analytics  │
│                                                                      │
│   ┌───────────────┐      ┌───────────────────┐    ┌──────────────┐   │
│   │               │      │                   │    │              │   │
│   │ Pipelines     │      │  Transformation   │    │ Dashboards   │   │
│   │ Infrastructure│      │  Modélisation     │    │ Rapports     │   │
│   │ Ingestion     │      │  Qualité données  │    │ Insights     │   │
│   │               │      │  Documentation    │    │              │   │
│   └───────────────┘      └───────────────────┘    └──────────────┘   │
│                                                                      │
│         ▲                        ▲                       ▲           │
│         │                        │                       │           │
│   Ingénieurs              Analytics Engineers        Analystes       │
│   Python, Scala           SQL, DBT, Git              BI, Excel       │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Définition formelle

> Un **Analytics Engineer** est un professionnel qui applique les pratiques du génie logiciel (versioning, tests, documentation, CI/CD) à la transformation et à la modélisation des données analytiques.

---

## Origine du métier

### Le problème historique

**Avant l'Analytics Engineering :**

```
┌─────────────────────────────────────────────────────────────────────┐
│               SITUATION PROBLÉMATIQUE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Data Engineer                              Data Analyst           │
│   ┌─────────────────┐                       ┌─────────────────┐     │
│   │                 │                       │                 │     │
│   │ "J'ai mis les   │   GAP !               │ "J'ai besoin de │     │
│   │  données dans   │ ◄──────────────────── │  données prêtes │     │
│   │  le warehouse"  │                       │  pour analyse"  │     │
│   │                 │                       │                 │     │
│   └─────────────────┘                       └─────────────────┘     │
│          │                                           │              │
│          │                                           │              │
│          ▼                                           ▼              │
│   Données brutes                              Dashboards cassés     │
│   non exploitables                            Requêtes complexes    │
│   Pas de documentation                        Logique dupliquée     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Qui faisait les transformations ?

| Avant | Problèmes |
|-------|-----------|
| **Data Engineers** | Trop occupés par l'infrastructure |
| **Data Analysts** | SQL complexe non maintenable, pas de versioning |
| **Personne** | Chacun crée ses propres vues/tables |

### L'émergence de DBT et du rôle

**2016-2017** : Fishtown Analytics (maintenant dbt Labs) crée DBT et formalise le rôle d'Analytics Engineer.

**Le manifeste (non-officiel) :**
1. Les transformations doivent être versionnées
2. Les transformations doivent être testées
3. Les transformations doivent être documentées
4. SQL est suffisant pour 90% des transformations
5. Les analystes peuvent (et doivent) gérer leurs modèles

---

## Responsabilités

### Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────┐
│              RESPONSABILITÉS DE L'ANALYTICS ENGINEER                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. MODÉLISATION DES DONNÉES                                        │
│     └── Concevoir les modèles dimensionnels                         │
│     └── Définir les faits et dimensions                             │
│     └── Optimiser pour les cas d'usage analytiques                  │
│                                                                     │
│  2. TRANSFORMATION (DBT)                                            │
│     └── Écrire les modèles SQL                                      │
│     └── Configurer les matérialisations                             │
│     └── Gérer les dépendances                                       │
│                                                                     │
│  3. QUALITÉ DES DONNÉES                                             │
│     └── Écrire les tests                                            │
│     └── Monitorer la fraîcheur                                      │
│     └── Alerter sur les anomalies                                   │
│                                                                     │
│  4. DOCUMENTATION                                                   │
│     └── Documenter les modèles                                      │
│     └── Maintenir le data dictionary                                │
│     └── Former les utilisateurs                                     │
│                                                                     │
│  5. COLLABORATION                                                   │
│     └── Travailler avec les Data Engineers (sources)                │
│     └── Travailler avec les Analysts (besoins)                      │
│     └── Standardiser les métriques                                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Responsabilité 1 : Modélisation

```sql
-- L'Analytics Engineer conçoit des modèles comme celui-ci

-- Dimension client
-- models/marts/dim_customers.sql
SELECT
    customer_id,
    customer_name,
    email,
    segment,
    first_order_date,
    total_lifetime_value,
    is_active
FROM {{ ref('int_customers') }}
```

### Responsabilité 2 : Transformation

```sql
-- Staging : nettoyage minimal
-- models/staging/stg_raw_orders.sql
SELECT
    id AS order_id,
    TRIM(customer_id) AS customer_id,
    CAST(amount AS DECIMAL(10,2)) AS order_amount,
    CAST(created_at AS TIMESTAMP) AS ordered_at
FROM {{ source('raw', 'orders') }}
WHERE id IS NOT NULL
```

### Responsabilité 3 : Tests

```yaml
# schema.yml
models:
  - name: fct_orders
    description: "Table de faits des commandes"
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      - name: order_amount
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
```

### Responsabilité 4 : Documentation

```yaml
# schema.yml
models:
  - name: fct_orders
    description: |
      Table de faits contenant toutes les commandes.
      
      **Grain** : Une ligne par commande
      **Mise à jour** : Quotidienne à 6h UTC
      **Source** : Système e-commerce Shopify
      
    columns:
      - name: order_id
        description: "Identifiant unique de la commande (PK)"
      - name: order_amount
        description: "Montant total de la commande en EUR TTC"
```

---

## Compétences clés

### Compétences techniques

```
┌─────────────────────────────────────────────────────────────────────┐
│                    COMPÉTENCES TECHNIQUES                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  SQL (Avancé)                                                       │
│  ├── Window functions                                               │
│  ├── CTEs complexes                                                 │
│  ├── Optimisation de requêtes                                       │
│  └── Dialectes (Snowflake, BigQuery, etc.)                          │
│                                                                     │
│  DBT                                                                │
│  ├── Models et matérialisations                                     │
│  ├── Macros et Jinja                                                │
│  ├── Tests et documentation                                         │
│  └── Packages                                                       │
│                                                                     │
│  Git                                                                │
│  ├── Branching (feature branches)                                   │
│  ├── Pull requests                                                  │
│  └── CI/CD basics                                                   │
│                                                                     │
│  Data Modeling                                                      │
│  ├── Star schema                                                    │
│  ├── Snowflake schema                                               │
│  ├── Data Vault (optionnel)                                         │
│  └── Normalisation / Dénormalisation                                │
│                                                                     │
│  Python (Bonus)                                                     │
│  ├── Pandas pour prototypage                                        │
│  └── Scripts d'automatisation                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Compétences non-techniques

| Compétence | Application |
|------------|-------------|
| **Communication** | Traduire les besoins métier en modèles |
| **Documentation** | Rendre les données compréhensibles |
| **Collaboration** | Travailler avec multiples équipes |
| **Autonomie** | Gérer ses propres projets |
| **Rigueur** | Tests, validation, qualité |

---

## Analytics Engineer vs autres rôles

### Comparaison détaillée

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          COMPARAISON DES RÔLES                               │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Aspect           Data Engineer    Analytics Engineer   Data Analyst         │
│  ────────────────────────────────────────────────────────────────────────────│
│                                                                              │
│  Focus            Infrastructure   Transformation       Insights             │
│                   & Pipelines      & Modélisation       & Reporting          │
│                                                                              │
│  Output           Tables raw       Tables marts         Dashboards           │
│                   dans warehouse   prêtes à l'emploi    & Rapports           │
│                                                                              │
│  Langages         Python, Scala    SQL, Jinja           SQL, Excel           │
│                   Java, Spark      (un peu Python)      BI tools             │
│                                                                              │
│  Outils           Airflow, Spark   DBT, Git             Tableau, Looker      │
│                   Kafka, AWS       dbt Cloud            Power BI, Metabase   │
│                                                                              │
│  Préoccupation    "Les données     "Les données sont    "Les données         │
│  principale       arrivent-elles?" correctes et         répondent-elles      │
│                                    documentées?"        aux questions?"      │
│                                                                              │
│  Background       CS, Software     Mix: Analyst +       Business, Stats      │
│  typique          Engineering      Engineering          Finance              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Qui fait quoi dans le pipeline ?

```
┌─────────────────────────────────────────────────────────────────────┐
│                     RESPONSABILITÉS PIPELINE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│ Sources → Ingestion → Raw → Staging → Marts → BI → Insights         │
│           ─────────   ───   ───────   ─────   ──   ────────         │
│              │         │       │        │      │      │             │
│              ▼         ▼       ▼        ▼      ▼      ▼             │
│                                                                     │
│           Data      Data    Analytics  Analytics  Data    Data      │
│           Engineer  Eng.    Engineer   Engineer   Analyst Analyst   │
│                                                                     │
│           ◄────────────────►◄───────────────────►◄──────────────►   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Chevauchements

Il y a des **zones grises** :

| Zone | Qui ? |
|------|-------|
| Configuration de l'ingestion | Data Engineer OU Analytics Engineer |
| Création de dashboards simples | Analytics Engineer OU Data Analyst |
| Modèles ML simples | Analytics Engineer OU Data Scientist |

---

## Workflows et outils

### Stack typique de l'Analytics Engineer

```
┌─────────────────────────────────────────────────────────────────────┐
│                    STACK ANALYTICS ENGINEER                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Transformation          IDE              Versioning                │
│  ┌────────────┐         ┌────────────┐   ┌────────────┐             │
│  │    DBT     │         │  VS Code   │   │   GitHub   │             │
│  │            │         │    +       │   │     /      │             │
│  │  dbt Core  │         │ Extensions │   │  GitLab    │             │
│  │  dbt Cloud │         │            │   │            │             │
│  └────────────┘         └────────────┘   └────────────┘             │
│                                                                     │
│  Warehouse              CI/CD             Documentation             │
│  ┌────────────┐         ┌────────────┐   ┌────────────┐             │
│  │ Snowflake  │         │  GitHub    │   │ dbt Docs   │             │
│  │ BigQuery   │         │  Actions   │   │            │             │
│  │ Redshift   │         │     /      │   │ Confluence │             │
│  │ Databricks │         │  dbt Cloud │   │ Notion     │             │
│  └────────────┘         └────────────┘   └────────────┘             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Workflow quotidien type

```
┌─────────────────────────────────────────────────────────────────────
│                 JOURNÉE TYPE D'UN ANALYTICS ENGINEER                
├─────────────────────────────────────────────────────────────────────
│                                                                     
│  09:00  📊  Vérifier les runs nocturnes (tests, freshness)          
│                                                                     
│  09:30  🔧  Corriger les erreurs si nécessaire                      
│                                                                     
│  10:00  📝  Standup avec l'équipe data                              
│                                                                     
│  10:30  💻  Développement de nouveaux modèles                       
│             - Créer une branche                                     
│             - Écrire le SQL                                         
│             - Ajouter les tests                                     
│             - Documenter                                            
│                                                                     
│  12:00  🍽️  Déjeuner                                                
│                                                                     
│  13:00  👥  Réunion avec équipe Business                            
│             - Comprendre les besoins                                
│             - Définir les métriques                                 
│                                                                     
│  14:00  🔍  Code review des PRs de l'équipe                         
│                                                                     
│  15:00  💻  Suite du développement                                  
│             - dbt run                                               
│             - dbt test                                              
│                                                                     
│  16:30  📚  Documentation / Formation                              
│                                                                     
│  17:00  ✅  Push, création PR, merge                            
│                                                                     
└─────────────────────────────────────────────────────────────────────
```

### Commandes DBT quotidiennes

```bash
# Développement
dbt run --select my_new_model        # Exécuter un modèle
dbt run --select +my_new_model       # + ses dépendances amont
dbt test --select my_new_model       # Tester
dbt docs generate && dbt docs serve  # Documenter

# Validation avant PR
dbt build --select state:modified+   # Build ce qui a changé
dbt compile                          # Vérifier la compilation

# Debug
dbt debug                            # Vérifier la connexion
dbt show --select my_model           # Prévisualiser les résultats
```

---

## Résumé

| Aspect | Description |
|--------|-------------|
| **Définition** | Pont entre Data Engineering et Data Analytics |
| **Mission** | Transformer les données brutes en données exploitables |
| **Outils** | DBT, Git, SQL, Cloud Warehouses |
| **Compétences** | SQL avancé, modélisation, tests, documentation |
| **Collaboration** | Data Engineers (amont), Analysts (aval) |
| **Valeur ajoutée** | Qualité, maintenabilité, documentation |

---

## Prochaines étapes

→ [Installation de DBT](../02-installation-configuration/01-installation-dbt.md)


# Paradigme ELT vs ETL

## 📋 Table des matières
1. [Définitions](#définitions)
2. [ETL : L'approche traditionnelle](#etl--lapproche-traditionnelle)
3. [ELT : L'approche moderne](#elt--lapproche-moderne)
4. [Comparaison détaillée](#comparaison-détaillée)
5. [Pourquoi DBT est ELT](#pourquoi-dbt-est-elt)
6. [Cas d'usage et choix](#cas-dusage-et-choix)

---

## Définitions

### ETL : Extract, Transform, Load

```
┌──────────────────────────────────────────────────────────────────────┐
│                           ETL                                        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   SOURCES              SERVEUR ETL              DESTINATION          │
│                                                                      │
│  ┌────────┐           ┌─────────────┐          ┌────────────┐        │
│  │Database│──Extract─>│             │          │            │        │
│  └────────┘           │  Transform  │──Load───>│  Warehouse │        │
│  ┌────────┐           │   (ici!)    │          │            │        │
│  │  API   │──Extract─>│             │          └────────────┘        │
│  └────────┘           └─────────────┘                                │
│  ┌────────┐                ▲                                         │
│  │ Files  │──Extract───────┘                                         │
│  └────────┘                                                          │
│                                                                      │
│  Ordre : E → T → L                                                   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Les transformations se font AVANT le chargement**, sur un serveur intermédiaire.

### ELT : Extract, Load, Transform

```
┌──────────────────────────────────────────────────────────────────────┐
│                           ELT                                        │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   SOURCES              INGESTION               WAREHOUSE             │
│                                                                      │
│  ┌────────┐           ┌─────────────┐          ┌────────────────┐    │
│  │Database│──Extract─>│             │          │    Transform   │    │
│  └────────┘           │    Load     │──Load───>│     (ici!)     │    │
│  ┌────────┐           │   direct    │          │                │    │
│  │  API   │──Extract─>│             │          │    ┌──────┐    │    │
│  └────────┘           └─────────────┘          │    │ DBT  │    │    │
│  ┌────────┐                                    │    └──────┘    │    │
│  │ Files  │──────────────Load────────────────> │                │    │
│  └────────┘                                    └────────────────┘    │
│                                                                      │
│  Ordre : E → L → T                                                   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Les transformations se font APRÈS le chargement**, directement dans le warehouse.

---

## ETL : L'approche traditionnelle

### Historique

L'ETL est né dans les années 90 avec les **data warehouses on-premise** :
- Stockage coûteux (disques locaux)
- Puissance de calcul limitée
- Licences par volume de données

### Outils ETL classiques

| Outil | Éditeur | Type |
|-------|---------|------|
| Informatica | Informatica | Enterprise |
| DataStage | IBM | Enterprise |
| Talend | Talend | Open source |
| SSIS | Microsoft | Enterprise |
| Pentaho | Hitachi | Open source |

### Architecture ETL typique

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SERVEUR ETL (Dédié)                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Pipeline ETL                               │  │
│  │                                                               │  │
│  │  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐    │  │
│  │  │  Source  │──>│  Filter  │──>│  Join    │──>│Aggregate │    │  │
│  │  │ Adapter  │   │ Nulls    │   │ Tables   │   │  Data    │    │  │
│  │  └──────────┘   └──────────┘   └──────────┘   └──────────┘    │  │
│  │                                                      │        │  │
│  │                                                      ▼        │  │
│  │                                              ┌──────────┐     │  │
│  │                                              │   Write  │     │  │
│  │                                              │ to Target│     │  │
│  │                                              └──────────┘     │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  - RAM nécessaire pour les transformations                          │
│  - CPU pour les calculs                                             │
│  - Stockage temporaire                                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Avantages de l'ETL

| Avantage | Explication |
|----------|-------------|
| **Données propres au chargement** | Seules les données transformées arrivent dans le warehouse |
| **Moins de stockage warehouse** | Pas de données brutes dans le warehouse |
| **Transformation puissante** | Langages procéduraux (Java, Python) disponibles |

### Inconvénients de l'ETL

| Inconvénient | Impact |
|--------------|--------|
| **Serveur dédié** | Coût d'infrastructure |
| **Goulot d'étranglement** | Scalabilité limitée |
| **Perte de données brutes** | Impossible de re-transformer |
| **Complexité** | Outils propriétaires souvent complexes |

---

## ELT : L'approche moderne

### Contexte d'émergence

L'ELT s'est imposé avec :
- **Cloud warehouses** (Snowflake, BigQuery, Redshift)
- **Stockage quasi-illimité et peu coûteux**
- **Compute élastique** (scale on demand)
- **Séparation compute/storage**

### La révolution du Cloud Warehouse

```
┌──────────────────────────────────────────────────────────────────────┐
│              CLOUD DATA WAREHOUSE (Ex: Snowflake)                    │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌───────────────────────────────────────────────────────────── ┐    │
│  │                    COMPUTE (Virtual Warehouses)              │    │
│  │                                                              │    │
│  │   ┌─────────┐    ┌─────────┐    ┌──────────┐                 │    │
│  │   │  XS     │    │   M     │    │   XL     │  ← Scale UP     │    │
│  │   │ (1 node)│    │(4 nodes)│    │(16 nodes)│                 │    │
│  │   └─────────┘    └─────────┘    └──────────┘                 │    │
│  │                                                              │    │
│  │   Facturation : à l'usage (secondes)                         │    │
│  │   Scalabilité : instantanée                                  │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                              ▲                                       │
│                              │ Query                                 │
│                              ▼                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │                    STORAGE (Illimité)                        │    │
│  │                                                              │    │
│  │   Coût : ~$20-40/TB/mois                                     │    │
│  │   Capacité : Pétaoctets                                      │    │
│  │                                                              │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Avantages de l'ELT

| Avantage | Explication |
|----------|-------------|
| **Données brutes préservées** | Possibilité de re-transformer |
| **Pas de serveur intermédiaire** | Réduction des coûts d'infrastructure |
| **Scalabilité native** | Le warehouse gère le compute |
| **Transformations SQL** | Accessibles aux analystes |
| **Audit trail** | Historique complet des données brutes |

### Stack ELT typique

```
┌──────────────────────────────────────────────────────────────────────┐
│                        STACK ELT MODERNE                             │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  EXTRACT + LOAD                    TRANSFORM                         │
│  (Ingestion)                       (Analytics)                       │
│                                                                      │
│  ┌──────────────────┐             ┌──────────────────┐               │
│  │                  │             │                  │               │
│  │   • Fivetran     │             │     • DBT        │               │
│  │   • Airbyte      │             │     • Dataform   │               │
│  │   • Stitch       │─────────────│                  │               │
│  │   • Hevo         │   Warehouse │                  │               │
│  │                  │   au milieu │                  │               │
│  └──────────────────┘             └──────────────────┘               │
│                                                                      │
│                    ┌──────────────────────┐                          │
│                    │   Snowflake          │                          │
│                    │   BigQuery           │                          │
│                    │   Redshift           │                          │
│                    │   Databricks         │                          │
│                    └──────────────────────┘                          │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Comparaison détaillée

### Tableau comparatif

| Critère | ETL | ELT |
|---------|-----|-----|
| **Ordre** | Extract → Transform → Load | Extract → Load → Transform |
| **Où transformer ?** | Serveur ETL dédié | Dans le warehouse |
| **Données brutes** | Non conservées | Conservées |
| **Scalabilité** | Limitée (serveur) | Élastique (cloud) |
| **Coût compute** | Serveur permanent | À l'usage |
| **Langage** | Procédural (Java, etc.) | SQL |
| **Accessibilité** | Ingénieurs ETL | Analystes + Ingénieurs |
| **Latence** | Plus longue | Plus courte |
| **Données sensibles** | Filtrées avant warehouse | Filtrées après (attention!) |

### Schéma de comparaison

```
ETL (Traditionnel)
==================
                    Serveur ETL
                    ┌─────────────────┐
Sources ──Extract──>│   Transform     │──Load──> Warehouse
                    │ (Données filtrées)│         (Données finales)
                    └─────────────────┘

ELT (Moderne)  
============
Sources ──Extract──> Warehouse ──Transform──> Marts
                    (Données brutes)   (via DBT)  (Données finales)
                         │
                         └──> Conservation de l'historique brut
```

---

## Pourquoi DBT est ELT

### Positionnement de DBT

DBT est un outil **purement Transformation** :

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│   E (Extract)         L (Load)              T (Transform)           │
│   ┌─────────┐        ┌─────────┐           ┌─────────────┐          │
│   │Fivetran │        │         │           │             │          │
│   │Airbyte  │───────>│Warehouse│──────────>│    DBT      │          │
│   │Stitch   │        │         │           │             │          │
│   └─────────┘        └─────────┘           └─────────────┘          │
│                                                                     │
│   DBT ne fait PAS     DBT ne fait PAS      DBT fait UNIQUEMENT      │
│   l'extraction        le chargement        la transformation        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### DBT exploite le warehouse

```sql
-- DBT compile ce code
SELECT
    customer_id,
    SUM(amount) AS total_spent
FROM {{ ref('stg_orders') }}
GROUP BY 1

-- En SQL exécuté DANS le warehouse
CREATE OR REPLACE VIEW analytics.total_customer_spend AS (
    SELECT
        customer_id,
        SUM(amount) AS total_spent
    FROM analytics.stg_orders
    GROUP BY 1
);
```

**DBT n'extrait pas les données du warehouse**. Il envoie des commandes SQL qui sont exécutées par le warehouse lui-même.

### Avantages pour DBT

| Aspect | Bénéfice |
|--------|----------|
| **Performance** | Le warehouse optimise les requêtes |
| **Pas de data movement** | Les données restent dans le warehouse |
| **Scalabilité** | Compute du warehouse élastique |
| **Coût** | Facturation warehouse uniquement |

---

## Cas d'usage et choix

### Quand choisir ETL ?

| Situation | Raison |
|-----------|--------|
| **Legacy on-premise** | Pas de cloud warehouse disponible |
| **Données ultra-sensibles** | RGPD, anonymisation AVANT stockage |
| **Transformations non-SQL** | ML, NLP complexes |
| **Budget compute limité** | Transformer une fois, stocker le résultat |

### Quand choisir ELT (et donc DBT) ?

| Situation | Raison |
|-----------|--------|
| **Cloud warehouse** | Snowflake, BigQuery, Redshift, Databricks |
| **Équipe Data moderne** | Analytics engineers, data analysts SQL |
| **Besoin de flexibilité** | Re-transformer les données historiques |
| **Audit et traçabilité** | Conserver les données brutes |
| **Budget élastique** | Payer le compute à l'usage |

### Approche hybride

Dans la réalité, beaucoup d'organisations utilisent une **approche hybride** :

```
┌─────────────────────────────────────────────────────────────────────┐
│                      APPROCHE HYBRIDE                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Sources     ETL Léger        Warehouse          ELT (DBT)          │
│             (Ingestion)       (Raw Data)         (Transform)        │
│                                                                     │
│  ┌─────┐    ┌─────────┐      ┌─────────┐       ┌─────────────┐      │
│  │ API │───>│Fivetran │─────>│  raw_*  │──────>│  stg_*      │      │
│  └─────┘    │         │      │ tables  │       │  marts_*    │      │
│             │ Minimal │      │         │       │             │      │
│  ┌─────┐    │transform│      │         │       │  DBT gère   │      │
│  │ DB  │───>│(typage) │─────>│         │──────>│  le reste   │      │
│  └─────┘    └─────────┘      └─────────┘       └─────────────┘      │
│                                                                     │
│  - Fivetran fait le typage minimal                                  │
│  - DBT fait la logique métier                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Résumé

| Aspect | ETL | ELT |
|--------|-----|-----|
| **Époque** | Années 90-2010 | 2015+ |
| **Infrastructure** | On-premise | Cloud |
| **Transform** | Serveur dédié | Dans le warehouse |
| **Outil phare** | Informatica | DBT |
| **Compétences** | ETL developers | Analytics Engineers |
| **Données brutes** | Perdues | Conservées |

---

## Prochaines étapes

→ [Analytics Engineering](./04-analytics-engineering.md)


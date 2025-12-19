# Définition des Exposures

## 📋 Table des matières
1. [Concept des exposures](#concept-des-exposures)
2. [Configuration](#configuration)
3. [Types d'exposures](#types-dexposures)
4. [Intégration au lineage](#intégration-au-lineage)
5. [Bonnes pratiques](#bonnes-pratiques)

---

## Concept des exposures

### Qu'est-ce qu'une exposure ?

Une **exposure** définit comment vos données sont utilisées en dehors de DBT (dashboards, applications, ML, etc.).

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONCEPT D'EXPOSURE                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   DBT (Transformation)              Consommation                     │
│   ┌─────────────────────┐          ┌─────────────────────────────┐  │
│   │                     │          │                             │  │
│   │  stg_orders         │          │  📊 Tableau Dashboard       │  │
│   │       │             │          │                             │  │
│   │       ▼             │   ────>  │  📈 Looker Report           │  │
│   │  fct_orders         │ exposure │                             │  │
│   │       │             │          │  🤖 ML Model                │  │
│   │       ▼             │          │                             │  │
│   │  dim_customers      │          │  📱 Application             │  │
│   │                     │          │                             │  │
│   └─────────────────────┘          └─────────────────────────────┘  │
│                                                                      │
│   Les exposures documentent les consommateurs de vos données        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Pourquoi utiliser les exposures ?

| Avantage | Description |
|----------|-------------|
| **Lineage complet** | Voir où les données sont utilisées |
| **Impact analysis** | Savoir ce qui est affecté par un changement |
| **Documentation** | Catalogue des utilisations |
| **Communication** | Liens vers les dashboards/apps |
| **Ownership** | Qui est responsable de quoi |

---

## Configuration

### Emplacement

```
my_project/
├── models/
│   ├── marts/
│   │   └── core/
│   │       ├── fct_orders.sql
│   │       └── dim_customers.sql
│   └── exposures.yml           ◄── Fichier exposures
└── dbt_project.yml
```

### Syntaxe de base

```yaml
# models/exposures.yml

version: 2

exposures:
  - name: weekly_revenue_dashboard
    type: dashboard
    maturity: high
    
    owner:
      name: "Analytics Team"
      email: analytics@company.com
    
    description: |
      Dashboard hebdomadaire des revenus.
      Utilisé par l'équipe Finance chaque lundi.
    
    depends_on:
      - ref('fct_orders')
      - ref('dim_customers')
      - ref('dim_date')
    
    url: https://tableau.company.com/views/weekly_revenue
    
    tags: ['finance', 'weekly']
    
    meta:
      priority: high
      refresh_frequency: daily
```

### Syntaxe complète

```yaml
exposures:
  - name: customer_360_app
    label: "Customer 360 Application"  # Nom d'affichage
    type: application
    maturity: high
    
    owner:
      name: "Product Team"
      email: product@company.com
    
    description: |
      # Customer 360 Application
      
      Application interne affichant une vue 360° de chaque client.
      
      ## Fonctionnalités
      - Historique des commandes
      - Métriques de lifetime value
      - Segmentation
      
      ## SLA
      - Données mises à jour toutes les heures
      - Disponibilité : 99.9%
      
      ## Contact
      - Slack : #product-support
      - Jira : PROD-123
    
    depends_on:
      - ref('dim_customers')
      - ref('fct_orders')
      - ref('fct_customer_metrics')
      - source('crm', 'interactions')
    
    url: https://app.company.com/customer360
    
    tags: ['customer', 'application', 'production']
    
    meta:
      team: product
      tier: critical
      data_freshness_sla: "1 hour"
      support_channel: "#product-support"
```

---

## Types d'exposures

### Types disponibles

| Type | Description | Exemple |
|------|-------------|---------|
| `dashboard` | Tableau de bord BI | Tableau, Looker, Power BI |
| `notebook` | Notebook d'analyse | Jupyter, Databricks |
| `analysis` | Analyse ad-hoc | SQL queries, Sheets |
| `ml` | Modèle ML | Feature store, prédictions |
| `application` | Application | Web app, API |

### Exemples par type

#### Dashboard

```yaml
- name: executive_kpi_dashboard
  type: dashboard
  maturity: high
  owner:
    name: BI Team
    email: bi@company.com
  description: "KPIs exécutifs - présenté au board mensuel"
  depends_on:
    - ref('fct_revenue')
    - ref('fct_orders')
    - ref('dim_date')
  url: https://tableau.company.com/executive_kpis
```

#### Notebook

```yaml
- name: churn_analysis_notebook
  type: notebook
  maturity: medium
  owner:
    name: Data Science Team
    email: ds@company.com
  description: "Analyse exploratoire du churn client"
  depends_on:
    - ref('fct_customer_events')
    - ref('dim_customers')
  url: https://databricks.company.com/notebooks/churn_analysis
```

#### ML Model

```yaml
- name: churn_prediction_model
  type: ml
  maturity: high
  owner:
    name: ML Team
    email: ml@company.com
  description: |
    Modèle de prédiction du churn.
    - Algorithm : XGBoost
    - Accuracy : 87%
    - Retrained weekly
  depends_on:
    - ref('ml_features_customers')
    - ref('fct_customer_events')
  url: https://mlflow.company.com/models/churn_v3
  meta:
    model_version: "v3.2.1"
    training_frequency: weekly
```

#### Application

```yaml
- name: customer_portal
  type: application
  maturity: high
  owner:
    name: Engineering Team
    email: eng@company.com
  description: "Portail client - affiche historique commandes"
  depends_on:
    - ref('fct_orders')
    - ref('dim_products')
  url: https://portal.company.com
```

### Maturity levels

| Level | Description |
|-------|-------------|
| `high` | Production, critique |
| `medium` | Utilisé régulièrement |
| `low` | Expérimental, en développement |

---

## Intégration au lineage

### Visualisation dans dbt docs

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LINEAGE AVEC EXPOSURES                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   Sources     Models          Exposures                              │
│                                                                      │
│   🟢 raw     🔵 stg_orders    🟡 revenue_dashboard                  │
│     │              │                    ▲                            │
│     └──────────────┤                    │                            │
│                    ▼                    │                            │
│              🔵 fct_orders ─────────────┤                            │
│                    │                    │                            │
│                    │                    │                            │
│   🟢 raw     🔵 stg_customers           │                            │
│     │              │                    │                            │
│     └──────────────┤                    │                            │
│                    ▼                    │                            │
│              🔵 dim_customers ──────────┘                            │
│                    │                                                 │
│                    └─────────────> 🟡 customer_app                   │
│                                                                      │
│   🟢 = Source   🔵 = Model   🟡 = Exposure                          │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Sélection par exposure

```bash
# Exécuter les models nécessaires pour un exposure
dbt run --select +exposure:weekly_revenue_dashboard

# Tester les models d'un exposure
dbt test --select +exposure:weekly_revenue_dashboard

# Voir ce qui dépend d'un model (incluant exposures)
dbt ls --select fct_orders+
```

---

## Bonnes pratiques

### Organisation

```yaml
# Un fichier par domaine
models/
├── marts/
│   ├── finance/
│   │   └── exposures.yml      # Exposures finance
│   ├── marketing/
│   │   └── exposures.yml      # Exposures marketing
│   └── product/
│       └── exposures.yml      # Exposures produit
```

### Nommage

```yaml
# Convention : <domaine>_<type>_<description>
- name: finance_dashboard_weekly_revenue
- name: marketing_report_campaign_performance
- name: ml_model_churn_prediction
```

### Documentation complète

```yaml
- name: critical_dashboard
  description: |
    ## Description
    Dashboard critique pour le reporting financier.
    
    ## Audience
    - CFO
    - Finance Team
    - Board of Directors
    
    ## Fréquence de mise à jour
    - Données : quotidienne (6h UTC)
    - Dashboard : temps réel
    
    ## SLA
    - Disponibilité : 99.9%
    - Données fraîches : < 6h
    
    ## Support
    - Slack : #bi-support
    - Email : bi-team@company.com
    
    ## Changelog
    - 2024-01: Ajout métrique ARR
    - 2023-11: Création initiale
```

### Liens et URLs

```yaml
- name: my_dashboard
  url: https://tableau.company.com/views/dashboard_name
  
  meta:
    # Liens additionnels
    confluence_doc: https://wiki.company.com/page/123
    jira_project: https://jira.company.com/projects/BI
    slack_channel: https://company.slack.com/channels/bi-support
```

### Tags cohérents

```yaml
exposures:
  - name: finance_dashboard
    tags: ['finance', 'dashboard', 'critical', 'weekly']
    
  - name: marketing_report
    tags: ['marketing', 'report', 'daily']
```

---

## Résumé

### Structure minimale

```yaml
exposures:
  - name: my_exposure
    type: dashboard
    owner:
      email: owner@company.com
    depends_on:
      - ref('my_model')
```

### Types

| Type | Icône | Usage |
|------|-------|-------|
| `dashboard` | 📊 | Tableaux de bord |
| `notebook` | 📓 | Analyses |
| `ml` | 🤖 | Modèles ML |
| `application` | 📱 | Applications |
| `analysis` | 📈 | Analyses ad-hoc |

### Checklist

- [ ] Toutes les consommations critiques documentées
- [ ] Owner défini pour chaque exposure
- [ ] URL vers la ressource
- [ ] Dépendances (depends_on) complètes
- [ ] Maturity level approprié
- [ ] Tags cohérents

---

## Prochaines étapes

→ [Conventions et style](../13-bonnes-pratiques/01-conventions-style.md)


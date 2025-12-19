# Génération de la Documentation DBT

## 📋 Table des matières
1. [Commandes de génération](#commandes-de-génération)
2. [Le site de documentation](#le-site-de-documentation)
3. [Personnalisation](#personnalisation)
4. [Hébergement](#hébergement)
5. [Bonnes pratiques](#bonnes-pratiques)

---

## Commandes de génération

### dbt docs generate

Génère les fichiers de documentation.

```bash
# Générer la documentation
dbt docs generate
```

**Fichiers générés dans `target/` :**
```
target/
├── catalog.json       # Métadonnées des tables/colonnes
├── manifest.json      # Structure du projet
├── index.html         # Page principale
└── graph.gpickle      # DAG sérialisé
```

### dbt docs serve

Lance un serveur local pour visualiser la documentation.

```bash
# Servir la documentation (port par défaut : 8080)
dbt docs serve

# Spécifier un port
dbt docs serve --port 8000

# Ouvrir automatiquement le navigateur
dbt docs serve --no-browser  # Désactiver l'ouverture auto
```

**Sortie :**
```
Running with dbt=1.7.0
Serving docs at http://localhost:8080
Press Ctrl+C to exit.
```

### Workflow complet

```bash
# 1. Compiler le projet (optionnel mais recommandé)
dbt compile

# 2. Générer la documentation
dbt docs generate

# 3. Visualiser
dbt docs serve
```

---

## Le site de documentation

### Interface

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SITE DBT DOCS                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐  ┌───────────────────────────────────────────┐ │
│  │   Navigation    │  │                 Contenu                   │ │
│  │                 │  │                                           │ │
│  │  📁 Sources 📁 │  │  ┌─────────────────────────────────────┐  │ │
│  │    shopify      │  │  │          fct_orders                 │  │ │
│  │    stripe       │  │  │                                     │  │ │
│  │                 │  │  │  Description:                       │  │ │
│  │  📁 Models 📁  │  │  │  │  Table de faits des commandes... │  │ │
│  │   staging/      │  │  │                                     │  │ │
│  │   marts/        │  │  │  Columns:                           │  │ │
│  │    └ core/      │  │  │  • order_id (PK)                    │  │ │
│  │    └ finance/   │  │  │  • customer_id                      │  │ │
│  │                 │  │  │  • amount                           │  │ │
│  │  📁 Tests 📁   │  │  │  │                                  │  │ │
│  │                 │  │  │  Referenced by:                     │  │ │
│  │  📁 Macros 📁  │  │  │  │  • dim_customers                 │  │ │
│  │                 │  │  └─────────────────────────────────────┘  │ │
│  └─────────────────┘  └───────────────────────────────────────────┘ │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    🔗 LINEAGE GRAPH 🔗                        │ │
│  │                                                                │ │
│  │   [source] ───> [stg_orders] ───> [fct_orders] ───> [expose]   │ │
│  │                                                                │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Fonctionnalités

| Fonctionnalité   | Description                       |
|------------------|-----------------------------------|
| **Navigation**   | Arborescence des resources        |
| **Recherche**    | Recherche globale                 |
| **Lineage**      | Graphe des dépendances            |
| **Descriptions** | Documentation des models/colonnes |
| **Code**         | SQL compilé visible               |
| **Tests**        | Liste des tests associés          |

### Le Lineage Graph

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LINEAGE GRAPH                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Visualisation interactive du DAG :                                 │
│                                                                     │
│  • Cliquer sur un nœud pour voir les détails                        │
│  • Filtrer par sélecteur (+model, model+, etc.)                     │
│  • Zoomer / déplacer                                                │
│  • Mettre en évidence les dépendances                               │
│                                                                     │
│  Couleurs par défaut :                                              │
│  🟢 Sources 🟢                                                     │
│  🔵 Models 🔵                                                      │
│  🟡 Exposures 🟡                                                   │
│  🔴 Tests échoués 🔴                                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Personnalisation

### Page d'accueil

Créer un fichier `__overview__.md` :

```markdown
{# models/docs/__overview__.md #}

{% docs __overview__ %}

# 🏢 Company Data Warehouse

Bienvenue dans notre documentation data !

## Quick Links

- [Core Marts](#!/model/model.my_project.fct_orders)
- [Sources](#!/source/source.my_project.shopify)

## Getting Started

```bash
# Exécuter les transformations
dbt run

# Tester les données
dbt test
```

## Team

| Nom   | Rôle               |
|-------|--------------------|
| Alice | Analytics Engineer |
| Bob   | Data Engineer      |

{% enddocs %}
```

### Assets (images, CSS)

```
models/
└── docs/
    └── assets/
        ├── logo.png
        └── diagram.png
```

Référencer dans la doc :
```markdown
{% docs __overview__ %}

![Logo](assets/logo.png)

{% enddocs %}
```

### Exposures (tableaux de bord)

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
      - ref('fct_revenue')
      - ref('dim_date')
    
    url: https://tableau.company.com/dashboard/123
```

Les exposures apparaissent dans le lineage graph.

---

## Hébergement

### Option 1 : dbt Cloud

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DBT CLOUD DOCUMENTATION                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ✅ Automatique avec dbt Cloud  ✅                                 │
│                                                                     │
│  • Mise à jour après chaque run                                     │
│  • URL persistante                                                  │
│  • Authentification intégrée                                        │
│  • Versionning                                                      │
│                                                                     │
│  URL : https://cloud.getdbt.com/accounts/{id}/documentation         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Option 2 : GitHub Pages

```yaml
# .github/workflows/docs.yml

name: Generate dbt docs

on:
  push:
    branches: [main]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install dbt
        run: pip install dbt-snowflake
      
      - name: Generate docs
        run: |
          dbt deps
          dbt docs generate --target prod
        env:
          # Secrets pour la connexion
          DBT_USER: ${{ secrets.DBT_USER }}
          DBT_PASSWORD: ${{ secrets.DBT_PASSWORD }}
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./target
```

### Option 3 : S3 + CloudFront

```bash
# Script de déploiement
#!/bin/bash

# Générer la doc
dbt docs generate --target prod

# Upload vers S3
aws s3 sync target/ s3://my-dbt-docs-bucket/ \
    --exclude "*.json" \
    --exclude "*.gpickle"

# Invalider le cache CloudFront
aws cloudfront create-invalidation \
    --distribution-id XXXXX \
    --paths "/*"
```

### Option 4 : Netlify / Vercel

```toml
# netlify.toml

[build]
  command = "pip install dbt-snowflake && dbt deps && dbt docs generate"
  publish = "target"
```

---

## Bonnes pratiques

### Mise à jour régulière

```bash
# Intégrer dans le pipeline quotidien
dbt run
dbt test
dbt docs generate
# ... déployer la doc
```

### Vérifier la qualité de la doc

```bash
# Script de vérification
#!/bin/bash

# Compter les models sans description
echo "Models sans description :"
dbt ls --resource-type model --output json | \
  jq '.[] | select(.description == null or .description == "") | .name'

# Compter les colonnes sans description
echo "Vérifier les colonnes clés..."
```

### Template de description complète

```yaml
models:
  - name: fct_orders
    description: |
      ## Description
      Table de faits des commandes validées.
      
      ## Grain
      Une ligne par commande (`order_id`).
      
      ## Mise à jour
      - **Fréquence** : Quotidienne
      - **Heure** : 6h00 UTC
      - **Job** : `daily_transform`
      
      ## Sources
      - `stg_shopify__orders`
      - `stg_stripe__payments`
      
      ## Utilisations
      - Dashboard revenus
      - Rapports financiers mensuels
      
      ## Notes
      - Exclut les commandes annulées
      - Montants en EUR TTC
      
      ## Contact
      - Owner : @analytics-team
      - Slack : #data-support
```

### Checklist documentation

- [ ] Tous les models ont une description
- [ ] Les colonnes clés sont documentées
- [ ] Le grain est explicite
- [ ] Les sources sont listées
- [ ] La page __overview__ existe
- [ ] Les exposures sont déclarées
- [ ] La doc est déployée et accessible

---

## Résumé

| Commande            | Action                    |
|---------------------|---------------------------|
| `dbt docs generate` | Créer les fichiers de doc |
| `dbt docs serve`    | Visualiser localement     |

### Hébergement recommandé

| Contexte    | Solution        |
|-------------|-----------------|
| dbt Cloud   | Automatique     |
| Open source | GitHub Pages    |
| Enterprise  | S3 + CloudFront |

---

## Prochaines étapes

→ [Syntaxe Jinja](../08-macros-jinja/01-syntaxe-jinja.md)


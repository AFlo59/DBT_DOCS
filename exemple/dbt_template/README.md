# DBT Template Project

Projet DBT d'exemple suivant les bonnes pratiques de la documentation.

## 📁 Structure du Projet

```
dbt_template/
├── dbt_project.yml          # Configuration du projet
├── profiles.exemple.yml     # Template de profil (à copier vers ~/.dbt/)
│
├── seeds/                   # Données CSV chargées en tables
│   ├── reference/           # Données de référence
│   │   ├── country_codes.csv
│   │   ├── order_status_mapping.csv
│   │   └── payment_methods.csv
│   ├── sample_data/         # Données exemple (simulent des sources)
│   │   ├── raw_customers.csv
│   │   ├── raw_products.csv
│   │   └── raw_orders.csv
│   └── _seeds.yml           # Documentation des seeds
│
├── models/                  # Modèles SQL
│   ├── staging/             # Layer staging (stg_*)
│   │   └── ecommerce/
│   │       ├── _ecommerce__sources.yml
│   │       ├── _ecommerce__models.yml
│   │       ├── stg_ecommerce__customers.sql
│   │       ├── stg_ecommerce__products.sql
│   │       └── stg_ecommerce__orders.sql
│   │
│   └── marts/               # Layer marts (fct_*, dim_*)
│       └── core/
│           ├── _core__models.yml
│           ├── dim_customers.sql
│           ├── dim_products.sql
│           └── fct_orders.sql
│
├── macros/                  # Macros Jinja réutilisables
│   ├── utils/
│   │   ├── cents_to_dollars.sql
│   │   ├── safe_divide.sql
│   │   ├── limit_in_dev.sql
│   │   └── get_custom_schema.sql
│   └── tests/
│       └── test_positive_value.sql
│
├── tests/                   # Tests singuliers
│   ├── assert_no_orphan_orders.sql
│   └── assert_revenue_is_positive.sql
│
├── snapshots/               # Snapshots SCD Type 2 (vide)
└── analyses/                # Analyses ad-hoc (vide)
```

## 🚀 Démarrage Rapide

### 1. Configurer le profil

```bash
# Copier le template de profil
cp profiles.exemple.yml ~/.dbt/profiles.yml

# Configurer les variables d'environnement
export DBT_SNOWFLAKE_ACCOUNT="votre_account"
export DBT_SNOWFLAKE_USER="votre_user"
export DBT_SNOWFLAKE_PASSWORD="votre_password"
export DBT_TARGET="dev"
```

### 2. Installer les dépendances et charger les seeds

```bash
# Se positionner dans le projet
cd dbt_template

# Installer les packages (si packages.yml existe)
dbt deps

# Charger les seeds (données CSV)
dbt seed
```

### 3. Exécuter les modèles

```bash
# Vérifier la configuration
dbt debug

# Exécuter tous les modèles
dbt run

# Exécuter les tests
dbt test

# Générer la documentation
dbt docs generate
dbt docs serve
```

## 📊 Architecture des Données

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           FLUX DE DONNÉES                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  SEEDS (Sources simulées)                                               │
│  ─────────────────────────                                              │
│  raw_customers ─────┐                                                   │
│  raw_products  ─────┼───> source('ecommerce', '*')                      │
│  raw_orders    ─────┘                                                   │
│                                                                         │
│  STAGING (Views)                                                        │
│  ───────────────                                                        │
│  stg_ecommerce__customers  ─────┐                                       │
│  stg_ecommerce__products   ─────┼───> ref('stg_*')                      │
│  stg_ecommerce__orders     ─────┘                                       │
│                                                                         │
│  MARTS (Tables)                                                         │
│  ──────────────                                                         │
│  dim_customers  ◄─── Dimension clients avec LTV                         │
│  dim_products   ◄─── Dimension produits avec ventes                     │
│  fct_orders     ◄─── Faits commandes enrichies                          │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## 🏷️ Conventions de Nommage

| Layer | Préfixe | Exemple |
|-------|---------|---------|
| Staging | `stg_<source>__<table>` | `stg_ecommerce__orders` |
| Intermediate | `int_<description>` | `int_orders_enriched` |
| Fact | `fct_<event>` | `fct_orders` |
| Dimension | `dim_<entity>` | `dim_customers` |

## 🔧 Configuration par Environnement

| Environnement | Target | Schéma | Matérialisation |
|---------------|--------|--------|-----------------|
| **Dev** | `dev` | `dbt_<user>_*` | View/Table |
| **Recette** | `rec` | `staging_rec`, `analytics_rec` | View/Table |
| **Production** | `prod` | `staging`, `analytics` | View/Table |

## 📝 Bonnes Pratiques Implémentées

### ✅ Structure
- Organisation en layers (staging → marts)
- Convention de nommage cohérente
- Un fichier YAML par source/domaine

### ✅ Qualité
- Contract enforcement sur les marts
- Tests sur les clés primaires et étrangères
- Tests singuliers pour la logique métier

### ✅ Documentation
- Description de chaque modèle et colonne
- Data types explicites (contract)
- Tags pour l'organisation

### ✅ Configuration
- Variables d'environnement pour les credentials
- Schémas dynamiques selon l'environnement
- Macros utilitaires réutilisables

## 📚 Documentation

Consultez le dossier `/docs` du projet parent pour la documentation complète sur:
- Installation et configuration
- Concepts DBT
- Bonnes pratiques
- Macros et Jinja

## 🧪 Tests

```bash
# Tous les tests
dbt test

# Tests d'un modèle spécifique
dbt test --select dim_customers

# Tests singuliers uniquement
dbt test --select test_type:singular
```

## 📈 Métriques Clés

Les marts exposent les métriques suivantes :

### dim_customers
- `lifetime_value` : Valeur vie client
- `customer_segment` : VIP, Regular, Occasional, New, Prospect
- `engagement_status` : Active, At Risk, Dormant, Churned

### fct_orders
- `net_revenue` : Revenu net (0 si annulée)
- `hours_to_ship` : Délai d'expédition
- `is_first_order` : Premier achat du client

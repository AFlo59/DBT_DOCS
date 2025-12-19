# 📚 DBT Documentation & Examples

Documentation technique complète pour **dbt (Data Build Tool)** avec des guides pratiques et un projet d'exemple fonctionnel.

---

## 🎯 Objectif

Ce repository fournit :
- Une **documentation exhaustive** sur DBT en français
- Des **guides d'installation** pas-à-pas (local et Docker)
- Un **projet d'exemple** complet suivant les bonnes pratiques

---

## 📁 Structure du Repository

```
DBT_DOCS/
│
├── 📖 docs/                    # Documentation technique complète
│   ├── 01-concepts/            # Introduction, architecture, ELT vs ETL
│   ├── 02-installation/        # Installation, dbt_project.yml, profiles.yml
│   ├── 03-structure-projet/    # Organisation, conventions de nommage
│   ├── 04-models/              # Staging, intermediate, marts, matérialisations
│   ├── 05-sources/             # Sources, freshness
│   ├── 06-tests/               # Tests génériques, singuliers, personnalisés
│   ├── 07-documentation/       # Documentation des modèles
│   ├── 08-macros-jinja/        # Syntaxe Jinja, macros, packages
│   ├── 09-seeds/               # Utilisation des seeds
│   ├── 10-snapshots/           # SCD Type 2, configuration
│   ├── 11-hooks-operations/    # Hooks, run-operation
│   ├── 12-exposures/           # Exposures
│   └── 13-bonnes-pratiques/    # Style, performance, CI/CD
│
├── 🚀 guide/                   # Guides d'installation pratiques
│   ├── 01-installation-locale-venv.md
│   ├── 02-installation-docker.md
│   └── 03-validation-projet.md
│
├── 💡 exemple/                 # Projet DBT d'exemple complet
│   ├── dbt_template/           # Projet DBT fonctionnel
│   ├── env.exemple             # Template variables d'environnement
│   └── requirements.txt        # Dépendances Python
│
└── roadmap.md                  # Roadmap du projet
```

---

## 📖 Documentation

### Parcours recommandé

| Ordre | Section | Description |
|-------|---------|-------------|
| 1 | [Concepts](docs/01-concepts/) | Comprendre DBT, ELT, Analytics Engineering |
| 2 | [Installation](docs/02-installation-configuration/) | Configurer DBT et les profils |
| 3 | [Structure](docs/03-structure-projet/) | Organiser son projet |
| 4 | [Models](docs/04-models/) | Créer des modèles staging, marts |
| 5 | [Sources](docs/05-sources/) | Définir et monitorer les sources |
| 6 | [Tests](docs/06-tests/) | Tester la qualité des données |
| 7 | [Documentation](docs/07-documentation/) | Documenter les modèles |
| 8 | [Macros](docs/08-macros-jinja/) | Créer des macros réutilisables |
| 9 | [Seeds](docs/09-seeds/) | Charger des données CSV |
| 10 | [Snapshots](docs/10-snapshots/) | Gérer l'historique (SCD Type 2) |
| 11 | [Hooks](docs/11-hooks-operations/) | Automatiser avec des hooks |
| 12 | [Exposures](docs/12-exposures/) | Documenter les consommateurs |
| 13 | [Bonnes pratiques](docs/13-bonnes-pratiques/) | Style, performance, CI/CD |

---

## 🚀 Guides d'Installation

| Guide | Description | Recommandé pour |
|-------|-------------|-----------------|
| [Installation Locale](guide/01-installation-locale-venv.md) | Python + venv | Développement quotidien |
| [Installation Docker](guide/02-installation-docker.md) | Docker + Compose | CI/CD, équipes |
| [Validation](guide/03-validation-projet.md) | Commandes de test | Tous |

### Démarrage rapide

```bash
# 1. Créer un environnement virtuel
python -m venv venv
source venv/bin/activate  # Linux/macOS
# .\venv\Scripts\Activate.ps1  # Windows

# 2. Installer DBT
pip install dbt-core dbt-snowflake

# 3. Vérifier l'installation
dbt --version
```

---

## 💡 Projet d'Exemple

Le dossier `exemple/dbt_template/` contient un projet DBT complet et fonctionnel.

### Caractéristiques

| Fonctionnalité | Implémentation |
|----------------|----------------|
| **Adaptateur** | Snowflake |
| **Layers** | Staging → Marts (fct_, dim_) |
| **Seeds** | Données de référence + exemple |
| **Sources** | Définies avec documentation |
| **Tests** | Génériques + singuliers + personnalisés |
| **Macros** | Utilitaires réutilisables |
| **Environnements** | dev / rec / prod |
| **Contract** | Enforced sur les marts |

### Structure du projet exemple

```
exemple/dbt_template/
├── dbt_project.yml              # Configuration avec schémas dynamiques
├── profiles.exemple.yml         # Template de profil multi-environnement
│
├── seeds/
│   ├── reference/               # country_codes, order_status, payment_methods
│   └── sample_data/             # raw_customers, raw_products, raw_orders
│
├── models/
│   ├── staging/ecommerce/       # stg_ecommerce__*
│   └── marts/core/              # dim_customers, dim_products, fct_orders
│
├── macros/
│   ├── utils/                   # cents_to_dollars, safe_divide, limit_in_dev
│   └── tests/                   # test_positive_value
│
└── tests/                       # Tests singuliers
```

### Utilisation

```bash
cd exemple/dbt_template

# Configurer le profil
cp profiles.exemple.yml ~/.dbt/profiles.yml

# Configurer les variables d'environnement
# (voir exemple/env.exemple)

# Exécuter
dbt debug          # Vérifier la configuration
dbt seed           # Charger les seeds
dbt run            # Exécuter les modèles
dbt test           # Lancer les tests
dbt docs generate  # Générer la documentation
dbt docs serve     # Visualiser la documentation
```

---

## 🔧 Prérequis

| Composant | Version | Obligatoire |
|-----------|---------|-------------|
| Python | 3.8+ | ✅ |
| pip | 21.0+ | ✅ |
| Git | 2.0+ | ✅ |
| Snowflake | - | Pour l'exemple |
| Docker | 20.10+ | Pour guide Docker |

---

## 📊 Diagramme d'Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ARCHITECTURE DBT                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   SOURCES (raw)          STAGING (views)         MARTS (tables)         │
│   ──────────────         ──────────────          ─────────────          │
│                                                                         │
│   ┌──────────────┐      ┌──────────────────┐    ┌────────────────┐      │
│   │raw_customers │──────│stg_ecommerce__   │    │ dim_customers  │      │
│   └──────────────┘      │    customers     │────│                │      │
│                         └──────────────────┘    │  (LTV, segment)│      │
│   ┌──────────────┐                              └────────────────┘      │
│   │raw_products  │──────┌──────────────────┐                            │
│   └──────────────┘      │stg_ecommerce__   │    ┌────────────────┐      │
│                         │    products      │────│ dim_products   │      │
│   ┌──────────────┐      └──────────────────┘    └────────────────┘      │
│   │raw_orders    │──────┌──────────────────┐                            │
│   └──────────────┘      │stg_ecommerce__   │    ┌────────────────┐      │
│                         │    orders        │────│  fct_orders    │      │
│   ┌──────────────┐      └──────────────────┘    │                │      │
│   │ Seeds (ref)  │──────────────────────────────│(enriched data) │      │
│   └──────────────┘                              └────────────────┘      │
│                                                                         │
│                                    │                                    │
│                                    ▼                                    │
│                            ┌──────────────┐                             │
│                            │   BI Tools   │                             │
│                            │   Analysts   │                             │
│                            └──────────────┘                             │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 🏷️ Conventions de Nommage

| Type | Convention | Exemple |
|------|------------|---------|
| **Staging** | `stg_<source>__<table>` | `stg_ecommerce__orders` |
| **Intermediate** | `int_<description>` | `int_orders_enriched` |
| **Fact** | `fct_<event>` | `fct_orders` |
| **Dimension** | `dim_<entity>` | `dim_customers` |
| **Snapshot** | `snap_<table>` | `snap_customers` |
| **Clé primaire** | `<entity>_id` | `customer_id` |
| **Timestamp** | `<action>_at` | `created_at` |
| **Booléen** | `is_/has_/was_` | `is_active` |

---

## 🔒 Sécurité

- ❌ Ne **jamais** committer de credentials
- ✅ Utiliser des **variables d'environnement**
- ✅ Ajouter `.env` au `.gitignore`
- ✅ Utiliser `env_var()` dans `profiles.yml`

---

## 📚 Ressources

- [Documentation officielle DBT](https://docs.getdbt.com/)
- [DBT Learn (cours gratuits)](https://courses.getdbt.com/)
- [DBT Community Slack](https://getdbt.slack.com/)
- [DBT Hub (packages)](https://hub.getdbt.com/)

---

## 🤝 Contribution

1. Fork le repository
2. Créer une branche (`git checkout -b feature/amelioration`)
3. Committer les changements (`git commit -m 'Ajout de...'`)
4. Pousser la branche (`git push origin feature/amelioration`)
5. Ouvrir une Pull Request

---

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

---

<p align="center">
  <b>Happy Data Building! 🚀</b>
</p>


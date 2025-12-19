# Maintenance et CI/CD

## 📋 Table des matières
1. [Workflows Git](#workflows-git)
2. [Tests automatisés (CI)](#tests-automatisés-ci)
3. [Déploiement (CD)](#déploiement-cd)
4. [Monitoring et alertes](#monitoring-et-alertes)
5. [Maintenance quotidienne](#maintenance-quotidienne)

---

## Workflows Git

### Branching strategy

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GIT WORKFLOW DBT                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   main (production)                                                 │
│   ────────────────────────────────────────────────────────────────  │
│        │                    │                    │                  │
│        │  merge             │  merge             │                  │
│        │                    │                    │                  │
│   feature/add-customer-dim  feature/fix-revenue                     │
│   ────────────────────────  ────────────────────                    │
│                                                                     │
│   Workflow :                                                        │
│   1. Créer une branche feature/*                                    │
│   2. Développer et tester localement                                │
│   3. Pousser et créer une PR                                        │
│   4. CI exécute les tests                                           │
│   5. Review et approbation                                          │
│   6. Merge dans main                                                │
│   7. CD déploie en production                                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Convention de nommage des branches

| Préfixe     | Usage                   | Exemple                   |
|-------------|-------------------------|---------------------------|
| `feature/`  | Nouvelle fonctionnalité | `feature/add-mrr-model`   |
| `fix/`      | Correction de bug       | `fix/revenue-calculation` |
| `refactor/` | Refactoring             | `refactor/staging-layer`  |
| `docs/`     | Documentation           | `docs/update-readme`      |

### Template de PR

```markdown
## Description
<!-- Décrivez les changements -->

## Type de changement
- [ ] Nouveau model
- [ ] Modification de model existant
- [ ] Refactoring
- [ ] Documentation
- [ ] Bug fix

## Models affectés
- `fct_orders`
- `dim_customers`

## Tests
- [ ] Tests ajoutés/mis à jour
- [ ] `dbt build` passe localement
- [ ] Documentation mise à jour

## Checklist
- [ ] Code suit les conventions de style
- [ ] Pas de breaking changes (ou documentés)
- [ ] Revue par un pair
```

---

## Tests automatisés (CI)

### GitHub Actions

```yaml
# .github/workflows/dbt-ci.yml

name: DBT CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

env:
  DBT_PROFILES_DIR: ./
  
jobs:
  dbt-test:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install dependencies
        run: |
          pip install dbt-snowflake
          dbt deps
      
      - name: Setup profiles.yml
        run: |
          cat << EOF > profiles.yml
          my_project:
            target: ci
            outputs:
              ci:
                type: snowflake
                account: ${{ secrets.SNOWFLAKE_ACCOUNT }}
                user: ${{ secrets.SNOWFLAKE_USER }}
                password: ${{ secrets.SNOWFLAKE_PASSWORD }}
                role: CI_ROLE
                warehouse: CI_WH
                database: CI_DB
                schema: ci_pr_${{ github.event.pull_request.number }}
                threads: 8
          EOF
      
      - name: Check source freshness
        run: dbt source freshness
      
      - name: Build changed models
        run: |
          dbt build --select state:modified+ --defer --state ./prod-manifest
        
      - name: Run all tests
        run: dbt test
      
      - name: Generate docs
        run: dbt docs generate
      
      - name: Cleanup CI schema
        if: always()
        run: |
          dbt run-operation cleanup_ci_schema \
            --args '{"schema": "ci_pr_${{ github.event.pull_request.number }}"}'
```

### Slim CI (state:modified)

```bash
# Ne tester que les models modifiés et leurs dépendants
dbt build --select state:modified+ --defer --state ./prod-manifest

# Générer le manifest de prod
dbt compile --target prod
cp target/manifest.json prod-manifest/manifest.json
```

### GitLab CI

```yaml
# .gitlab-ci.yml

stages:
  - test
  - deploy

variables:
  DBT_PROFILES_DIR: $CI_PROJECT_DIR

.dbt-base:
  image: python:3.10
  before_script:
    - pip install dbt-snowflake
    - dbt deps

test:
  extends: .dbt-base
  stage: test
  script:
    - dbt build --target ci
    - dbt test
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

deploy:
  extends: .dbt-base
  stage: deploy
  script:
    - dbt run --target prod
    - dbt test --target prod
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  environment:
    name: production
```

---

## Déploiement (CD)

### Stratégie de déploiement

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PIPELINE DE DÉPLOIEMENT                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   PR merged → main                                                  │
│        │                                                            │
│        ▼                                                            │
│   ┌─────────────────┐                                               │
│   │ dbt source      │ Vérifier fraîcheur des sources                │
│   │ freshness       │                                               │
│   └────────┬────────┘                                               │
│            │                                                        │
│            ▼                                                        │
│   ┌─────────────────┐                                               │
│   │ dbt run         │ Exécuter les transformations                  │
│   │ --target prod   │                                               │
│   └────────┬────────┘                                               │
│            │                                                        │
│            ▼                                                        │
│   ┌─────────────────┐                                               │
│   │ dbt test        │ Tester les données                            │
│   │ --target prod   │                                               │
│   └────────┬────────┘                                               │
│            │                                                        │
│            ▼                                                        │
│   ┌─────────────────┐                                               │
│   │ dbt docs        │ Mettre à jour la documentation                │
│   │ generate        │                                               │
│   └─────────────────┘                                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Workflow production avec Airflow

```python
# dags/dbt_production.py

from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'dbt_production',
    default_args=default_args,
    schedule_interval='0 6 * * *',  # 6h UTC daily
    start_date=datetime(2024, 1, 1),
    catchup=False,
) as dag:
    
    dbt_deps = BashOperator(
        task_id='dbt_deps',
        bash_command='cd /opt/dbt && dbt deps',
    )
    
    source_freshness = BashOperator(
        task_id='source_freshness',
        bash_command='cd /opt/dbt && dbt source freshness --target prod',
    )
    
    dbt_run = BashOperator(
        task_id='dbt_run',
        bash_command='cd /opt/dbt && dbt run --target prod',
    )
    
    dbt_test = BashOperator(
        task_id='dbt_test',
        bash_command='cd /opt/dbt && dbt test --target prod',
    )
    
    dbt_docs = BashOperator(
        task_id='dbt_docs',
        bash_command='cd /opt/dbt && dbt docs generate --target prod',
    )
    
    dbt_deps >> source_freshness >> dbt_run >> dbt_test >> dbt_docs
```

---

## Monitoring et alertes

### Alertes sur échec

```yaml
# GitHub Actions avec notification Slack
- name: Notify on failure
  if: failure()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "❌ DBT CI Failed!",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*DBT CI Failed* on `${{ github.ref }}`\n<${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|View Run>"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Monitoring de freshness

```bash
#!/bin/bash
# scripts/check_freshness.sh

# Exécuter le check de freshness
dbt source freshness --output target/sources.json

# Parser les résultats
ERRORS=$(cat target/sources.json | jq '.results[] | select(.status == "error") | .unique_id' | wc -l)

if [ $ERRORS -gt 0 ]; then
    # Envoyer une alerte
    curl -X POST $SLACK_WEBHOOK_URL \
        -H "Content-Type: application/json" \
        -d "{\"text\": \"🚨 $ERRORS sources are stale!\"}"
    exit 1
fi
```

### Dashboard de monitoring

```sql
-- Table d'audit des runs
CREATE TABLE audit.dbt_runs (
    run_id VARCHAR,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR,
    models_run INTEGER,
    models_failed INTEGER,
    tests_passed INTEGER,
    tests_failed INTEGER
);

-- Requête pour le dashboard
SELECT
    DATE(started_at) AS run_date,
    COUNT(*) AS total_runs,
    AVG(DATEDIFF('minute', started_at, completed_at)) AS avg_duration_min,
    SUM(tests_failed) AS total_failed_tests
FROM audit.dbt_runs
WHERE started_at >= DATEADD('day', -30, CURRENT_DATE)
GROUP BY 1
ORDER BY 1 DESC;
```

---

## Maintenance quotidienne

### Checklist quotidienne

```
□ VÉRIFICATIONS MATINALES
  ├── Vérifier le statut du run nocturne
  ├── Vérifier la freshness des sources
  ├── Consulter les alertes
  └── Résoudre les tests en échec

□ MAINTENANCE HEBDOMADAIRE
  ├── Revue des PR en attente
  ├── Nettoyage des branches mergées
  ├── Mise à jour des packages (dbt deps)
  └── Revue de la documentation

□ MAINTENANCE MENSUELLE
  ├── Audit des models non utilisés
  ├── Optimisation des models lents
  ├── Revue des permissions
  └── Mise à jour de DBT
```

### Script de maintenance

```bash
#!/bin/bash
# scripts/maintenance.sh

echo "=== DBT Maintenance Script ==="

# 1. Nettoyer le dossier target
echo "Cleaning target..."
dbt clean

# 2. Installer les dépendances
echo "Installing deps..."
dbt deps

# 3. Compiler et vérifier
echo "Compiling..."
dbt compile

# 4. Vérifier les sources
echo "Checking source freshness..."
dbt source freshness

# 5. Exécuter les tests
echo "Running tests..."
dbt test

# 6. Générer la documentation
echo "Generating docs..."
dbt docs generate

echo "=== Maintenance Complete ==="
```

### Rotation des secrets

```yaml
# Checklist rotation
- [ ] Mettre à jour les secrets dans CI/CD
- [ ] Mettre à jour profiles.yml local
- [ ] Tester la connexion (dbt debug)
- [ ] Communiquer à l'équipe
```

---

## Résumé

### Pipeline CI/CD minimal

```yaml
# 1. CI sur PR
- dbt build --select state:modified+
- dbt test

# 2. CD sur merge to main
- dbt source freshness
- dbt run --target prod
- dbt test --target prod
```

### Commandes essentielles

| Contexte        | Commandes                            |
|-----------------|--------------------------------------|
| **CI**          | `dbt build --select state:modified+` |
| **CD**          | `dbt run && dbt test`                |
| **Monitoring**  | `dbt source freshness`               |
| **Maintenance** | `dbt clean && dbt deps`              |

### Checklist CI/CD

- [ ] Tests automatiques sur PR
- [ ] Slim CI (state:modified)
- [ ] Déploiement automatique sur merge
- [ ] Alertes sur échec
- [ ] Monitoring de freshness
- [ ] Documentation auto-générée

---

## Conclusion

Cette documentation couvre les aspects essentiels de DBT, de l'installation à la mise en production. Référez-vous aux sections appropriées selon vos besoins et n'hésitez pas à la compléter avec les spécificités de votre projet.

**Ressources supplémentaires :**
- [Documentation officielle DBT](https://docs.getdbt.com)
- [dbt Community Slack](https://community.getdbt.com)
- [dbt Hub (packages)](https://hub.getdbt.com)


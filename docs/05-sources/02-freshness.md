# Freshness (Fraîcheur des données)

## 📋 Table des matières
1. [Concept de freshness](#concept-de-freshness)
2. [Configuration](#configuration)
3. [Exécution](#exécution)
4. [Alertes et monitoring](#alertes-et-monitoring)
5. [Bonnes pratiques](#bonnes-pratiques)

---

## Concept de freshness

### Qu'est-ce que la freshness ?

La **freshness** permet de surveiller si vos données sources sont à jour en vérifiant le timestamp de la dernière donnée chargée.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    CONCEPT DE FRESHNESS                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Source: orders                                                     │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  id    │  amount  │  _loaded_at           │                 │    │
│  │  1     │  100     │  2024-01-15 08:00:00  │                 │    │
│  │  2     │  200     │  2024-01-15 09:00:00  │                 │    │
│  │  3     │  150     │  2024-01-15 10:00:00  │  ◄── Plus récent│    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
│  Heure actuelle : 2024-01-15 11:00:00                               │
│  Dernière donnée : 2024-01-15 10:00:00                              │
│  Âge des données : 1 heure                                          │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Seuil warn_after  : 2 heures   →  ✅ OK ✅                │    │
│  │  Seuil error_after : 6 heures   →  ✅ OK ✅                │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Pourquoi surveiller la freshness ?

| Risque                | Impact                            |
|-----------------------|-----------------------------------|
| **Pipeline cassé**    | Données non mises à jour          |
| **Problème source**   | API down, erreur d'ingestion      |
| **Décisions fausses** | Dashboards avec données obsolètes |

---

## Configuration

### Configuration de base

```yaml
# _shopify__sources.yml

version: 2

sources:
  - name: shopify
    database: raw_data
    schema: shopify
    
    # Colonne contenant le timestamp de chargement
    loaded_at_field: _fivetran_synced
    
    # Seuils de fraîcheur (défaut pour toutes les tables)
    freshness:
      warn_after:
        count: 12
        period: hour
      error_after:
        count: 24
        period: hour
    
    tables:
      - name: orders
        # Hérite de la freshness par défaut
        
      - name: inventory
        # Override pour cette table (mise à jour plus fréquente)
        freshness:
          warn_after:
            count: 1
            period: hour
          error_after:
            count: 3
            period: hour
```

### Colonnes de timestamp

```yaml
# Colonne de chargement (Fivetran)
loaded_at_field: _fivetran_synced

# Colonne de chargement (Airbyte)
loaded_at_field: _airbyte_extracted_at

# Colonne métier
loaded_at_field: updated_at

# Colonne personnalisée
loaded_at_field: _loaded_timestamp
```

### Périodes disponibles

| Période  | Usage                |
|----------|----------------------|
| `minute` | Données temps réel   |
| `hour`   | Données horaires     |
| `day`    | Données quotidiennes |

### Désactiver la freshness

```yaml
tables:
  - name: static_data
    # Pas de vérification de freshness
    freshness: null
    
  - name: historical_archive
    # Table archivée, pas de mise à jour attendue
    freshness: null
```

### Filter (filtrer les données)

```yaml
tables:
  - name: events
    freshness:
      warn_after: {count: 1, period: hour}
      error_after: {count: 6, period: hour}
      # Ne vérifier que les événements récents
      filter: "event_date >= DATEADD('day', -1, CURRENT_DATE)"
```

---

## Exécution

### Commande dbt source freshness

```bash
# Vérifier la freshness de toutes les sources
dbt source freshness

# Vérifier une source spécifique
dbt source freshness --select source:shopify

# Vérifier une table spécifique
dbt source freshness --select source:shopify.orders

# Output dans un fichier
dbt source freshness --output target/sources.json
```

### Sortie de la commande

```
Running with dbt=1.7.0

Found 3 sources, checking freshness...

Source shopify.orders
  max_loaded_at: 2024-01-15 10:00:00
  snapshotted_at: 2024-01-15 11:00:00
  age: 1 hour
  status: PASS

Source shopify.customers
  max_loaded_at: 2024-01-15 08:00:00
  snapshotted_at: 2024-01-15 11:00:00
  age: 3 hours
  status: WARN

Source shopify.inventory
  max_loaded_at: 2024-01-14 18:00:00
  snapshotted_at: 2024-01-15 11:00:00
  age: 17 hours
  status: ERROR

Done. PASS=1 WARN=1 ERROR=1 TOTAL=3
```

### Statuts

| Statut    | Signification         |
|-----------|-----------------------|
| **PASS**  | Données fraîches      |
| **WARN**  | Dépasse `warn_after`  |
| **ERROR** | Dépasse `error_after` |

### Intégration dans le workflow

```bash
# Workflow typique
dbt source freshness    # 1. Vérifier que les données sont à jour
dbt run                 # 2. Exécuter les transformations
dbt test                # 3. Tester les résultats
```

---

## Alertes et monitoring

### Fichier sources.json

```bash
dbt source freshness --output target/sources.json
```

```json
{
  "metadata": {
    "generated_at": "2024-01-15T11:00:00Z"
  },
  "results": [
    {
      "unique_id": "source.my_project.shopify.orders",
      "status": "pass",
      "max_loaded_at": "2024-01-15T10:00:00Z",
      "snapshotted_at": "2024-01-15T11:00:00Z",
      "age_in_seconds": 3600
    },
    {
      "unique_id": "source.my_project.shopify.inventory",
      "status": "error",
      "max_loaded_at": "2024-01-14T18:00:00Z",
      "snapshotted_at": "2024-01-15T11:00:00Z",
      "age_in_seconds": 61200
    }
  ]
}
```

### CI/CD avec vérification freshness

```yaml
# GitHub Actions
jobs:
  dbt-run:
    steps:
      - name: Check source freshness
        run: |
          dbt source freshness
          # Échoue si ERROR
          if [ $? -ne 0 ]; then
            echo "Source freshness check failed!"
            exit 1
          fi
      
      - name: Run dbt
        run: dbt run
```

### Alertes Slack (exemple)

```python
# Script Python pour alertes
import json
import requests

def check_freshness_and_alert():
    with open('target/sources.json') as f:
        results = json.load(f)
    
    errors = [r for r in results['results'] if r['status'] == 'error']
    
    if errors:
        message = "🚨 Sources stale:\n"
        for e in errors:
            message += f"- {e['unique_id']}: {e['age_in_seconds']/3600:.1f} hours old\n"
        
        requests.post(
            "https://hooks.slack.com/...",
            json={"text": message}
        )
```

### Monitoring avec dbt Cloud

```
┌─────────────────────────────────────────────────────────────────────┐
│                    DBT CLOUD FRESHNESS                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ✅ dbt Cloud inclut nativement ✅ :                               │
│                                                                     │
│  • Exécution automatique de source freshness                        │
│  • Dashboard de monitoring                                          │
│  • Alertes email/Slack intégrées                                    │
│  • Historique des vérifications                                     │
│                                                                     │
│  Configuration dans dbt Cloud :                                     │
│  Jobs > New Job > "Source Freshness" checkbox                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Bonnes pratiques

### Définir des seuils réalistes

```yaml
# ❌ Trop strict pour des données quotidiennes
freshness:
  warn_after: {count: 1, period: hour}
  error_after: {count: 2, period: hour}

# ✅ Adapté aux données quotidiennes
freshness:
  warn_after: {count: 24, period: hour}
  error_after: {count: 48, period: hour}
```

### Adapter par type de source

```yaml
sources:
  # Données temps réel (events, logs)
  - name: segment_events
    freshness:
      warn_after: {count: 15, period: minute}
      error_after: {count: 1, period: hour}
    tables:
      - name: page_views
      - name: events
  
  # Données horaires (CRM, e-commerce)
  - name: shopify
    freshness:
      warn_after: {count: 2, period: hour}
      error_after: {count: 6, period: hour}
    tables:
      - name: orders
      - name: customers
  
  # Données quotidiennes (finance, RH)
  - name: netsuite
    freshness:
      warn_after: {count: 24, period: hour}
      error_after: {count: 48, period: hour}
    tables:
      - name: invoices
```

### Exclure les tables statiques

```yaml
tables:
  # Table de référence, rarement mise à jour
  - name: country_codes
    freshness: null
    
  # Archive historique
  - name: orders_2019
    freshness: null
```

### Utiliser le filter pour les grandes tables

```yaml
tables:
  - name: events
    loaded_at_field: event_timestamp
    freshness:
      warn_after: {count: 1, period: hour}
      error_after: {count: 6, period: hour}
      # Vérifier uniquement les 7 derniers jours
      filter: "event_date >= CURRENT_DATE - INTERVAL '7 days'"
```

### Documentation des SLA

```yaml
sources:
  - name: stripe
    description: |
      Données Stripe synchronisées par Fivetran.
      
      ## SLA de fraîcheur
      | Table     | Attendu    | Warn    | Error   |
      |-----------|------------|---------|---------|
      | payments  | < 1h       | 2h      | 6h      |
      | refunds   | < 1h       | 2h      | 6h      |
```

---

## Résumé

### Configuration type

```yaml
sources:
  - name: <source>
    loaded_at_field: _loaded_at
    freshness:
      warn_after: {count: X, period: hour}
      error_after: {count: Y, period: hour}
```

### Commandes

| Commande               | Usage                          |
|------------------------|--------------------------------|
| `dbt source freshness` | Vérifier toutes les sources    |
| `--select source:X`    | Vérifier une source spécifique |
| `--output file.json`   | Exporter les résultats         |

### Checklist

- [ ] Configurer `loaded_at_field` pour chaque source
- [ ] Définir des seuils `warn_after` et `error_after` réalistes
- [ ] Désactiver pour les tables statiques (`freshness: null`)
- [ ] Intégrer dans le pipeline CI/CD
- [ ] Configurer des alertes pour les erreurs

---

## Prochaines étapes

→ [Tests génériques](../06-tests/01-tests-generiques.md)


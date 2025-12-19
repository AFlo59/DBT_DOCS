# Guide d'Installation Docker - DBT Conteneurisé

Ce guide détaille l'installation et l'utilisation de DBT dans un environnement Docker.

---

## Table des matières

1. [Prérequis](#prérequis)
2. [Structure du Projet](#structure-du-projet)
3. [Configuration Dockerfile](#configuration-dockerfile)
4. [Docker Compose](#docker-compose)
5. [Build et Exécution](#build-et-exécution)
6. [Commandes DBT avec Docker](#commandes-dbt-avec-docker)
7. [Validation](#validation)
8. [Développement avec Volumes](#développement-avec-volumes)
9. [CI/CD avec Docker](#cicd-avec-docker)

---

## Prérequis

### Logiciels requis

| Composant      | Version minimale |
|----------------|------------------|
| Docker         | 20.10+           |
| Docker Compose | 2.0+             |

### Vérifier les prérequis

```powershell
# Vérifier Docker
docker --version

# Vérifier Docker Compose
docker compose version
```

### Installation Docker

- **Windows** : [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
- **macOS** : [Docker Desktop for Mac](https://docs.docker.com/desktop/install/mac-install/)
- **Linux** : [Docker Engine](https://docs.docker.com/engine/install/)

---

## Structure du Projet

```
mon-projet-dbt/
├── docker/
│   ├── Dockerfile
│   └── entrypoint.sh
├── docker-compose.yml
├── .dockerignore
├── .env                    # Variables d'environnement (non versionné)
├── requirements.txt
├── profiles/
│   └── profiles.yml        # Profile DBT pour Docker
├── dbt_project/            # Votre projet DBT
│   ├── models/
│   ├── macros/
│   ├── seeds/
│   ├── snapshots/
│   ├── tests/
│   ├── analyses/
│   ├── dbt_project.yml
│   └── packages.yml
└── README.md
```

---

## Configuration Dockerfile

### Dockerfile principal

Créer `docker/Dockerfile` :

```dockerfile
# =============================================================================
# Dockerfile pour DBT
# =============================================================================

# Image de base Python
FROM python:3.10-slim-bookworm

# Métadonnées
LABEL maintainer="votre-email@example.com"
LABEL description="Image Docker pour DBT avec Snowflake"
LABEL version="1.0"

# Variables d'environnement
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DBT_PROFILES_DIR=/root/.dbt

# Répertoire de travail
WORKDIR /dbt

# Installation des dépendances système
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Copie des requirements
COPY requirements.txt .

# Installation des dépendances Python
RUN pip install --upgrade pip && \
    pip install -r requirements.txt

# Création du dossier .dbt pour les profiles
RUN mkdir -p /root/.dbt

# Copie du profile DBT
COPY profiles/profiles.yml /root/.dbt/profiles.yml

# Copie du projet DBT
COPY dbt_project/ /dbt/

# Copie du script d'entrée
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Point d'entrée
ENTRYPOINT ["/entrypoint.sh"]

# Commande par défaut
CMD ["dbt", "--version"]
```

### Script d'entrée

Créer `docker/entrypoint.sh` :

```bash
#!/bin/bash
set -e

echo "=========================================="
echo "DBT Docker Container"
echo "=========================================="

# Afficher la version de DBT
echo "DBT Version:"
dbt --version

echo ""
echo "Environment: ${DBT_TARGET:-dev}"
echo "=========================================="

# Exécuter la commande passée en argument
exec "$@"
```

### Fichier .dockerignore

Créer `.dockerignore` :

```
# Git
.git
.gitignore

# Python
__pycache__
*.pyc
*.pyo
*.pyd
.Python
venv/
.venv/
*.egg-info/

# DBT artefacts
dbt_project/target/
dbt_project/dbt_packages/
dbt_project/logs/
*.log

# IDE
.vscode/
.idea/
.cursor/

# OS
.DS_Store
Thumbs.db

# Secrets
.env
*.credentials

# Documentation
*.md
!dbt_project/README.md
docs/
```

---

## Docker Compose

### Configuration docker-compose.yml

Créer `docker-compose.yml` :

```yaml
version: '3.8'

services:
  # ==========================================================================
  # Service DBT principal
  # ==========================================================================
  dbt:
    build:
      context: .
      dockerfile: docker/Dockerfile
    image: dbt-snowflake:latest
    container_name: dbt-runner
    
    # Variables d'environnement depuis .env
    env_file:
      - .env
    
    # Variables d'environnement supplémentaires
    environment:
      - DBT_TARGET=${DBT_TARGET:-dev}
      - DBT_PROFILES_DIR=/root/.dbt
    
    # Volumes pour le développement
    volumes:
      # Monter le projet DBT (développement)
      - ./dbt_project:/dbt:rw
      # Monter les profiles
      - ./profiles/profiles.yml:/root/.dbt/profiles.yml:ro
      # Persister les logs
      - ./logs:/dbt/logs:rw
      # Persister le target (optionnel)
      - ./target:/dbt/target:rw
    
    # Commande par défaut
    command: ["dbt", "debug"]
    
    # Réseau
    networks:
      - dbt-network

  # ==========================================================================
  # Service pour exécuter dbt run
  # ==========================================================================
  dbt-run:
    extends:
      service: dbt
    container_name: dbt-run
    command: ["dbt", "run"]

  # ==========================================================================
  # Service pour exécuter dbt test
  # ==========================================================================
  dbt-test:
    extends:
      service: dbt
    container_name: dbt-test
    command: ["dbt", "test"]

  # ==========================================================================
  # Service pour la documentation
  # ==========================================================================
  dbt-docs:
    extends:
      service: dbt
    container_name: dbt-docs
    ports:
      - "8080:8080"
    command: ["sh", "-c", "dbt docs generate && dbt docs serve --port 8080"]

networks:
  dbt-network:
    driver: bridge
```

### Fichier .env pour Docker

Créer `.env` à la racine :

```env
# =============================================================================
# Variables d'environnement pour Docker
# =============================================================================

# Snowflake Configuration
DBT_SNOWFLAKE_ACCOUNT=xy12345.eu-west-1
DBT_SNOWFLAKE_USER=votre_user
DBT_SNOWFLAKE_PASSWORD=votre_password
DBT_SNOWFLAKE_ROLE=TRANSFORMER
DBT_SNOWFLAKE_WAREHOUSE=COMPUTE_WH
DBT_SNOWFLAKE_DATABASE=ANALYTICS
DBT_SNOWFLAKE_SCHEMA=dev

# DBT Configuration
DBT_TARGET=dev
DBT_THREADS=4
```

---

## Configuration du Profile pour Docker

### profiles.yml pour conteneur

Créer `profiles/profiles.yml` :

```yaml
# =============================================================================
# Profile DBT pour Docker
# =============================================================================

mon_projet:
  target: "{{ env_var('DBT_TARGET', 'dev') }}"
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('DBT_SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('DBT_SNOWFLAKE_USER') }}"
      password: "{{ env_var('DBT_SNOWFLAKE_PASSWORD') }}"
      role: "{{ env_var('DBT_SNOWFLAKE_ROLE', 'TRANSFORMER') }}"
      warehouse: "{{ env_var('DBT_SNOWFLAKE_WAREHOUSE', 'COMPUTE_WH') }}"
      database: "{{ env_var('DBT_SNOWFLAKE_DATABASE', 'ANALYTICS') }}"
      schema: "{{ env_var('DBT_SNOWFLAKE_SCHEMA', 'dev') }}"
      threads: "{{ env_var('DBT_THREADS', '4') | int }}"
      client_session_keep_alive: false

    prod:
      type: snowflake
      account: "{{ env_var('DBT_SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('DBT_SNOWFLAKE_USER') }}"
      password: "{{ env_var('DBT_SNOWFLAKE_PASSWORD') }}"
      role: TRANSFORMER
      warehouse: TRANSFORMING_WH
      database: ANALYTICS
      schema: prod
      threads: 8
      client_session_keep_alive: false
```

---

## Build et Exécution

### Construire l'image Docker

```bash
# Build simple
docker compose build

# Build sans cache (forcer reconstruction)
docker compose build --no-cache

# Build avec logs détaillés
docker compose build --progress=plain
```

### Exécuter DBT

```bash
# Vérifier l'installation (debug)
docker compose run --rm dbt

# Exécuter dbt run
docker compose run --rm dbt dbt run

# Exécuter dbt test
docker compose run --rm dbt dbt test

# Utiliser les services prédéfinis
docker compose run --rm dbt-run
docker compose run --rm dbt-test
```

### Lancer la documentation

```bash
# Générer et servir la documentation
docker compose up dbt-docs

# Accéder à http://localhost:8080
```

---

## Commandes DBT avec Docker

### Commandes courantes

```bash
# Debug / Validation
docker compose run --rm dbt dbt debug

# Installer les packages
docker compose run --rm dbt dbt deps

# Compiler les modèles
docker compose run --rm dbt dbt compile

# Exécuter tous les modèles
docker compose run --rm dbt dbt run

# Exécuter un modèle spécifique
docker compose run --rm dbt dbt run --select mon_modele

# Exécuter avec un tag
docker compose run --rm dbt dbt run --select tag:daily

# Exécuter les tests
docker compose run --rm dbt dbt test

# Charger les seeds
docker compose run --rm dbt dbt seed

# Exécuter les snapshots
docker compose run --rm dbt dbt snapshot

# Nettoyer les artefacts
docker compose run --rm dbt dbt clean

# Fresh run (clean + deps + run)
docker compose run --rm dbt sh -c "dbt clean && dbt deps && dbt run"
```

### Changer d'environnement (target)

```bash
# Exécuter en production
docker compose run --rm -e DBT_TARGET=prod dbt dbt run

# Ou modifier le .env
DBT_TARGET=prod docker compose run --rm dbt dbt run
```

### Accéder au shell du conteneur

```bash
# Shell interactif
docker compose run --rm dbt bash

# Puis exécuter des commandes DBT
dbt debug
dbt run
```

---

## Validation

### 1. Vérifier le build

```bash
docker compose build
```

**Sortie attendue** : Build terminé sans erreur.

### 2. Vérifier la version DBT

```bash
docker compose run --rm dbt dbt --version
```

### 3. Valider la configuration

```bash
docker compose run --rm dbt dbt debug
```

**Sortie attendue** :

```
Configuration:
  profiles.yml file [OK found and valid]
  dbt_project.yml file [OK found and valid]

Connection:
  Connection test: [OK connection ok]

All checks passed!
```

### 4. Exécuter les modèles d'exemple

```bash
docker compose run --rm dbt dbt run
```

### 5. Exécuter les tests

```bash
docker compose run --rm dbt dbt test
```

---

## Développement avec Volumes

### Mode développement (hot reload)

Les volumes dans `docker-compose.yml` permettent de modifier le code localement et de l'exécuter immédiatement dans Docker :

```yaml
volumes:
  - ./dbt_project:/dbt:rw  # Montage en lecture-écriture
```

### Workflow de développement

1. **Modifier les fichiers localement** (dans `dbt_project/`)
2. **Exécuter via Docker** :

```bash
docker compose run --rm dbt dbt run --select mon_nouveau_modele
```

3. **Les artefacts sont générés dans** `./target/` et `./logs/`

### Script de développement

Créer `scripts/dev.sh` (ou `dev.ps1` pour Windows) :

```bash
#!/bin/bash
# Script de développement DBT

case "$1" in
  run)
    docker compose run --rm dbt dbt run "${@:2}"
    ;;
  test)
    docker compose run --rm dbt dbt test "${@:2}"
    ;;
  debug)
    docker compose run --rm dbt dbt debug
    ;;
  compile)
    docker compose run --rm dbt dbt compile "${@:2}"
    ;;
  docs)
    docker compose up dbt-docs
    ;;
  shell)
    docker compose run --rm dbt bash
    ;;
  fresh)
    docker compose run --rm dbt sh -c "dbt clean && dbt deps && dbt run"
    ;;
  *)
    echo "Usage: $0 {run|test|debug|compile|docs|shell|fresh}"
    exit 1
    ;;
esac
```

```powershell
# scripts/dev.ps1 - Version PowerShell
param(
    [Parameter(Position=0)]
    [string]$Command,
    
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Args
)

switch ($Command) {
    "run"     { docker compose run --rm dbt dbt run $Args }
    "test"    { docker compose run --rm dbt dbt test $Args }
    "debug"   { docker compose run --rm dbt dbt debug }
    "compile" { docker compose run --rm dbt dbt compile $Args }
    "docs"    { docker compose up dbt-docs }
    "shell"   { docker compose run --rm dbt bash }
    "fresh"   { docker compose run --rm dbt sh -c "dbt clean && dbt deps && dbt run" }
    default   { Write-Host "Usage: .\dev.ps1 {run|test|debug|compile|docs|shell|fresh}" }
}
```

---

## CI/CD avec Docker

### GitHub Actions

Créer `.github/workflows/dbt-ci.yml` :

```yaml
name: DBT CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

env:
  DBT_SNOWFLAKE_ACCOUNT: ${{ secrets.DBT_SNOWFLAKE_ACCOUNT }}
  DBT_SNOWFLAKE_USER: ${{ secrets.DBT_SNOWFLAKE_USER }}
  DBT_SNOWFLAKE_PASSWORD: ${{ secrets.DBT_SNOWFLAKE_PASSWORD }}
  DBT_SNOWFLAKE_ROLE: ${{ secrets.DBT_SNOWFLAKE_ROLE }}
  DBT_SNOWFLAKE_WAREHOUSE: ${{ secrets.DBT_SNOWFLAKE_WAREHOUSE }}
  DBT_SNOWFLAKE_DATABASE: ${{ secrets.DBT_SNOWFLAKE_DATABASE }}

jobs:
  dbt-ci:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build Docker image
        run: docker compose build

      - name: Install dependencies
        run: docker compose run --rm dbt dbt deps

      - name: Validate configuration
        run: docker compose run --rm dbt dbt debug

      - name: Compile models
        run: docker compose run --rm dbt dbt compile

      - name: Run models
        run: docker compose run --rm dbt dbt run

      - name: Test models
        run: docker compose run --rm dbt dbt test
```

### GitLab CI

Créer `.gitlab-ci.yml` :

```yaml
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_DRIVER: overlay2

build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker compose build

test:
  stage: test
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker compose run --rm dbt dbt deps
    - docker compose run --rm dbt dbt debug
    - docker compose run --rm dbt dbt compile
    - docker compose run --rm dbt dbt run
    - docker compose run --rm dbt dbt test

deploy:
  stage: deploy
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker compose run --rm -e DBT_TARGET=prod dbt dbt run
  only:
    - main
```

---

## Résolution des Problèmes

### Erreur : "Cannot connect to Docker daemon"

```bash
# Vérifier que Docker est démarré
docker info

# Windows : Démarrer Docker Desktop
# Linux : sudo systemctl start docker
```

### Erreur : "Permission denied"

```bash
# Linux : Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
# Puis redémarrer la session
```

### Erreur : "Port already in use"

```bash
# Changer le port dans docker-compose.yml
ports:
  - "8081:8080"  # Utiliser 8081 au lieu de 8080
```

### Reconstruire sans cache

```bash
docker compose build --no-cache
docker compose down --volumes
docker compose up
```

---

## Checklist Installation Docker

- [ ] Docker et Docker Compose installés
- [ ] Dockerfile créé et configuré
- [ ] docker-compose.yml configuré
- [ ] .env avec les credentials (non versionné)
- [ ] profiles.yml dans `profiles/`
- [ ] Image Docker buildée avec succès
- [ ] `dbt debug` passe dans le conteneur
- [ ] `dbt run` fonctionne dans le conteneur

---

**Prochaine étape** : Consultez le guide de validation pour les commandes de vérification complètes.


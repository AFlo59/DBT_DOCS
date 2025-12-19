# Guides d'Installation DBT

Ce dossier contient des guides pratiques pas-à-pas pour installer et configurer DBT.

---

## Guides Disponibles

| Guide | Description |
|-------|-------------|
| [01-installation-locale-venv.md](./01-installation-locale-venv.md) | Installation complète avec Python virtual environment |
| [02-installation-docker.md](./02-installation-docker.md) | Installation et utilisation avec Docker/Docker Compose |
| [03-validation-projet.md](./03-validation-projet.md) | Commandes de validation du projet, profile et connexion |

---

## Quel guide choisir ?

### 🐍 Installation Locale (venv) - Recommandé pour débuter

**Idéal pour** :
- Développement quotidien
- Apprentissage de DBT
- Petites équipes
- Environnement de développement personnel

**Avantages** :
- Simple à mettre en place
- Accès direct aux fichiers
- Débogage facile
- Pas de overhead Docker

### 🐳 Installation Docker - Recommandé pour les équipes

**Idéal pour** :
- Environnement reproductible
- CI/CD
- Équipes avec des environnements hétérogènes
- Production

**Avantages** :
- Environnement identique partout
- Isolation complète
- Facile à intégrer en CI/CD
- Pas de conflits de dépendances

---

## Ordre de lecture suggéré

1. **Débutant** : Commencer par le guide local (01)
2. **Validation** : Utiliser le guide de validation (03) pour vérifier
3. **Avancé** : Passer au guide Docker (02) pour la production

---

## Prérequis communs

- Accès à un data warehouse (Snowflake, BigQuery, etc.)
- Credentials de connexion
- Git installé

---

## Ressources complémentaires

- [Documentation officielle DBT](https://docs.getdbt.com/)
- [DBT Learn (cours gratuits)](https://courses.getdbt.com/)
- [DBT Community Slack](https://getdbt.slack.com/)


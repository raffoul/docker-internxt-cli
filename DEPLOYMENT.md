# Docker Multi-Architecture Deployment Guide

## Prérequis

1. **Docker Desktop** avec support buildx activé
2. **Compte Docker Hub** (docker.io)
3. **Connexion Docker Hub** via `docker login`

## Déploiement rapide

### 1. Build et push pour production (branche main/master)

```powershell
.\scripts\deploy.ps1 -DockerUsername "votre-username"
```

Crée et pousse les images :
- `votre-username/internxt-cli:1.5.8` (version actuelle)
- `votre-username/internxt-cli:latest`

### 2. Build et push pour test (autres branches)

```powershell
.\scripts\deploy.ps1 -DockerUsername "votre-username" -Test
```

Crée et pousse l'image :
- `votre-username/internxt-cli-test:nom-branche-1.5.8`

### 3. Utiliser un nom d'image personnalisé

```powershell
.\scripts\deploy.ps1 -DockerUsername "votre-username" -ImageName "mon-internxt"
```

### 4. Utiliser la variable d'environnement

```powershell
$env:DOCKER_USERNAME = "votre-username"
.\scripts\deploy.ps1
```

## Architectures supportées

Le script compile et pousse automatiquement pour :
- **linux/amd64** - Serveurs x86_64 classiques
- **linux/arm64** - Raspberry Pi 4+, AWS Graviton, Apple Silicon
- **linux/ppc64le** - Serveurs PowerPC 64-bit
- **linux/s390x** - Mainframes IBM Z

## Comment ça fonctionne

### Docker Buildx

Docker Buildx utilise QEMU pour émuler différentes architectures et construire des images natives pour chaque plateforme. Le manifest multi-architecture permet à Docker de télécharger automatiquement la bonne image selon l'architecture du système.

### Workflow du script

1. **Login** à Docker Hub
2. **Récupération** de la dernière version `@internxt/cli` depuis npm
3. **Initialisation** du builder buildx multi-plateforme
4. **Build simultané** pour toutes les architectures
5. **Push** du manifest multi-architecture vers Docker Hub

### Vérification des images

Après le déploiement, vérifiez sur Docker Hub :

```powershell
# Inspecter le manifest multi-architecture
docker buildx imagetools inspect votre-username/internxt-cli:latest
```

Exemple de sortie :
```
Name:      docker.io/votre-username/internxt-cli:latest
MediaType: application/vnd.docker.distribution.manifest.list.v2+json
Digest:    sha256:abc123...
           
Manifests: 
  Name:      docker.io/votre-username/internxt-cli:latest@sha256:def456...
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/amd64
           
  Name:      docker.io/votre-username/internxt-cli:latest@sha256:ghi789...
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/arm64
  ...
```

## Utilisation des images déployées

Sur n'importe quelle plateforme supportée :

```bash
# Docker télécharge automatiquement la bonne architecture
docker pull votre-username/internxt-cli:latest

# Ou avec une version spécifique
docker pull votre-username/internxt-cli:1.5.8
```

## Troubleshooting

### Erreur "failed to solve with frontend dockerfile.v0"

Le builder buildx n'est pas configuré correctement :

```powershell
docker buildx create --name mybuilder --bootstrap --use
docker buildx inspect mybuilder
```

### Erreur "multiple platforms feature is currently not supported"

Vous utilisez le builder par défaut. Créez un nouveau builder :

```powershell
docker buildx create --use
```

### Build très lent

C'est normal ! La compilation multi-architecture utilise QEMU pour émuler les autres architectures, ce qui est beaucoup plus lent qu'une compilation native. Comptez 5-15 minutes selon votre machine.

### Tester une architecture spécifique localement

```powershell
# Build uniquement pour ARM64 par exemple
docker buildx build `
    --platform linux/arm64 `
    -t test-arm64:latest `
    --load .

# Puis exécuter avec QEMU
docker run --platform linux/arm64 test-arm64:latest
```

## Alternative : Build bash (Linux/WSL)

Si vous préférez utiliser les scripts bash originaux :

```bash
# Définir les variables d'environnement
export DOCKER_USERNAME="votre-username"
export DOCKER_API_PASSWORD="votre-token"  # Ou mot de passe
export IMAGE_FULLNAME="${DOCKER_USERNAME}/internxt-cli"
export BRANCH_NAME="main"

# Lancer le build et déploiement
./scripts/start.sh
```

## CI/CD avec GitHub Actions

Exemple de workflow GitHub Actions :

```yaml
name: Build and Push Multi-Arch

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v2
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      
      - name: Build and push
        run: |
          export DOCKER_USERNAME=${{ secrets.DOCKER_USERNAME }}
          export IMAGE_FULLNAME="${DOCKER_USERNAME}/internxt-cli"
          export BRANCH_NAME="main"
          bash scripts/start.sh
```

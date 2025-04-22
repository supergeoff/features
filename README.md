# Features Repository

Ce dépôt contient des fonctionnalités pour les conteneurs de développement Devcontainer. Chaque fonctionnalité est conçue pour être facilement intégrée dans un environnement de développement basé sur Devcontainer.

## Structure du Répertoire

- **`src/`** : Contient les définitions des fonctionnalités.

- **`test/`** : Contient les tests pour valider les fonctionnalités.


## Fonctionnalités Disponibles

### Google CLI

- **Description** : Installe la Google CLI et la rend disponible sur le `PATH`.
- **Options** :
  - `version` : Permet de sélectionner ou d'entrer une version spécifique de la Google CLI (par défaut : `latest`).

#### Exemple d'Utilisation

```json
"features": {
    "ghcr.io/supergeoff/features/google-cli:1": {}
}
```

## Tests

Les tests pour chaque fonctionnalité sont situés dans le répertoire `test/`.

## Configuration du Conteneur de Développement

Le fichier `.devcontainer/devcontainer.json` configure l'environnement de développement avec les fonctionnalités suivantes :
- **Docker-in-Docker** : Permet l'accès à Docker dans le conteneur.
- **Python** : Installe Python sans outils supplémentaires.
- **Devcontainers CLI** : Installe la CLI Devcontainer.

### Extensions VS Code

Les extensions suivantes sont automatiquement installées dans le conteneur :
- `ms-azuretools.vscode-docker` : Gestion de Docker via l'interface utilisateur.
- `mads-hartmann.bash-ide-vscode` : Auto-complétion pour les scripts Bash.

## Notes

- Ce dépôt est compatible avec les distributions Linux supportées par `devcontainers/features/common-utils`.
- Pour plus de détails sur chaque fonctionnalité, consultez les fichiers `README.MD` dans leurs répertoires respectifs.
#!/usr/bin/env bash
set -e

# --- Configuration Globale ---
# Liste des paquets CSV (ex: "pkg1_url[@version],pkg2_url[@version]")
# Peut être passé en premier argument, sinon vide par défaut (le script se terminera poliment)
PACKAGES_CSV="${1:-""}"
# Chemin GOPATH final pour les binaires
TARGET_GOPATH="${TARGET_GOPATH:-"/go"}"
# Utilisateur pour les permissions
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

# Répertoire de base pour les logs et fichier log principal
LOG_DIR_BASE="/usr/local/etc/vscode-dev-containers"
MAIN_LOG_FILE="${LOG_DIR_BASE}/go_install_combined.log"

# --- Logique de détermination de l'utilisateur (identique à vos scripts originaux) ---
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    # Essayer de trouver un utilisateur non-root existant
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" >/dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    # Si aucun utilisateur approprié n'est trouvé, utiliser root
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" >/dev/null 2>&1; then
    # Si 'none' est spécifié ou si l'utilisateur n'existe pas, utiliser root
    USERNAME=root
fi
# --- Fin de la logique de détermination de l'utilisateur ---

# --- Environnement de compilation temporaire ---
# Unique pour cette exécution pour éviter les conflits
TEMP_BUILD_DIR="/tmp/go_pkg_build_$$" # $$ est l'ID du processus pour l'unicité
BUILD_GOPATH="${TEMP_BUILD_DIR}"
BUILD_GOCACHE="${TEMP_BUILD_DIR}/cache"
BUILD_GOBIN="${TEMP_BUILD_DIR}/bin" # Les binaires de tous les paquets iront ici temporairement

# --- Fonctions ---

# Fonction pour vérifier si Go est installé
check_go_installed() {
    if ! type go >/dev/null 2>&1; then
        echo "$(date): Tentative d'installation de Go..." | tee -a "${MAIN_LOG_FILE}"
        curl -fsSL https://raw.githubusercontent.com/devcontainers/features/main/src/go/install.sh | bash -s -- "/usr/local" | tee -a "${MAIN_LOG_FILE}"
        exit 1
    fi
    echo "$(date): Version de Go installée : $(go version)" | tee -a "${MAIN_LOG_FILE}"
}

# Fonction pour installer un unique paquet Go
# Utilise les variables globales BUILD_GOPATH, BUILD_GOCACHE, BUILD_GOBIN, LOG_DIR_BASE
install_single_go_package() {
    local PACKAGE_URL="${1}"
    local PACKAGE_VERSION="${2:-"latest"}" # "latest" par défaut si aucune version n'est fournie

    # Nettoyer le nom du paquet pour le nom du fichier log
    local PACKAGE_NAME_FOR_LOG=$(echo "${PACKAGE_URL}" | sed 's/[^a-zA-Z0-9_-]/_/g')
    local SINGLE_PKG_LOG_FILE="${LOG_DIR_BASE}/go_install_${PACKAGE_NAME_FOR_LOG}.log"

    echo "$(date): Début de l'installation du paquet Go : ${PACKAGE_URL}@${PACKAGE_VERSION}" >"${SINGLE_PKG_LOG_FILE}"

    if [ -z "$PACKAGE_URL" ]; then
        echo "$(date): La variable 'PACKAGE_URL' est vide, installation ignorée." | tee -a "${SINGLE_PKG_LOG_FILE}"
        return 1 # Indiquer un échec pour ce paquet
    fi

    echo "$(date): Installation du paquet Go : ${PACKAGE_URL}@${PACKAGE_VERSION}" | tee -a "${SINGLE_PKG_LOG_FILE}"
    echo "$(date): Utilisation de GOPATH=${GOPATH}, GOCACHE=${GOCACHE}, GOBIN=${GOBIN}" | tee -a "${SINGLE_PKG_LOG_FILE}"

    local INSTALL_TARGET="${PACKAGE_URL}"
    if [ "${PACKAGE_VERSION}" != "latest" ] && [ -n "${PACKAGE_VERSION}" ]; then
        INSTALL_TARGET="${PACKAGE_URL}@${PACKAGE_VERSION}"
    fi

    # La commande 'go install' placera les binaires dans $GOBIN (qui est $BUILD_GOBIN)
    # Redirige stdout et stderr vers le fichier log et la console.
    {
        echo "$(date): Exécution de : go install -v \"${INSTALL_TARGET}\""
        # Exécuter dans un sous-shell pour que les variables d'environnement soient bien prises
        (
            export GOPATH="${BUILD_GOPATH}"
            export GOCACHE="${BUILD_GOCACHE}"
            export GOBIN="${BUILD_GOBIN}"
            go install -v "${INSTALL_TARGET}"
        )
    } 2>&1 | tee -a "${SINGLE_PKG_LOG_FILE}"

    # Vérifier si la commande a réussi (go install retourne un code d'erreur en cas d'échec)
    # `set -e` devrait déjà gérer cela, mais une vérification explicite peut être ajoutée si nécessaire.
    # if [ $? -ne 0 ]; then
    # echo "$(date): ERREUR lors de l'installation de ${INSTALL_TARGET}" | tee -a "${SINGLE_PKG_LOG_FILE}"
    # return 1
    # fi

    echo "$(date): Commande d'installation pour ${PACKAGE_URL}@${PACKAGE_VERSION} soumise avec succès." | tee -a "${SINGLE_PKG_LOG_FILE}"
    return 0
}

# --- Script Principal ---

# Vérifier si des paquets sont spécifiés
if [ -z "$PACKAGES_CSV" ]; then
    echo "$(date): Aucun paquet Go spécifié dans le premier argument ou la variable PACKAGES_CSV. Fin du script."
    # Ne pas écrire dans MAIN_LOG_FILE si LOG_DIR_BASE n'a pas encore été créé.
    if [ -d "${LOG_DIR_BASE}" ]; then
        echo "$(date): Aucun paquet Go spécifié. Fin du script." >>"${MAIN_LOG_FILE}"
    fi
    exit 0
fi

# Création des répertoires nécessaires
mkdir -p "${LOG_DIR_BASE}" "${TARGET_GOPATH}/bin" "${BUILD_GOPATH}" "${BUILD_GOCACHE}" "${BUILD_GOBIN}"
echo "$(date): Installation multi-paquets Go (script combiné) démarrée." >"${MAIN_LOG_FILE}"
echo "$(date): Paquets à installer : ${PACKAGES_CSV}" | tee -a "${MAIN_LOG_FILE}"
echo "$(date): GOPATH cible pour les binaires : ${TARGET_GOPATH}" | tee -a "${MAIN_LOG_FILE}"
echo "$(date): GOPATH de compilation temporaire : ${BUILD_GOPATH}" | tee -a "${MAIN_LOG_FILE}"
echo "$(date): Utilisateur effectif pour les permissions : ${USERNAME}" | tee -a "${MAIN_LOG_FILE}"

# Vérifier l'installation de Go une seule fois
check_go_installed

# Sauvegarder les variables d'environnement Go actuelles (optionnel, mais bonne pratique)
ORIGINAL_GOPATH="${GOPATH:-}"
ORIGINAL_GOCACHE="${GOCACHE:-}"
ORIGINAL_GOBIN="${GOBIN:-}"

# Définir l'environnement Go pour la durée de ce script
export GOPATH="${BUILD_GOPATH}"
export GOCACHE="${BUILD_GOCACHE}"
export GOBIN="${BUILD_GOBIN}"
# Exporter LOG_DIR_BASE pour que la fonction d'installation sache où placer ses logs spécifiques
export LOG_DIR_BASE

# Configuration du groupe et des permissions (une fois avant les installations)
echo "$(date): Configuration du groupe 'golang' et des permissions utilisateur..." | tee -a "${MAIN_LOG_FILE}"
umask 002
if ! cat /etc/group | grep -e "^golang:" >/dev/null 2>&1; then
    if command -v groupadd >/dev/null 2>&1; then
        groupadd -r golang || echo "$(date): Avertissement : La commande groupadd a échoué." | tee -a "${MAIN_LOG_FILE}"
    else
        echo "$(date): Avertissement : Commande groupadd introuvable. Impossible de créer le groupe 'golang'." | tee -a "${MAIN_LOG_FILE}"
    fi
fi

if id -u "${USERNAME}" >/dev/null 2>&1; then # Vérifier si l'utilisateur existe
    if command -v usermod >/dev/null 2>&1; then
        if ! groups "${USERNAME}" 2>/dev/null | grep -q "\bgolang\b"; then
            usermod -a -G golang "${USERNAME}" || echo "$(date): Avertissement : usermod a échoué pour l'utilisateur ${USERNAME}." | tee -a "${MAIN_LOG_FILE}"
        fi
    else
        echo "$(date): Avertissement : Commande usermod introuvable. Impossible d'ajouter l'utilisateur ${USERNAME} au groupe 'golang'." | tee -a "${MAIN_LOG_FILE}"
    fi
else
    echo "$(date): Avertissement : Utilisateur ${USERNAME} introuvable. Ajout au groupe 'golang' ignoré." | tee -a "${MAIN_LOG_FILE}"
fi

# Séparer les paquets par la virgule
IFS=',' read -ra SPLITTED_PACKAGES <<<"$PACKAGES_CSV"

INSTALL_SUCCESS_COUNT=0
INSTALL_FAILURE_COUNT=0

for package_entry in "${SPLITTED_PACKAGES[@]}"; do
    # Nettoyer les espaces autour de l'entrée du paquet
    package_entry=$(echo "$package_entry" | xargs)
    if [ -z "$package_entry" ]; then
        continue
    fi

    PARSED_PACKAGE_URL=""
    PARSED_PACKAGE_VERSION="latest" # Par défaut à "latest"

    # Regex pour extraire package_url[@version]
    if [[ $package_entry =~ ^([^@]+)(@(.+))?$ ]]; then
        PARSED_PACKAGE_URL="${BASH_REMATCH[1]}"
        if [ -n "${BASH_REMATCH[3]}" ]; then # Si une partie version existe
            PARSED_PACKAGE_VERSION="${BASH_REMATCH[3]}"
        fi
    else
        echo "$(date): Avertissement : Impossible d'analyser l'entrée du paquet '$package_entry' pour une version. Utilisation de '$package_entry' comme URL et version 'latest'." | tee -a "${MAIN_LOG_FILE}"
        PARSED_PACKAGE_URL="$package_entry"
    fi

    echo "----------------------------------------------------------------------" | tee -a "${MAIN_LOG_FILE}"
    echo "$(date): Traitement du paquet : URL='${PARSED_PACKAGE_URL}', Version='${PARSED_PACKAGE_VERSION}'" | tee -a "${MAIN_LOG_FILE}"

    # Appel de la fonction d'installation solo
    if install_single_go_package "${PARSED_PACKAGE_URL}" "${PARSED_PACKAGE_VERSION}"; then
        INSTALL_SUCCESS_COUNT=$((INSTALL_SUCCESS_COUNT + 1))
    else
        # `set -e` arrête le script en cas d'échec dans la fonction si elle retourne un code non nul.
        # Si `set -e` est commenté, cette section serait atteinte.
        echo "$(date): ERREUR : L'installation de ${PARSED_PACKAGE_URL}@${PARSED_PACKAGE_VERSION} a échoué (voir log spécifique)." | tee -a "${MAIN_LOG_FILE}"
        INSTALL_FAILURE_COUNT=$((INSTALL_FAILURE_COUNT + 1))
    fi
    echo "----------------------------------------------------------------------" | tee -a "${MAIN_LOG_FILE}"
done

# Restaurer les variables d'environnement Go originales (si elles étaient définies)
export GOPATH="${ORIGINAL_GOPATH}"
export GOCACHE="${ORIGINAL_GOCACHE}"
export GOBIN="${ORIGINAL_GOBIN}"
# Nettoyer si elles étaient vides à l'origine pour ne pas laisser de variables vides exportées
if [ -z "${GOPATH}" ]; then unset GOPATH; fi
if [ -z "${GOCACHE}" ]; then unset GOCACHE; fi
if [ -z "${GOBIN}" ]; then unset GOBIN; fi

# Déplacer les outils Go depuis le GOBIN de compilation temporaire vers TARGET_GOPATH/bin final
if [ -d "${BUILD_GOBIN}" ] && [ "$(ls -A ${BUILD_GOBIN} 2>/dev/null)" ]; then
    echo "$(date): Déplacement des binaires installés de ${BUILD_GOBIN} vers ${TARGET_GOPATH}/bin/" | tee -a "${MAIN_LOG_FILE}"
    # S'assurer que le répertoire cible existe bien
    mkdir -p "${TARGET_GOPATH}/bin/"
    # Utiliser rsync ou cp -a pour mieux gérer les permissions initiales si nécessaire,
    # mais mv est généralement suffisant ici car les permissions finales sont appliquées ensuite.
    mv "${BUILD_GOBIN}"/* "${TARGET_GOPATH}/bin/"
else
    echo "$(date): Aucun binaire trouvé dans le GOBIN de compilation temporaire (${BUILD_GOBIN}) à déplacer." | tee -a "${MAIN_LOG_FILE}"
fi

echo "$(date): Nettoyage du répertoire de compilation temporaire ${TEMP_BUILD_DIR}..." | tee -a "${MAIN_LOG_FILE}"
rm -rf "${TEMP_BUILD_DIR}"

# Ajustement final des permissions pour l'ensemble de TARGET_GOPATH
# Uniquement si au moins une installation a réussi et que des binaires existent.
if [ ${INSTALL_SUCCESS_COUNT} -gt 0 ] && [ -d "${TARGET_GOPATH}/bin" ] && [ "$(ls -A ${TARGET_GOPATH}/bin 2>/dev/null)" ]; then
    echo "$(date): Finalisation des permissions pour ${TARGET_GOPATH}..." | tee -a "${MAIN_LOG_FILE}"
    chown -R "${USERNAME}:golang" "${TARGET_GOPATH}" || echo "$(date): Avertissement : Le chown final a échoué pour ${TARGET_GOPATH}." | tee -a "${MAIN_LOG_FILE}"
    chmod -R g+r+w "${TARGET_GOPATH}" || echo "$(date): Avertissement : Le chmod final (g+r+w) a échoué pour ${TARGET_GOPATH}." | tee -a "${MAIN_LOG_FILE}"
    find "${TARGET_GOPATH}" -type d -print0 | xargs -n 1 -0 chmod g+s || echo "$(date): Avertissement : Le chmod final (g+s) a échoué pour ${TARGET_GOPATH}." | tee -a "${MAIN_LOG_FILE}"
else
    if [ ${INSTALL_FAILURE_COUNT} -gt 0 ]; then
        echo "$(date): Configuration finale des permissions ignorée en raison d'erreurs d'installation." | tee -a "${MAIN_LOG_FILE}"
    elif [ ${INSTALL_SUCCESS_COUNT} -eq 0 ]; then
        echo "$(date): Configuration finale des permissions ignorée car aucun paquet n'a été installé avec succès." | tee -a "${MAIN_LOG_FILE}"
    else
        echo "$(date): Configuration finale des permissions ignorée car aucun binaire n'a été installé ou TARGET_GOPATH n'est pas comme attendu." | tee -a "${MAIN_LOG_FILE}"
    fi
fi

echo "--- Résumé de l'installation ---" | tee -a "${MAIN_LOG_FILE}"
echo "Paquets traités avec succès : ${INSTALL_SUCCESS_COUNT}" | tee -a "${MAIN_LOG_FILE}"
echo "Paquets en échec : ${INSTALL_FAILURE_COUNT}" | tee -a "${MAIN_LOG_FILE}"

if [ ${INSTALL_FAILURE_COUNT} -gt 0 ]; then
    echo "$(date): Une ou plusieurs installations de paquets Go ont échoué. Vérifiez les logs pour plus de détails." | tee -a "${MAIN_LOG_FILE}"
    echo "Terminé avec des erreurs." | tee -a "${MAIN_LOG_FILE}"
    exit 1 # Sortir avec une erreur si un paquet a échoué
else
    echo "$(date): Tous les paquets Go spécifiés ont été traités avec succès !" | tee -a "${MAIN_LOG_FILE}"
    echo "Terminé !" | tee -a "${MAIN_LOG_FILE}"
fi

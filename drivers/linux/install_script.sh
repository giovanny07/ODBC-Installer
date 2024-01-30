#!/bin/bash
# Imagunet Property: This script is developed by Imagunet.
# You may obtain more information about Imagunet at https://www.imagunet.com/.
# All rights reserved by Imagunet.

# Obtiene el directorio del script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define global variables
LOG_FILE="$SCRIPT_DIR/install_log.log"
LOCAL_MARIADB_PACKAGE_PATH="$SCRIPT_DIR"
TARGET_INSTALLATION_PATH="/var/lib/zabbix"


# Function for displaying help
display_help() {
    script_name=$(basename "$0")
    echo "Usage: $script_name [OPTIONS]"
    echo "Options:"
    echo "  --remove PACKAGE_NAME   Remove the specified package."
    echo "  --install PACKAGE_NAME  Install the specified package."
    echo "  --install-db-engines    Install selected database engines. You can specify the version you want to install"
    echo "                          Example: $script_name --install-db-engines mariadb 3.2.0 postgresql 12.5 oracledb 19.3"
    echo "  -h, --help              Display this help message."
    exit 0
}

# Function for logging events
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

# Function to check Internet Connection
check_internet_connection() {
    log_message "Checking internet connection..."
    if command -v wget &> /dev/null; then
        wget -q --spider http://www.google.com
    elif command -v curl &> /dev/null; then
        curl -s --head http://www.google.com
    else
        log_message "Neither 'wget' nor 'curl' is available. Please install one of them."
        exit 1
    fi

    if [ $? -eq 0 ]; then
        log_message "Internet connection is available."
    else
        log_message "No internet connection. Please check your network settings."
        exit 1
    fi
}

# Function to update repositories
update_repositories() {
    if command -v apt &> /dev/null; then
        sudo apt-get update
    elif command -v yum &> /dev/null; then
        sudo yum check-update
    else
        log_message "Unsupported package manager. Please add the necessary checks for your package manager."
    fi
}

# Function to install a package if not present
install_package_if_not_present() {
    PACKAGE_NAME=$1
    if ! command -v $PACKAGE_NAME &> /dev/null; then
        log_message "$PACKAGE_NAME not found. Installing..."
        if command -v apt &> /dev/null; then
            sudo apt-get install $PACKAGE_NAME -y
        elif command -v yum &> /dev/null; then
            sudo yum install $PACKAGE_NAME -y
        else
            log_message "Unsupported package manager. Please add the necessary checks for your package manager."
            exit 1
        fi
    else
        log_message "$PACKAGE_NAME is already installed."
    fi
}

# Function to uninstall a package
uninstall_package() {
    PACKAGE_NAME=$1
    log_message "Removing $PACKAGE_NAME..."
    if command -v apt &> /dev/null; then
        sudo apt-get remove $PACKAGE_NAME
    elif command -v yum &> /dev/null; then
        sudo yum remove $PACKAGE_NAME
    else
        log_message "Unsupported package manager. Please add the necessary checks for your package manager."
        exit 1
    fi
}

# Function to check and update repositories, and install/uninstall a package if not present
check_and_manage_package() {
    update_repositories
    if [ "$REMOVE_PACKAGE" == "true" ]; then
        uninstall_package "$PACKAGE_TO_REMOVE"
    else
        install_package_if_not_present "$PACKAGE_TO_INSTALL"
    fi
}

check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        log_message "jq is not installed. Please install jq to proceed."
        exit 1
    fi
}

#Function to detect Linux distribution and version
detect_linux_distribution() {
    log_message "Detecting Linux distribution..."
    log_message "Detecting Linux distribution and version..."
    if [ -f "/etc/os-release" ]; then
        . "/etc/os-release"
        LINUX_DISTRIBUTION=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        log_message "Detected Linux distribution: $LINUX_DISTRIBUTION"

        case $LINUX_DISTRIBUTION in
            "ubuntu")
                LINUX_VERSION=$UBUNTU_CODENAME
                ;;
            "rocky" | "almalinux" | "rhel" | "ol" | "centos")
                LINUX_VERSION=$(echo "$VERSION_ID" | cut -d '.' -f 1)
                ;;
            *)
                log_message "Unsupported Linux distribution: $LINUX_DISTRIBUTION"
                exit 1
                ;;
        esac

        log_message "Detected Linux distribution: $LINUX_DISTRIBUTION $LINUX_VERSION"
    else
        log_message "Unable to detect Linux distribution."
        exit 1
    fi
}

# Function to download latest odbc's mariadb version
download_latest_mariadb_odbc() {
    check_jq_installed
    detect_linux_distribution  # Asegúrate de que esta función está disponible y es correcta
    if check_internet_connection; then
        MARIADB_ODBC_VERSION=$(curl -s https://api.github.com/repos/mariadb-corporation/mariadb-connector-odbc/tags | jq -r '.[] | .name' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+(-release)?$' | sort -V | tail -n 1)
        VERSION_FILTER=$(echo "$MARIADB_ODBC_VERSION" | cut -d. -f1,2)
        PATH_HTML_1=$(curl -s https://dlm.mariadb.com/browse/odbc_connector/ | awk -v target="$TARGET_VERSION" -v filter="$VERSION_FILTER" -F'["/]' '$0 ~ filter && $5 ~ target {print $5; exit}')
        PATH_HTML_2=$(curl -s "https://dlm.mariadb.com/browse/odbc_connector/$PATH_HTML_1/" | grep -oP 'href="/browse/odbc_connector/'"$PATH_HTML_1"'/\K\d+' | grep -oP '\d+' | sort -n | tail -n 1)
        FILE_LIST=$(curl -s "https://dlm.mariadb.com/browse/odbc_connector/$PATH_HTML_1/$PATH_HTML_2/")

        log_message "Downloading MariaDB ODBC driver version $MARIADB_ODBC_VERSION for $LINUX_DISTRIBUTION $LINUX_VERSION..."

        # Agregamos lógica para seleccionar el archivo correcto según el sistema operativo
        case $LINUX_DISTRIBUTION in
            "ubuntu")
                DOWNLOAD_FILE=$(echo "$FILE_LIST" | grep -oE 'href="([^"]+\.tar\.gz)"' | sed -E 's/href="([^"]+)"/\1/' | grep -E "mariadb-connector-odbc-$MARIADB_ODBC_VERSION-ubuntu-$LINUX_VERSION-amd64.tar.gz")
                ;;
            "rocky" | "almalinux" | "rhel" | "ol" | "centos")
                DOWNLOAD_FILE=$(echo "$FILE_LIST" | grep -oE 'href="([^"]+\.tar\.gz)"' | sed -E 's/href="([^"]+)"/\1/' | grep -E "mariadb-connector-odbc-$MARIADB_ODBC_VERSION-rhel$LINUX_VERSION-amd64.tar.gz")
                ;;
            *)  # Añade casos adicionales para otras distribuciones según sea necesario
                log_message "Unsupported Linux distribution: $LINUX_DISTRIBUTION"
                exit 1
                ;;
        esac
        BASENAME_FILE=$(basename "$DOWNLOAD_FILE")
        if [ -n "$BASENAME_FILE" ]; then
            log_message "Selected download file: $BASENAME_FILE"

            if [ -e "$TARGET_INSTALLATION_PATH/$BASENAME_FILE" ]; then
                log_message "$BASENAME_FILE already exists in $TARGET_INSTALLATION_PATH. Skipping download."
            else
                log_message "Downloading $DOWNLOAD_FILE..."
                curl -LO "https://dlm.mariadb.com/browse/odbc_connector/$PATH_HTML_1/$PATH_HTML_2/$DOWNLOAD_FILE"
                log_message "$BASENAME_FILE downloaded successfully."

                log_message "Copying $BASENAME_FILE to $TARGET_INSTALLATION_PATH..."
                cp "$BASENAME_FILE" "$TARGET_INSTALLATION_PATH/"
                log_message "Copy complete."
            fi
        else
            log_message "No suitable download file found for $LINUX_DISTRIBUTION $LINUX_VERSION."
            exit 1
        fi
    else
        log_message "No internet connection. Using a local version of MariaDB ODBC driver."
    fi
}


# Function to download a specific version of MariaDB ODBC driver
download_specific_mariadb_version() {
    check_jq_installed
    detect_linux_distribution  # Asegúrate de que esta función está disponible y es correcta
    if check_internet_connection; then
        MARIADB_ODBC_VERSION=$1
        VERSION_FILTER=$(echo "$MARIADB_ODBC_VERSION" | cut -d. -f1,2)
        PATH_HTML_1=$(curl -s https://dlm.mariadb.com/browse/odbc_connector/ | awk -v target="$TARGET_VERSION" -v filter="$VERSION_FILTER" -F'["/]' '$0 ~ filter && $5 ~ target {print $5; exit}')
        PATH_HTML_2=$(curl -s "https://dlm.mariadb.com/browse/odbc_connector/$PATH_HTML_1/" | grep -oP 'href="/browse/odbc_connector/'"$PATH_HTML_1"'/\K\d+' | grep -oP '\d+' | sort -n | tail -n 1)
        FILE_LIST=$(curl -s "https://dlm.mariadb.com/browse/odbc_connector/$PATH_HTML_1/$PATH_HTML_2/")

        log_message "Downloading MariaDB ODBC driver version $MARIADB_ODBC_VERSION for $LINUX_DISTRIBUTION $LINUX_VERSION..."

        # Agregamos lógica para seleccionar el archivo correcto según el sistema operativo
        case $LINUX_DISTRIBUTION in
            "ubuntu")
                DOWNLOAD_FILE=$(echo "$FILE_LIST" | grep -oE 'href="([^"]+\.tar\.gz)"' | sed -E 's/href="([^"]+)"/\1/' | grep -E "mariadb-connector-odbc-$MARIADB_ODBC_VERSION-ubuntu-$LINUX_VERSION-amd64.tar.gz")
                ;;
            "rocky" | "almalinux" | "rhel" | "ol" | "centos")
                DOWNLOAD_FILE=$(echo "$FILE_LIST" | grep -oE 'href="([^"]+\.tar\.gz)"' | sed -E 's/href="([^"]+)"/\1/' | grep -E "mariadb-connector-odbc-$MARIADB_ODBC_VERSION-rhel$LINUX_VERSION-amd64.tar.gz")
                ;;
            *)  # Añade casos adicionales para otras distribuciones según sea necesario
                log_message "Unsupported Linux distribution: $LINUX_DISTRIBUTION"
                exit 1
                ;;
        esac
        BASENAME_FILE=$(basename "$DOWNLOAD_FILE")
        if [ -n "$BASENAME_FILE" ]; then
            log_message "Selected download file: $BASENAME_FILE"

            if [ -e "$TARGET_INSTALLATION_PATH/$BASENAME_FILE" ]; then
                log_message "$BASENAME_FILE already exists in $TARGET_INSTALLATION_PATH. Skipping download."
            else
                log_message "Downloading $DOWNLOAD_FILE..."
                curl -LO "https://dlm.mariadb.com/browse/odbc_connector/$PATH_HTML_1/$PATH_HTML_2/$DOWNLOAD_FILE"
                log_message "$BASENAME_FILE downloaded successfully."

                log_message "Copying $BASENAME_FILE to $TARGET_INSTALLATION_PATH..."
                cp "$BASENAME_FILE" "$TARGET_INSTALLATION_PATH/"
                log_message "Copy complete."
            fi
        else
            log_message "No suitable download file found for $LINUX_DISTRIBUTION $LINUX_VERSION."
            exit 1
        fi
    else
        log_message "No internet connection. Using a local version of MariaDB ODBC driver."
    fi
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        --remove)
            REMOVE_PACKAGE="true"
            shift
            PACKAGE_TO_REMOVE="$1"
            log_message "Removing package: $PACKAGE_TO_REMOVE"
            uninstall_package "$PACKAGE_TO_REMOVE"
            ;;
        --install)
            REMOVE_PACKAGE="false"
            shift
            PACKAGE_TO_INSTALL="$1"
            log_message "Installing package: $PACKAGE_TO_INSTALL"
            install_package_if_not_present "$PACKAGE_TO_INSTALL"
            ;;
        --install-db-engines)
            shift
            while [[ $# -gt 0 ]]; do
                case $1 in
                    "mariadb")
                        DB_ENGINES+=("mariadb")
                        shift
                        if [ $# -gt 0 ] && [[ ! $1 == -* ]]; then
                            MARIADB_VERSIONS+=("$1")
                            log_message "Adding MariaDB version: $1"
                            shift
                        else
                            log_message "No version specified for MariaDB. Using the latest version."
                        fi
                        ;;
                    "postgresql")
                        DB_ENGINES+=("postgresql")
                        shift
                        if [ $# -gt 0 ] && [[ ! $1 == -* ]]; then
                            POSTGRESQL_VERSIONS+=("$1")
                            log_message "Adding PostgreSQL version: $1"
                            shift
                        else
                            log_message "No version specified for PostgreSQL. Display an error message or use a default version."
                        fi
                        # Add logic for PostgreSQL
                        ;;
                    "oracledb")
                        DB_ENGINES+=("oracledb")
                        shift
                        if [ $# -gt 0 ] && [[ ! $1 == -* ]]; then
                            ORACLEDB_VERSIONS+=("$1")
                            log_message "Adding OracleDB version: $1"
                            shift
                        else
                            log_message "No version specified for OracleDB. Display an error message or use a default version."
                        fi
                        # Add logic for OracleDB
                        ;;
                    *)
                        log_message "Unsupported database engine specified: $1"
                        exit 1
                        ;;
                esac
            done
            ;;
        --h | --help)
            display_help
            ;;
        *)
            log_message "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done



# Install selected database engines
if [ ${#DB_ENGINES[@]} -gt 0 ]; then
    for ((i=0; i<${#DB_ENGINES[@]}; i++)); do
        case ${DB_ENGINES[$i]} in
            "mariadb")
                if [ "${MARIADB_VERSIONS[$i]}" ]; then
                    detect_linux_distribution
                    case $LINUX_DISTRIBUTION in
                        "ubuntu")
                            install_package_if_not_present "unixodbc"
                            ;;
                        "rocky" | "almalinux" | "rhel" | "ol" | "centos")
                            install_package_if_not_present "unixODBC"
                            ;;
                        *)  # Añade casos adicionales para otras distribuciones según sea necesario
                            log_message "Unsupported Linux distribution: $LINUX_DISTRIBUTION"
                            exit 1
                            ;;
                    esac
                    download_specific_mariadb_version "${MARIADB_VERSIONS[$i]}"
                else
                    log_message "No version specified for MariaDB ODBC driver. Using a default version."
                    case $LINUX_DISTRIBUTION in
                        "ubuntu")
                            install_package_if_not_present "unixodbc"
                            ;;
                        "rocky" | "almalinux" | "rhel" | "ol" | "centos")
                            install_package_if_not_present "unixODBC"
                            ;;
                        *)  # Añade casos adicionales para otras distribuciones según sea necesario
                            log_message "Unsupported Linux distribution: $LINUX_DISTRIBUTION"
                            exit 1
                            ;;
                    esac
                    download_latest_mariadb_odbc
                fi
                ;;
            "postgresql")
                if [ "${POSTGRESQL_VERSIONS[$i]}" ]; then
                    detect_linux_distribution
                    case $LINUX_DISTRIBUTION in
                        "ubuntu")
                            install_package_if_not_present "unixodbc"
                            ;;
                        "rocky" | "almalinux" | "rhel" | "ol" | "centos")
                            install_package_if_not_present "unixODBC"
                            ;;
                        *)  # Añade casos adicionales para otras distribuciones según sea necesario
                            log_message "Unsupported Linux distribution: $LINUX_DISTRIBUTION"
                            exit 1
                            ;;
                    esac
                else
                    log_message "No version specified for PostgreSQL ODBC driver. Using a default version."
                    case $LINUX_DISTRIBUTION in
                        "ubuntu")
                            install_package_if_not_present "unixodbc"
                            ;;
                        "rocky" | "almalinux" | "rhel" | "ol" | "centos")
                            install_package_if_not_present "unixODBC"
                            ;;
                        *)  # Añade casos adicionales para otras distribuciones según sea necesario
                            log_message "Unsupported Linux distribution: $LINUX_DISTRIBUTION"
                            exit 1
                            ;;
                    esac
                fi
                ;;
            "oracledb")
                if [ "${ORACLEDB_VERSIONS[$i]}" ]; then
                    detect_linux_distribution
                    case $LINUX_DISTRIBUTION in
                        "ubuntu")
                            install_package_if_not_present "unixodbc"
                            ;;
                        "rocky" | "almalinux" | "rhel" | "ol" | "centos")
                            install_package_if_not_present "unixODBC"
                            ;;
                        *)  # Añade casos adicionales para otras distribuciones según sea necesario
                            log_message "Unsupported Linux distribution: $LINUX_DISTRIBUTION"
                            exit 1
                            ;;
                    esac
                else
                    log_message "No version specified for OracleDB ODBC driver. Using a default version."
                    case $LINUX_DISTRIBUTION in
                        "ubuntu")
                            install_package_if_not_present "unixodbc"
                            ;;
                        "rocky" | "almalinux" | "rhel" | "ol" | "centos")
                            install_package_if_not_present "unixODBC"
                            ;;
                        *)  # Añade casos adicionales para otras distribuciones según sea necesario
                            log_message "Unsupported Linux distribution: $LINUX_DISTRIBUTION"
                            exit 1
                            ;;
                    esac
                fi
                ;;
            *)
                log_message "Unsupported database engine specified: ${DB_ENGINES[$i]}"
                exit 1
                ;;
        esac
    done
fi

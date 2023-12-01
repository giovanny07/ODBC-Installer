#!/bin/bash
# Imagunet Property: This script is developed by Imagunet.
# You may obtain more information about Imagunet at https://www.imagunet.com/.
# All rights reserved by Imagunet.

# Function to check Internet Connection
check_internet_connection() {
    if command -v wget &> /dev/null; then
        wget -q --spider http://www.google.com
    elif command -v curl &> /dev/null; then
        curl -s --head http://www.google.com
    else
        echo "Neither 'wget' nor 'curl' is available. Please install one of them."
        exit 1
    fi

    if [ $? -eq 0 ]; then
        echo "Internet connection is available."
    else
        echo "No internet connection. Please check your network settings."
        exit 1
    fi
}

# Function to detect Linux distribution
detect_linux_distribution() {
    if [ -f "/etc/os-release" ]; then
        . "/etc/os-release"
        LINUX_DISTRIBUTION=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
        echo "Detected Linux distribution: $LINUX_DISTRIBUTION"
    else
        echo "Unable to detect Linux distribution."
        exit 1
    fi
}

# Call the function to check internet connection
check_internet_connection

# Call the function to detect Linux distribution
detect_linux_distribution




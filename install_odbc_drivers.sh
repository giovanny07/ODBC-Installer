#!/bin/bash
# Imagunet Property: This script is developed by Imagunet.
# You may obtain more information about Imagunet at https://www.imagunet.com/.
# All rights reserved by Imagunet.

# This script checks the operating system and runs the appropriate installation script.

# Detect if the operating system is Linux
if [ "$(uname)" == "Linux" ]; then
    # Run the installation script specific to Linux
    ./drivers/linux/install_script.sh
else
    echo "This script is only compatible with Linux distributions."
    exit 1
fi




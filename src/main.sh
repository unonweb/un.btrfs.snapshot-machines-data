#!/bin/bash

# BOILERPLATE
# ===========
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_DIR_NAME=$(dirname -- "$(readlink -f "${SCRIPT_DIR}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")
CLEAR="\e[0m"
BOLD="\e[1m"
UNDERLINE="\e[4m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
GREY="\e[38;5;248m"

# CONFIG
# ======
MACHINES_DATA_DIR="/srv/data"
SNAPSHOTS_BASE_DIR="/.snapshots"

# IMPORTS
# =======
source "${SCRIPT_DIR}/lib/is_btrfs_subvolume.sh"
source "${SCRIPT_DIR}/lib/get_subvolume_name.sh"
source "${SCRIPT_DIR}/lib/start_machine.sh"
source "${SCRIPT_DIR}/lib/snapshot_machine.sh"

function main {

    if [ "${UID}" -ne 0 ]; then
        echo "<3>ERROR: This script must be run as root."
        exit 1
    fi

    # Validate arguments
    if [[ ${#} -eq 0 ]]; then
        echo "<3>ERROR: No machine names provided." 
        echo "Usage: ${0} <container_1> [container_2 ...]"
        echo "Exiting ..."
        exit 1
    fi

    for machine in "${@}"; do
        snapshot_machine "${machine}"
    done

    echo "<6>Done"
}

main ${@}
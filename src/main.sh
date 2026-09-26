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

# Function to handle a single machine snapshot safely
function snapshot_machine {

    local machine="${1}"
    local machine_data_path="${MACHINES_DATA_DIR}/${machine}"

    # Verify path exists and is a Btrfs subvolume
    if ! is_btrfs_subvolume "${machine_data_path}"; then
        echo "WARNING: '${machine_data_path}' does not exist or is NOT a Btrfs subvolume. Skipping."
        return 0
    fi

    echo "<6>---"
    echo -e "<6>MACHINE: ${CYAN}${machine}${CLEAR}"

    # Build target snapshot path
    local subvol_name
    subvol_name=$(get_subvolume_name "${machine_data_path}")
    
    local snapshots_dir="${SNAPSHOTS_BASE_DIR}/${subvol_name:-${machine}}"
    local snapshot_path="${snapshots_dir}/$(date +%Y-%m-%d-%H%M%S)"

    # Create destination directory if it doesn't exist
    if [ ! -d "${snapshots_dir}" ]; then
        mkdir -p "${snapshots_dir}"
    fi

    # Track machine status
    local was_running=false
    if machinectl status "${machine}" &>/dev/null; then
        was_running=true
    fi

    # Scoped trap: if this specific machine execution is interrupted, restart it if it was running
    trap 'if [ "${was_running}" = true ]; then start_machine "${machine}"; fi' EXIT INT TERM

    # Stop machine if running
    local skip_snapshot=false
    if [ "${was_running}" = true ]; then
        echo "<6>Stopping machine: ${machine} ..."
        machinectl stop "${machine}"
    
        sleep 1
        local wait_count=0
        local wait_count_max=6 # -> 6*2=12s

        while true; do
            if ! machinectl status "${machine}" &>/dev/null; then
                echo "<6>${machine} has stopped."
                break
            fi
            
            if ((wait_count == wait_count_max)); then
                echo "<3>ERROR: Aborting operation on machine ${machine} after waiting $((wait_count * 2)) seconds."
                skip_snapshot=true
                break
            fi
            
            echo "<6>Waiting for ${machine} to complete shutdown ... ($((wait_count * 2))/$((wait_count_max * 2))s)"
            ((wait_count++))
            sleep 2
        done

        if ${skip_snapshot}; then
            trap - EXIT INT TERM
            return 1
        fi
    fi
    
    # Perform Read-Only Btrfs Snapshot
    echo "Creating read-only snapshot at '${snapshot_path}'..."
    if btrfs subvolume snapshot -r "${machine_data_path}" "${snapshot_path}"; then
        echo "Snapshot created successfully."
    else
        echo "ERROR: Failed to create snapshot for '${machine}'."
    fi

    # Restart machine if it was running previously
    if [ "${was_running}" = true ]; then
        start_machine "${machine}"
    fi

    # Clear trap for this machine run successfully
    trap - EXIT INT TERM
}

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

main "${@}"
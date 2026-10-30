# NOTES
# =====
# Stops the machine given by ${1}
# Creates a snapshot
# Src: ${MACHINES_DATA_BASE_DIR}/${machine}
# Dst: ${SNAPSHOTS_BASE_DIR}/${subvol_name:-${machine}}
# Starts the machine again

# REQUIRES
# ========
# - SNAPSHOTS_BASE_DIR
# - MACHINES_DATA_BASE_DIR
# - WAIT_SHUTDOWN_MAX_SEC

function snapshot_machine { # ${machine}

	if [[ -z ${1} ]]; then
		echo "Error: Missing required arg: machine"
		return 1
	fi

	if [[ -z ${SNAPSHOTS_BASE_DIR} || -z ${MACHINES_DATA_BASE_DIR} ]]; then
		echo "Error: Missing required global var: MACHINES_DATA_BASE_DIR || SNAPSHOTS_BASE_DIR"
		return 1
	fi

    local machine="${1}"
    local machine_data_path="${MACHINES_DATA_BASE_DIR}/${machine}"

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
		local wait_sleep=2
		local wait_count_max_sec=${WAIT_SHUTDOWN_MAX_SEC:-12}
        local wait_count_max=$(( wait_count_max_sec / wait_sleep )) # -> 12s / 2 -> 6 iterations with 2s wait

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
			# Restart the machine if it was running before we tried to snapshot
			if [ "${was_running}" = true ]; then
				echo "<6>Restarting machine: ${machine} after timeout/abort ..."
				start_machine "${machine}"
			fi
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
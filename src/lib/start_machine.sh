# Function to safely start a machine back up

function start_machine() {
    local machine="${1}"
    echo "Starting machine '${machine}'..."
    machinectl start ${machine} || {
        echo "ERROR: Failed to start machine '${machine}'!"
        return 1
    }
}
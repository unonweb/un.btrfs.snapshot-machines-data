function is_btrfs_subvolume {
	# must be run as root!
	local path="${1}"
    if [[ ! -d "${path}" ]]; then
        return 1
    fi
	
	# btrfs subvolume show returns 0 if it's a subvolume root, non-zero otherwise
    btrfs subvolume show "${path}" &>/dev/null
}
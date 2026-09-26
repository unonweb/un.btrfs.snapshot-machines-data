ABOUT
=====

This script takes snapshots of user data of systemd-nspawn containers.
This user data is stored outside of these containers and bind mounted inside.
This script makes sure that running containers are stopped before taking snapshots and restarted afterwards.

REQUIRES / EXPECTS
==================

- systemd-nspawn containers
- user data in `MACHINES_DATA_DIR` for each container 
- where `${MACHINES_DATA_DIR}/<container>` must be a btrfs subvolume
- and `<container>` must match the name of the systemd-nspawn container
- call this script with a systemd timer unit 
- provide the container names whose user data that shall be snapshoted with this call
- configuring different timer units you can have different snaphot intervalls for your containers

CONFIG
======

```sh
# defaults:
MACHINES_DATA_DIR="/srv/data"
SNAPSHOTS_BASE_DIR="/.snapshots"
```

NOTES
=====

- **trap**: If the script is interrupted while a container is shut down, the trap ensures the machine is safely powered back on.
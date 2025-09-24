#!/bin/sh
# =============================================================================
# ghettoVCB Backup & Restore Wrapper
#
# David Harrop
# August 2025
#
# Description:
#   Wrapper around ghettoVCB to simplify backing up and restoring ESXi VMs.
#   Features include:
#     - Backup & restore with exclusions
#     - Backup & restore individual vms or all
#     - Handles VM names with spaces
#     - Dry-run mode for preview without execution
#     - Prompt to rename vm(s) and edit the restore file prior to restore
#     - Cleans up orphan vmkfstools processes or /tmp/ghetto* files after script interruption
#
# Usage:
#   ./ghettoVCB-Express.sh --all                                                    # Back up all VMs
#   ./ghettoVCB-Express.sh --name vmname | --name "vm name"                         # Back up a specific VM (with or without spaces)
#   ./ghettoVCB-Express.sh --name vmname1 --name vmname2                            # Back up a selection of VMs
#   ./ghettoVCB-Express.sh --all                                                    # Restore all VMs
#   ./ghettoVCB-Express.sh --restore --name vmmname                                 # Restore a specific VM
#   ./ghettoVCB-Express.sh --restore --name vmname1 --name vmname2                  # Restore a selection of VMs
#   ./ghettoVCB-Express.sh --dry-run --all | --name vmname                          # Preview backup targets
#   ./ghettoVCB-Express.sh --restore --dry-run --all | --name vmname                # Preview restore targets
#   ./ghettoVCB-Express.sh --kill                                                   # Free any hung backup processes or locked files
#   ./ghettoVCB-Express.sh --help                                                   # Show these options
#
# Requirements:
#   - ghettoVCB.sh, ghettoVCB-restore.sh, and ghettoVCB.conf placed in the same directory
#   - Must run on an ESXi host with vim-cmd available
#   - Must only run one instance of this script at a time
# =============================================================================

# ======== Excluded from backup or restore (exact names, one per line) ========
EXCLUDE_VMS="
Router1
"

set -eu
[ -t 1 ] && clear

# Set a few important script variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VCB_CONF="$SCRIPT_DIR/ghettoVCB.conf"
DEFAULT_RECOVERY_DATASTORE="Datastore1"
DEFAULT_RECOVERY_FOLDER=""
DEFAULT_RECOVERY_DATASTORE_PATH="/vmfs/volumes/$DEFAULT_RECOVERY_DATASTORE/$DEFAULT_RECOVERY_FOLDER"
RESTORE_DISK_FORMAT="3" # 1 = zeroedthick, 2 = 2gbsparse, 3 = thin, 4 = eagerzeroedthick
DELETE_UNZIPPED="true"  # Delete decompressed backup copy after each VM restore to prevent disk space blowout

# Gather all exlcuded VMs
is_excluded() {
    vm="$1"
    while IFS= read -r ex; do
        [ -z "$ex" ] && continue
        [ "$vm" = "$ex" ] && return 0
    done <<EOF
$EXCLUDE_VMS
EOF
    return 1
}

# Check to make sure vcb.conf is set
[ ! -f "$VCB_CONF" ] && {
    echo "Error: ghettoVCB.conf not found"
    exit 1
}

# Get the backup volume from ghettoVCB.conf
VM_BACKUP_VOLUME=$(
    grep -E '^VM_BACKUP_VOLUME=' "$VCB_CONF" |
        cut -d'=' -f2- |
        sed 's/^"[[:space:]]*//; s/[[:space:]]*"//; s/[[:space:]]*$//'
)
# Ensure no trailing slash in backup path
VM_BACKUP_VOLUME="${VM_BACKUP_VOLUME%/}"

# Check that a backup volume value was read from vcb.conf
[ -z "$VM_BACKUP_VOLUME" ] && {
    echo "Error: VM_BACKUP_VOLUME not set in $VCB_CONF"
    exit 1
}

# Parse script arguments
RESTORE_MODE=0
DRYRUN_MODE=0
ARG_MODE=""
ARG_VM_LIST=""

usage() {
    echo "Usage: $0 [--restore] [--dry-run] [--all | --name <vmname>]"
    echo
    echo "Examples:"
    echo "  $0 --all                                        # Back up all VMs"
    echo "  $0 --name <vmname> | <\"vm name\">                # Back up a specific VM (with or without spaces)"
    echo "  $0 --name <vmname1> --name <vmname2>            # Back up a selection of VMs"
    echo "  $0 --restore --all                              # Restore all VMs"
    echo "  $0 --restore --name <vmname>                    # Restore a specific VM"
    echo "  $0 --restore --name <vmname1> --name <vnname2>  # Restore a selection of VMs"
    echo "  $0 --dry-run --all | --name <vmname>            # Preview backup targets"
    echo "  $0 --restore --dry-run --all | --name <vmname>  # Preview restore targets"
    echo "  $0 --kill                                       # Kill any hung backup processes & unlock files"
    echo "  $0 --help                                       # Show this help message"
    echo
    exit 0
}

cleanup_vmkfstools() {
    # Clear out leftover temp files or processes from previous (interrupted) ghettoVCB runs
 echo "---------------------------------------------------------------------------------------------------------------"
    echo "Cleaning temporary files..."
    rm -rf /tmp/ghettoVCB.work* 2>/dev/null

    echo "Checking for leftover vmkfstools processes..."
    while true; do
        # get PIDs safely
        pids=$(ps | grep vmkfstools | grep -v grep | awk '{print $1}' || true)
        [ -z "$pids" ] && break
        for pid in $pids; do
            echo "  Killing PID $pid"
            kill -9 "$pid" 2>/dev/null || true # ignore errors
            sleep 0.2
        done
        sleep 0.5
    done
}

cleanup() {
 echo "---------------------------------------------------------------------------------------------------------------"
    echo "Running cleanup..."

    # Kill leftover processes
    cleanup_vmkfstools || true

    # Unmount NFS if enabled
    if [ "${UNMOUNT_NFS:-0}" = "1" ] && [ -n "${NFS_LOCAL_NAME:-}" ]; then
        echo "Unmounting NFS datastore: $NFS_LOCAL_NAME"
        esxcli storage nfs remove --volume-name="$NFS_LOCAL_NAME" 2>/dev/null || true
    fi

    # Remove working lists safely
    rm -f "${BACKUPLIST:-}" "${RESTORELIST:-}" current_restore_task.txt 2>/dev/null || true

    echo "Cleanup complete."
    echo
}

# Show script usage if no arguments
echo
[ $# -eq 0 ] && usage

RECOVERY_DATASTORE="$DEFAULT_RECOVERY_DATASTORE"
RECOVERY_DATASTORE_PATH="$DEFAULT_RECOVERY_DATASTORE_PATH"
[ -z "$RECOVERY_DATASTORE" ] && {
    echo "Error: RECOVERY_DATASTORE not set"
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
    --all)
        ARG_MODE="all"
        ;;
    --dry-run)
        DRYRUN_MODE=1
        ;;
    --help)
        usage
        ;;
    --kill)
        echo "Killing leftover backup processes and cleaning temporary files..."
        echo
        cleanup_vmkfstools
        echo "Cleanup complete. Exiting."
        exit 0
        ;;
    --restore)
        RESTORE_MODE=1
        RECOVERY_DATASTORES=$(esxcli storage filesystem list | awk '$1 ~ /^\/vmfs/ && $2 !~ /^(BOOTBANK|OSDATA)/ {print $2}')
        echo "Available recovery datastores:"
        PS=1
        for DS in $RECOVERY_DATASTORES; do
            echo "$PS) $DS"
            PS=$((PS + 1))
        done

        while true; do
            read -p "Select datastore number: " NUM
            if [ "$NUM" -ge 1 ] 2>/dev/null && [ "$NUM" -le $(echo "$RECOVERY_DATASTORES" | wc -l) ]; then
                RECOVERY_DATASTORE=$(echo "$RECOVERY_DATASTORES" | sed -n "${NUM}p")
                RECOVERY_DATASTORE_PATH="/vmfs/volumes/$RECOVERY_DATASTORE/$DEFAULT_RECOVERY_FOLDER"
                echo "You selected: $RECOVERY_DATASTORE"
                break
            else
                echo "Invalid selection, try again."
            fi
        done
        ;;

    --name)
        shift
        [ -z "$1" ] && {
            echo "Error: VM name required after --name"
            exit 1
        }
        if is_excluded "$1"; then
            echo "Error: VM '$1' is excluded."
            exit 1
        fi
        ARG_MODE="name"
        # Append using newline
        if [ -z "$ARG_VM_LIST" ]; then
            ARG_VM_LIST="$1"
        else
            ARG_VM_LIST="$ARG_VM_LIST
$1"
        fi
        ;;
    *) usage ;;
    esac
    shift
done

# Ensure required mode args are set
[ -z "$ARG_MODE" ] && usage

# Catch all exit paths
trap 'cleanup' INT TERM EXIT

# Tidy up any orphan processes next
cleanup_vmkfstools || true

# Show excluded VMs
echo
echo "Excluded VMs:"
echo "$EXCLUDE_VMS" | sed '/^$/d' | while IFS= read -r ex; do echo "  - $ex"; done

# Ensure no trailing slash in recovery datastore path
RECOVERY_DATASTORE_PATH="${RECOVERY_DATASTORE_PATH%/}/"

# Show backup and restore datastores
echo "Backup datastore (backup target from ghettoVCB.conf):"
echo "  - $VM_BACKUP_VOLUME"
echo
echo "Recovery datastore (subfolder set in DEFAULT_RECOVERY_FOLDER):"
echo "  - $RECOVERY_DATASTORE_PATH"
echo "---------------------------------------------------------------------------------------------------------------"
echo

# Warn if backup and restore datastores are the same
if [ "$(readlink -f "$VM_BACKUP_VOLUME")" = "$(readlink -f "$RECOVERY_DATASTORE_PATH")" ]; then
    echo "************************************************************"
    echo "WARNING: Backup volume and recovery datastore are the SAME!"
    echo "  Backup:  $VM_BACKUP_VOLUME"
    echo "  Recovery: $RECOVERY_DATASTORE_PATH"
    echo
    echo "Restoring into the same datastore as backups may overwrite or"
    echo "corrupt your backups. Review your configuration carefully."
    echo "************************************************************"
    echo
fi

# Backup list generator
BACKUPLIST="$SCRIPT_DIR/backuplist.txt"
generate_backuplist() {
    >"$BACKUPLIST"

    if [ "$RESTORE_MODE" -eq 1 ]; then
        # In restore mode, build list from backup storage
        echo "Building list of available backups from repository: $VM_BACKUP_VOLUME"
        find "$VM_BACKUP_VOLUME" -maxdepth 1 -mindepth 1 -type d | while IFS= read -r vm_dir; do
            vm="$(basename "$vm_dir")"
            if ! is_excluded "$vm"; then
                echo "$vm" >>"$BACKUPLIST"
            fi
        done
    else
        # In backup mode, build list from registered VMs
        vim-cmd vmsvc/getallvms | awk '
        NR>1 && $1 ~ /^[0-9]+$/ {
            name=""
            for(i=2;i<=NF;i++){
                if($i ~ /^\[/) break
                name = (name=="" ? $i : name " " $i)
            }
            if(name != "") print name
        }' | while IFS= read -r vm; do
            vm="$(echo "$vm" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")"
            if ! is_excluded "$vm"; then
                echo "$vm" >>"$BACKUPLIST"
            fi
        done
    fi
}
# Output the selection array to the backup list
[ "$ARG_MODE" = "all" ] && generate_backuplist || {
    : >"$BACKUPLIST"
    echo "$ARG_VM_LIST" >>"$BACKUPLIST"
}

# Handle Non-Persistent NFS Mounts. Only runs if NFS is enabled in ghettoVCB.conf (also ignores any comments on these lines in ghettoVCB.conf)
ENABLE_NON_PERSISTENT_NFS=$(grep -E '^ENABLE_NON_PERSISTENT_NFS=' "$VCB_CONF" | sed 's/#.*//;s/^.*=//')

if [ "$ENABLE_NON_PERSISTENT_NFS" = "1" ]; then
    echo "Non-persistent NFS restore enabled. Preparing to mount NFS datastore..."

    # Read NFS settings from config, ignoring comments and spaces
    UNMOUNT_NFS=$(grep -E '^UNMOUNT_NFS=' "$VCB_CONF" | sed 's/#.*//;s/^.*=//')
    NFS_SERVER=$(grep -E '^NFS_SERVER=' "$VCB_CONF" | sed 's/#.*//;s/^.*=//')
    NFS_MOUNT=$(grep -E '^NFS_MOUNT=' "$VCB_CONF" | sed 's/#.*//;s/^.*=//')
    NFS_LOCAL_NAME=$(grep -E '^NFS_LOCAL_NAME=' "$VCB_CONF" | sed 's/#.*//;s/^.*=//')
    NFS_VM_BACKUP_DIR=$(grep -E '^NFS_VM_BACKUP_DIR=' "$VCB_CONF" | sed 's/#.*//;s/^.*=//')

    # Check if already mounted
    if esxcli storage nfs list | awk '{print $1}' | grep -qw "$NFS_LOCAL_NAME"; then
        echo "NFS datastore $NFS_LOCAL_NAME is already mounted. Skipping mount."
    else
        # Mount NFS datastore
        echo "Mounting NFS $NFS_SERVER:$NFS_MOUNT as $NFS_LOCAL_NAME..."
        esxcli storage nfs add --host="$NFS_SERVER" --share="$NFS_MOUNT" --volume-name="$NFS_LOCAL_NAME"

        # Verify mount succeeded
        if ! esxcli storage nfs list | grep -qw "$NFS_LOCAL_NAME"; then
            echo "Error: Failed to mount NFS datastore $NFS_LOCAL_NAME"
            exit 1
        fi
    fi

    # Update VM_BACKUP_VOLUME to point to the NFS backup path
    VM_BACKUP_VOLUME="/vmfs/volumes/$NFS_LOCAL_NAME/$NFS_VM_BACKUP_DIR"
    echo "VM_BACKUP_VOLUME set to: $VM_BACKUP_VOLUME"

fi

# Restore list generator
RESTORELIST="$SCRIPT_DIR/restorelist.txt"
generate_restorelist() {
    : >"$RESTORELIST"

    if [ ! -f "$BACKUPLIST" ]; then
        echo "Error: BACKUPLIST '$BACKUPLIST' not found" >&2
        return 1
    fi

    while IFS= read -r vm || [ -n "$vm" ]; do
        [ -z "$vm" ] && continue

        # Find the VM backup directory
        vm_dir=$(find "$VM_BACKUP_VOLUME" -maxdepth 1 -type d -name "$vm" 2>/dev/null | head -n1)

        if [ -z "$vm_dir" ]; then
            echo "Warning: No backup directory found for '$vm', skipping" >&2
            continue
        fi

        # Check for already decompressed version (directory containing .vmx)
        decompressed_dir=$(find "$vm_dir" -maxdepth 1 -type d -exec sh -c 'ls "$1"/*.vmx >/dev/null 2>&1 && echo "$1"' _ {} \; | sort | tail -n1)

        if [ -n "$decompressed_dir" ]; then
            latest_backup="$decompressed_dir"
            echo "Using decompressed backup for '$vm': $latest_backup"
        else
            # Fall back to .gz or .tgz files
            latest_backup=$(find "$vm_dir" -maxdepth 1 -type f \( -name "${vm}*.gz" -o -name "${vm}*.tgz" \) 2>/dev/null | sort | tail -n1)
            if [ -n "$latest_backup" ]; then
                echo "Using compressed backup for '$vm': $latest_backup"
            else
                echo "Warning: No backup found for '$vm', skipping" >&2
                continue
            fi
        fi

        # Prompt for rename
        read -rp "Restore '$vm' as (press Enter to keep original name): " new_vm </dev/tty
        [ -z "$new_vm" ] && new_vm="$vm"

        # Clean VM name
        new_vm_clean=$(echo "$new_vm" | sed 's#^/*##; s#/*$##')

        # Ensure the base recovery folder exists
        mkdir -p "$RECOVERY_DATASTORE_PATH" || {
            echo "Error: Failed to create base recovery path '$RECOVERY_DATASTORE_PATH'"
            exit 1
        }

        # Write entry to restorelist
        # IMPORTANT: pass the base path, not per-VM
        printf '"%s;%s;%s;%s"\n' \
            "$latest_backup" \
            "$RECOVERY_DATASTORE_PATH" \
            "$RESTORE_DISK_FORMAT" \
            "$new_vm_clean" >>"$RESTORELIST"

    done <"$BACKUPLIST"

    echo
    echo "restorelist.txt generated with $(wc -l <"$RESTORELIST") entries"

    # Allow manual editing
    read -rp "Do you want to manually edit restorelist before continuing? (y/N): " edit_choice </dev/tty
    echo
    case "$edit_choice" in
    [yY]*) ${EDITOR:-vi} "$RESTORELIST" ;;
    esac
}

# Dry-run
if [ "$DRYRUN_MODE" -eq 1 ]; then
    if [ "$RESTORE_MODE" -eq 1 ]; then
        echo "[DRY-RUN] Restore would be run on the following VMs:"
        generate_restorelist
        echo
        cat "$RESTORELIST"
    else
        echo "[DRY-RUN] Backup would be run on the following VMs:"
        cat "$BACKUPLIST"
    fi
    exit 0
fi

# Execute backup/restore
if [ "$RESTORE_MODE" -eq 1 ]; then
    echo "Running ghettoVCB-restore..."
    generate_restorelist

    # Process each VM individually
    while IFS=";" read -r backup_path recovery_path diskfmt vmname; do
        # Strip quotes
        backup_path=$(echo "$backup_path" | sed 's/^"//; s/"$//')
        recovery_path=$(echo "$recovery_path" | sed 's/^"//; s/"$//')
        vmname=$(echo "$vmname" | sed 's/^"//; s/"$//')

        echo "---------------------------------------------------------------------------------------------------------------"
        echo "Restoring VM '$vmname'..."
        echo "Backup path: $backup_path"
        echo "Recovery path: $recovery_path"

        # Create a temporary restore task file
        echo "\"$backup_path\";\"$recovery_path\";\"$diskfmt\";\"$vmname\"" >"$SCRIPT_DIR/current_restore_task.txt"

        # Run the restore
        "$SCRIPT_DIR/ghettoVCB-restore.sh" -c "$SCRIPT_DIR/current_restore_task.txt"

        # Normalize VMX file
        vmx_file="$recovery_path/$vmname/$vmname.vmx"
        [ -f "$vmx_file" ] && sed -i 's/[[:space:]]*=[[:space:]]*/ = /g' "$vmx_file"

        # Delete decompressed folder if requested
        if [ "$DELETE_UNZIPPED" = "true" ]; then
            # The extracted folder is a subdirectory under the VM backup dir
            backup_dir=$(dirname "$backup_path")  # /vmfs/.../Vmname
            # Find subdirectory starting with vmname- (the extracted folder)
            decompressed_dir=$(find "$backup_dir" -maxdepth 1 -type d -name "$vmname-*" | sort | tail -n1)

            if [ -n "$decompressed_dir" ] && [ -d "$decompressed_dir" ]; then
                rm -rf "$decompressed_dir"
                echo "Deleted decompressed backup copy for VM '$vmname': $decompressed_dir"
				echo
            else
                echo "No decompressed backup found to delete for VM '$vmname'"
				echo
            fi
        fi

    
    done <"$RESTORELIST"

    ACTION="Restore"
else
    echo "Running ghettoVCB backup with $BACKUPLIST..."
    "$SCRIPT_DIR/ghettoVCB.sh" -g "$VCB_CONF" -f "$BACKUPLIST"
    ACTION="Backup"
fi

echo "$ACTION completed. VMs processed:"
cat "$BACKUPLIST"
echo
# Author: William Lam
# Created Date: 11/17/2008
# http://www.virtuallyghetto.com/
# http://communities.vmware.com/docs/DOC-8760
##################################################################

# directory that all VM backups should go (e.g. /vmfs/volumes/SAN_LUN1/mybackupdir)
VM_BACKUP_VOLUME=/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS

# Format output of VMDK backup
# zeroedthick
# 2gbsparse
# thin
# eagerzeroedthick
DISK_BACKUP_FORMAT=thin

# Number of backups for a given VM before deleting
VM_BACKUP_ROTATION_COUNT=3

# Shutdown guestOS prior to running backups and power them back on afterwards
# This feature assumes VMware Tools are installed, else they will not power down and loop forever
# 1=on, 0 =off
POWER_VM_DOWN_BEFORE_BACKUP=0

# enable shutdown code 1=on, 0 = off
ENABLE_HARD_POWER_OFF=0

# if the above flag "ENABLE_HARD_POWER_OFF "is set to 1, then will look at this flag which is the # of iterations
# the script will wait before executing a hard power off, this will be a multiple of 60seconds 
# (e.g) = 3, which means this will wait up to 180seconds (3min) before it just powers off the VM
ITER_TO_WAIT_SHUTDOWN=3

# Number of iterations the script will wait before giving up on powering down the VM and ignoring it for backup
# this will be a multiple of 60 (e.g) = 5, which means this will wait up to 300secs (5min) before it gives up
POWER_DOWN_TIMEOUT=5

# enable compression with gzip+tar 1=on, 0=off
ENABLE_COMPRESSION=0

############################
####### NEW PARAMS #########
############################

# Include VMs memory when taking snapshot
VM_SNAPSHOT_MEMORY=0

# Quiesce VM when taking snapshot (requires VMware Tools to be installed)
VM_SNAPSHOT_QUIESCE=0

##########################################################
# NON-PERSISTENT NFS-BACKUP ONLY
# 
# ENABLE NON PERSISTENT NFS BACKUP 1=on, 0=off

ENABLE_NON_PERSISTENT_NFS=0

# umount NFS datastore after backup is complete 1=yes, 0=no
UNMOUNT_NFS=0

# IP Address of NFS Server
NFS_SERVER=172.51.0.192

# Path of exported folder residing on NFS Server (e.g. /some/mount/point )
NFS_MOUNT=/upload

# Non-persistent NFS datastore display name of choice
NFS_LOCAL_NAME=backup

# Name of backup directory for VMs residing on the NFS volume
NFS_VM_BACKUP_DIR=mybackups 


############################
######### EMAIL ############
############################ 

# Email log 1=yes, 0=no 
EMAIL_LOG=0

# Email Delay Interval from NC (netcat) - default 1
EMAIL_DELAY_INTERVAL=1

# Email SMTP server
EMAIL_SERVER=auroa.primp-industries.com

# Email SMTP server port
EMAIL_SERVER_PORT=25

# Email FROM
EMAIL_FROM=root@ghettoVCB

# Email RCPT
EMAIL_TO=auroa@primp-industries.com


############################
######### DEBUG ############
############################ 

# Do not remove workdir on exit: 1=yes, 0=no 
WORKDIR_DEBUG=0

########################## DO NOT MODIFY PAST THIS LINE ##########################

# RSYNC LINK 1=yes, 0 = no
RSYNC_LINK=0

LOG_LEVEL="info"
VMDK_FILES_TO_BACKUP="all"
# default 15min timeout
SNAPSHOT_TIMEOUT=15

LAST_MODIFIED_DATE=2011_11_19
VERSION=1
VERSION_STRING=${LAST_MODIFIED_DATE}_${VERSION}

# Directory naming convention for backup rotations (please ensure there are no spaces!)
VM_BACKUP_DIR_NAMING_CONVENTION="$(date +%F_%H-%M-%S)"

printUsage() {
        echo "###############################################################################"
        echo "#"
        echo "# ghettoVCB for ESX/ESXi 3.5, 4.x+ and 5.0"
        echo "# Author: William Lam"
        echo "# http://www.virtuallyghetto.com/"
        echo "# Documentation: http://communities.vmware.com/docs/DOC-8760"
        echo "# Created: 11/17/2008"
        echo "# Last modified: ${LAST_MODIFIED_DATE} Version ${VERSION}"
        echo "#"
        echo "###############################################################################"
        echo
        echo "Usage: $(basename $0) [options]"
        echo
        echo "OPTIONS:"
        echo "   -a     Backup all VMs on host"
        echo "   -f     List of VMs to backup"
        echo "   -m     Name of VM to backup (overrides -f)"
        echo "   -c     VM configuration directory for VM backups"
        echo "   -g     Path to global ghettoVCB configuration file"
        echo "   -l     File to output logging"
        echo "   -w     ghettoVCB work directory (default: ${WORKDIR})"
        echo "   -d     Debug level [info|debug|dryrun] (default: info)"
        echo
        echo "(e.g.)"
        echo -e "\nBackup VMs stored in a list"
        echo -e "\t$0 -f vms_to_backup"
        echo -e "\nBackup a single VM"
        echo -e "\t$0 -m vm_to_backup"
        echo -e "\nBackup all VMs residing on this host"
        echo -e "\t$0 -a"
        echo -e "\nBackup all VMs residing on this host except for the VMs in the exclusion list"
        echo -e "\t$0 -a -e vm_exclusion_list"
        echo -e "\nBackup VMs based on specific configuration located in directory"
        echo -e "\t$0 -f vms_to_backup -c vm_backup_configs"
        echo -e "\nBackup VMs using global ghettoVCB configuration file"
        echo -e "\t$0 -f vms_to_backup -g /global/ghettoVCB.conf"
        echo -e "\nOutput will log to /tmp/ghettoVCB.log (consider logging to local or remote datastore to persist logs)"
        echo -e "\t$0 -f vms_to_backup -l /vmfs/volume/local-storage/ghettoVCB.log"
        echo -e "\nDry run (no backup will take place)"
        echo -e "\t$0 -f vms_to_backup -d dryrun"
        echo
        exit 1
}

logger() {
    LOG_TYPE=$1
    MSG=$2

    if [[ "${LOG_LEVEL}" == "debug" ]] && [[ "${LOG_TYPE}" == "debug" ]] || [[ "${LOG_TYPE}" == "info" ]] || [[ "${LOG_TYPE}" == "dryrun" ]]; then
        TIME=$(date +%F" "%H:%M:%S)
        if [[ "${LOG_TO_STDOUT}" -eq 1 ]] ; then
            echo -e "${TIME} -- ${LOG_TYPE}: ${MSG}"
        fi

        if [[ -n "${LOG_OUTPUT}" ]] ; then
            echo -e "${TIME} -- ${LOG_TYPE}: ${MSG}" >> "${LOG_OUTPUT}"
        fi

        if [[ "${EMAIL_LOG}" -eq 1 ]] ; then
            echo -ne "${TIME} -- ${LOG_TYPE}: ${MSG}\r\n" >> "${EMAIL_LOG_OUTPUT}"      
        fi
    fi
}

sanityCheck() {
    NUM_OF_ARGS=$1

    # refuse to run with an unsafe workdir
    if [[ "${WORKDIR}" == "/" ]]; then
        echo "ERROR: Refusing to run with unsafe workdir ${WORKDIR}"
        exit 1
    fi

    if [[ "${USE_GLOBAL_CONF}" -eq 1 ]] ; then
        reConfigureGhettoVCBConfiguration "${GLOBAL_CONF}"
    fi

    # always log to STDOUT, use "> /dev/null" to ignore output
    LOG_TO_STDOUT=1
    
    #if no logfile then provide default logfile in /tmp
    if [[ -z "${LOG_OUTPUT}" ]] ; then
        LOG_OUTPUT="/tmp/ghettoVCB-$(date +%F_%H-%M-%S)-$$.log"
        echo "Logging output to \"${LOG_OUTPUT}\" ..."
    fi

    touch "${LOG_OUTPUT}"
    # REDIRECT is used by the "tail" trick, use REDIRECT=/dev/null to redirect vmkfstool to STDOUT only
    REDIRECT=${LOG_OUTPUT}

    if [[ ${NUM_OF_ARGS} -lt 1 ]] || [[ ${NUM_OF_ARGS} -gt 12 ]]; then
        logger "info" "ERROR: Incorrect number of arguments!"
        printUsage
    fi

    if [[ ! -f "${VM_FILE}" ]] && [[ "${USE_VM_CONF}" -eq 0 ]] && [[ "${BACKUP_ALL_VMS}" -eq 0 ]]; then
        logger "info" "ERROR: \"${VM_FILE}\" is not valid VM input file!"
        printUsage
    fi

    if [[ ! -f "${VM_EXCLUSION_FILE}" ]] && [[ "${EXCLUDE_SOME_VMS}" -eq 1 ]]; then
        logger "info" "ERROR: \"${VM_EXCLUSION_FILE}\" is not valid VM exclusion input file!"
        printUsage
    fi

    if [[ ! -d "${CONFIG_DIR}" ]] && [[ "${USE_VM_CONF}" -eq 1 ]]; then
        logger "info" "ERROR: \"${CONFIG_DIR}\" is not valid directory!"
        printUsage
    fi

    if [[ ! -f "${GLOBAL_CONF}" ]] && [[ "${USE_GLOBAL_CONF}" -eq 1 ]]; then
        logger "info" "ERROR: \"${GLOBAL_CONF}\" is not valid global configuration file!"
        printUsage
    fi

    if [[ -f /usr/bin/vmware-vim-cmd ]]; then
        VMWARE_CMD=/usr/bin/vmware-vim-cmd
        VMKFSTOOLS_CMD=/usr/sbin/vmkfstools
    elif [[ -f /bin/vim-cmd ]]; then
        VMWARE_CMD=/bin/vim-cmd
        VMKFSTOOLS_CMD=/sbin/vmkfstools
    else
        logger "info" "ERROR: Unable to locate *vimsh*! You're not running ESX(i) 3.5+, 4.x+ or 5.0!"
        echo "ERROR: Unable to locate *vimsh*! You're not running ESX(i) 3.5+, 4.x+ or 5.0!"
        exit 1
    fi

    ESX_VERSION=$(vmware -v | awk '{print $3}')
    if [[ "${ESX_VERSION}" == "5.0.0" ]]; then
        VER=5
        elif [[ "${ESX_VERSION}" == "4.0.0" ]] || [[ "${ESX_VERSION}" == "4.1.0" ]]; then
            VER=4
        else
            ESX_VERSION=$(vmware -v | awk '{print $4}')
            if [[ "${ESX_VERSION}" == "3.5.0" ]] || [[ "${ESX_VERSION}" == "3i" ]]; then
                VER=3
            else
                echo "You're not running ESX(i) 3.5, 4.x, 5.x!"
                exit 1
            fi
        fi

    NEW_VIMCMD_SNAPSHOT="no"
    ${VMWARE_CMD} vmsvc/snapshot.remove | grep "snapshotId" > /dev/null 2>&1
    [[ $? -eq 0 ]] && NEW_VIMCMD_SNAPSHOT="yes"

    if [[ "${EMAIL_LOG}" -eq 1 ]] && [[ -f /usr/bin/nc ]] || [[ -f /bin/nc ]]; then
        if [[ -f /usr/bin/nc ]] ; then
            NC_BIN=/usr/bin/nc
        elif [[ -f /bin/nc ]] ; then 
            NC_BIN=/bin/nc
        fi
    else 
        EMAIL_LOG=0
    fi

    if [[ ! $(whoami) == "root" ]] ; then
        logger "info" "This script needs to be executed by \"root\"!"
    echo "ERROR: This script needs to be executed by \"root\"!"
        exit 1
    fi
}

startTimer() {
    START_TIME=$(date)
    S_TIME=$(date +%s)
}

endTimer() {
    END_TIME=$(date)
    E_TIME=$(date +%s)
    DURATION=$(echo $((E_TIME - S_TIME)))

    #calculate overall completion time
    if [[ ${DURATION} -le 60 ]] ; then
        logger "info" "Backup Duration: ${DURATION} Seconds"
    else
        logger "info" "Backup Duration: $(awk 'BEGIN{ printf "%.2f\n", '${DURATION}'/60}') Minutes"
    fi
}

captureDefaultConfigurations() {
    DEFAULT_VM_BACKUP_VOLUME="${VM_BACKUP_VOLUME}"
    DEFAULT_DISK_BACKUP_FORMAT="${DISK_BACKUP_FORMAT}"
    DEFAULT_VM_BACKUP_ROTATION_COUNT="${VM_BACKUP_ROTATION_COUNT}"
    DEFAULT_POWER_VM_DOWN_BEFORE_BACKUP="${POWER_VM_DOWN_BEFORE_BACKUP}"
    DEFAULT_ENABLE_HARD_POWER_OFF="${ENABLE_HARD_POWER_OFF}"
    DEFAULT_ITER_TO_WAIT_SHUTDOWN="${ITER_TO_WAIT_SHUTDOWN}"
    DEFAULT_POWER_DOWN_TIMEOUT="${POWER_DOWN_TIMEOUT}"
    DEFAULT_SNAPSHOT_TIMEOUT="${SNAPSHOT_TIMEOUT}"
    DEFAULT_ENABLE_COMPRESSION="${ENABLE_COMPRESSION}"
    DEFAULT_VM_SNAPSHOT_MEMORY="${VM_SNAPSHOT_MEMORY}"
    DEFAULT_VM_SNAPSHOT_QUIESCE="${VM_SNAPSHOT_QUIESCE}"
    DEFAULT_VMDK_FILES_TO_BACKUP="${VMDK_FILES_TO_BACKUP}"
    DEFAULT_EMAIL_LOG="${EMAIL_LOG}"
    DEFAULT_WORKDIR_DEBUG="${WORKDIR_DEBUG}"
}

useDefaultConfigurations() {
    VM_BACKUP_VOLUME="${DEFAULT_VM_BACKUP_VOLUME}"
    DISK_BACKUP_FORMAT="${DEFAULT_DISK_BACKUP_FORMAT}"
    VM_BACKUP_ROTATION_COUNT="${DEFAULT_VM_BACKUP_ROTATION_COUNT}"
    POWER_VM_DOWN_BEFORE_BACKUP="${DEFAULT_POWER_VM_DOWN_BEFORE_BACKUP}"
    ENABLE_HARD_POWER_OFF="${DEFAULT_ENABLE_HARD_POWER_OFF}"
    ITER_TO_WAIT_SHUTDOWN="${DEFAULT_ITER_TO_WAIT_SHUTDOWN}"
    POWER_DOWN_TIMEOUT="${DEFAULT_POWER_DOWN_TIMEOUT}"
    SNAPSHOT_TIMEOUT="${DEFAULT_SNAPSHOT_TIMEOUT}"
    ENABLE_COMPRESSION="${DEFAULT_ENABLE_COMPRESSION}"
    VM_SNAPSHOT_MEMORY="${DEFAULT_VM_SNAPSHOT_MEMORY}"
    VM_SNAPSHOT_QUIESCE="${DEFAULT_VM_SNAPSHOT_QUIESCE}"
    VMDK_FILES_TO_BACKUP="all"
    EMAIL_LOG=0
    WORKDIR_DEBUG=0
}

reConfigureGhettoVCBConfiguration() {
    GLOBAL_CONF=$1
    
    if [[ -f "${GLOBAL_CONF}" ]]; then
        source "${GLOBAL_CONF}"
    else
        useDefaultConfigurations
    fi
}

reConfigureBackupParam() {
    VM=$1

    if [[ -e "${CONFIG_DIR}/${VM}" ]]; then
        logger "info" "CONFIG - USING CONFIGURATION FILE = ${CONFIG_DIR}/${VM}"
        source "${CONFIG_DIR}/${VM}"
    else
        useDefaultConfigurations
    fi
}

dumpHostInfo() {
    VERSION=$(vmware -v)
    logger "debug" "HOST VERSION: ${VERSION}"
    echo ${VERSION} | grep "Server 3i" > /dev/null 2>&1
    [[ $? -eq 1 ]] && logger "debug" "HOST LEVEL: $(vmware -l)"
    logger "debug" "HOSTNAME: $(hostname)\n"
}

findVMDK() {
    VMDK_TO_SEARCH_FOR=$1

    #if [[ "${USE_VM_CONF}" -eq 1 ]] ; then
    logger "debug" "findVMDK() - Searching for VMDK: \"${VMDK_TO_SEARCH_FOR}\" to backup"

    OLD_IFS2="${IFS}"
    IFS=","
    for k in ${VMDK_FILES_TO_BACKUP}; do
        VMDK_FILE=$(echo $k | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
        if [[ "${VMDK_FILE}" == "${VMDK_TO_SEARCH_FOR}" ]] ; then
            logger "debug" "findVMDK() - Found VMDK! - \"${VMDK_TO_SEARCH_FOR}\" to backup"
           isVMDKFound=1
        fi  
    done
    IFS="${OLD_IFS2}"
    #fi
}

getVMDKs() {
    #get all VMDKs listed in .vmx file
    VMDKS_FOUND=$(grep -iE '(scsi|ide)' "${VMX_PATH}" | grep -i fileName | awk -F " " '{print $1}')

    TMP_IFS=${IFS}
    IFS=${ORIG_IFS}
    #loop through each disk and verify that it's currently present and create array of valid VMDKS
    for DISK in ${VMDKS_FOUND}; do
        #extract the SCSI ID and use it to check for valid vmdk disk
        SCSI_ID=$(echo ${DISK%%.*})
        grep -i "${SCSI_ID}.present" "${VMX_PATH}" | grep -i "true" > /dev/null 2>&1

        #if valid, then we use the vmdk file
        if [[ $? -eq 0 ]]; then
            #verify disk is not independent
            grep -i "${SCSI_ID}.mode" "${VMX_PATH}" | grep -i "independent" > /dev/null 2>&1 
            if [[ $? -eq 1 ]]; then
                grep -i "${SCSI_ID}.deviceType" "${VMX_PATH}" | grep -i "scsi-hardDisk" > /dev/null 2>&1

                #if we find the device type is of scsi-disk, then proceed
                if [[ $? -eq 0 ]]; then
                    DISK=$(grep -i ${SCSI_ID}.fileName "${VMX_PATH}" | awk -F "\"" '{print $2}')
                    echo "${DISK}" | grep "\/vmfs\/volumes" > /dev/null 2>&1

                    if [[ $? -eq 0 ]]; then
                        DISK_SIZE_IN_SECTORS=$(cat "${DISK}" | grep "VMFS" | grep ".vmdk" | awk '{print $2}')
                    else
                        DISK_SIZE_IN_SECTORS=$(cat "${VMX_DIR}/${DISK}" | grep "VMFS" | grep ".vmdk" | awk '{print $2}')
                    fi

                    DISK_SIZE=$(echo "${DISK_SIZE_IN_SECTORS}" | awk '{printf "%.0f\n",$1*512/1024/1024/1024}')
                    VMDKS="${DISK}###${DISK_SIZE}:${VMDKS}"
                    TOTAL_VM_SIZE=$((TOTAL_VM_SIZE+DISK_SIZE))
                else
                    #if the deviceType is NULL for IDE which it is, thanks for the inconsistency VMware
                    #we'll do one more level of verification by checking to see if an ext. of .vmdk exists
                    #since we can not rely on the deviceType showing "ide-hardDisk"
                    grep -i ${SCSI_ID}.fileName "${VMX_PATH}" | grep -i ".vmdk" > /dev/null 2>&1

                    if [[ $? -eq 0 ]]; then
                        DISK=$(grep -i ${SCSI_ID}.fileName "${VMX_PATH}" | awk -F "\"" '{print $2}')
                        echo "${DISK}" | grep "\/vmfs\/volumes" > /dev/null 2>&1
                        if [[ $? -eq 0 ]]; then
                            DISK_SIZE_IN_SECTORS=$(cat "${DISK}" | grep "VMFS" | grep ".vmdk" | awk '{print $2}')
                        else
                            DISK_SIZE_IN_SECTORS=$(cat "${VMX_DIR}/${DISK}" | grep "VMFS" | grep ".vmdk" | awk '{print $2}')
                        fi
                        DISK_SIZE=$(echo "${DISK_SIZE_IN_SECTORS}" | awk '{printf "%.0f\n",$1*512/1024/1024/1024}')
                        VMDKS="${DISK}###${DISK_SIZE}:${VMDKS}"
                        TOTAL_VM_SIZE=$((TOTAL_VM_SIZE_IN+DISK_SIZE))
                   fi
                fi

            else
                #independent disks are not affected by snapshots, hence they can not be backed up
                DISK=$(grep -i ${SCSI_ID}.fileName "${VMX_PATH}" | awk -F "\"" '{print $2}')
                echo "${DISK}" | grep "\/vmfs\/volumes" > /dev/null 2>&1
                if [[ $? -eq 0 ]]; then
                    DISK_SIZE_IN_SECTORS=$(cat "${DISK}" | grep "VMFS" | grep ".vmdk" | awk '{print $2}')
                else
                    DISK_SIZE_IN_SECTORS=$(cat "${VMX_DIR}/${DISK}" | grep "VMFS" | grep ".vmdk" | awk '{print $2}')
                fi
                DISK_SIZE=$(echo "${DISK_SIZE_IN_SECTORS}" | awk '{printf "%.0f\n",$1*512/1024/1024/1024}')
                INDEP_VMDKS="${DISK}###${DISK_SIZE}:${INDEP_VMDKS}"
            fi
        fi
    done
    IFS=${TMP_IFS}
    logger "debug" "getVMDKs() - ${VMDKS}"
}

dumpVMConfigurations() {
    logger "info" "CONFIG - VERSION = ${VERSION_STRING}"
    logger "info" "CONFIG - GHETTOVCB_PID = ${GHETTOVCB_PID}"
    logger "info" "CONFIG - VM_BACKUP_VOLUME = ${VM_BACKUP_VOLUME}"
    if [[ "${ENABLE_NON_PERSISTENT_NFS}" -eq 1 ]]; then
        logger "info" "CONFIG - ENABLE_NON_PERSISTENT_NFS = ${ENABLE_NON_PERSISTENT_NFS}"
        logger "info" "CONFIG - UNMOUNT_NFS = ${UNMOUNT_NFS}"
        logger "info" "CONFIG - NFS_SERVER = ${NFS_SERVER}"
        logger "info" "CONFIG - NFS_MOUNT = ${NFS_MOUNT}"
    fi
    logger "info" "CONFIG - VM_BACKUP_ROTATION_COUNT = ${VM_BACKUP_ROTATION_COUNT}"
    logger "info" "CONFIG - VM_BACKUP_DIR_NAMING_CONVENTION = ${VM_BACKUP_DIR_NAMING_CONVENTION}"
    logger "info" "CONFIG - DISK_BACKUP_FORMAT = ${DISK_BACKUP_FORMAT}"
    logger "info" "CONFIG - POWER_VM_DOWN_BEFORE_BACKUP = ${POWER_VM_DOWN_BEFORE_BACKUP}"
    logger "info" "CONFIG - ENABLE_HARD_POWER_OFF = ${ENABLE_HARD_POWER_OFF}"
    logger "info" "CONFIG - ITER_TO_WAIT_SHUTDOWN = ${ITER_TO_WAIT_SHUTDOWN}"
    logger "info" "CONFIG - POWER_DOWN_TIMEOUT = ${POWER_DOWN_TIMEOUT}"
    logger "info" "CONFIG - SNAPSHOT_TIMEOUT = ${SNAPSHOT_TIMEOUT}"
    logger "info" "CONFIG - LOG_LEVEL = ${LOG_LEVEL}"
    logger "info" "CONFIG - BACKUP_LOG_OUTPUT = ${LOG_OUTPUT}"
    logger "info" "CONFIG - VM_SNAPSHOT_MEMORY = ${VM_SNAPSHOT_MEMORY}"
    logger "info" "CONFIG - VM_SNAPSHOT_QUIESCE = ${VM_SNAPSHOT_QUIESCE}"
    logger "info" "CONFIG - VMDK_FILES_TO_BACKUP = ${VMDK_FILES_TO_BACKUP}"
    logger "info" "CONFIG - EMAIL_LOG = ${EMAIL_LOG}"
    if [[ "${EMAIL_LOG}" -eq 1 ]]; then
        logger "info" "CONFIG - EMAIL_SERVER = ${EMAIL_SERVER}"
        logger "info" "CONFIG - EMAIL_SERVER_PORT = ${EMAIL_SERVER_PORT}"
        logger "info" "CONFIG - EMAIL_DELAY_INTERVAL = ${EMAIL_DELAY_INTERVAL}"
        logger "info" "CONFIG - EMAIL_FROM = ${EMAIL_FROM}"
        logger "info" "CONFIG - EMAIL_TO = ${EMAIL_TO}"
        logger "info" "CONFIG - WORKDIR_DEBUG = ${WORKDIR_DEBUG}"
    fi
    logger "info" ""
}

checkVMBackupRotation() {
    local BACKUP_DIR_PATH=$1
    local VM_TO_SEARCH_FOR=$2

    #default rotation if variable is not defined
    if [[ -z ${VM_BACKUP_ROTATION_COUNT} ]]; then
        VM_BACKUP_ROTATION_COUNT=1
    fi

    LIST_BACKUPS=$(ls -t "${BACKUP_DIR_PATH}" | grep "${VM_TO_SEARCH_FOR}-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}")
    BACKUPS_TO_KEEP=$(ls -t "${BACKUP_DIR_PATH}" | grep "${VM_TO_SEARCH_FOR}-[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}" | head -"${VM_BACKUP_ROTATION_COUNT}")

    ORIG_IFS=${IFS}
    IFS='
'
    for i in ${LIST_BACKUPS}; do
        FOUND=0
        for j in ${BACKUPS_TO_KEEP}; do
            [[ $i == $j ]] && FOUND=1
        done

        if [[ $FOUND -eq 0 ]]; then
            logger "debug" "Removing $BACKUP_DIR_PATH/$i"
            rm -rf "$BACKUP_DIR_PATH/$i"

            #NFS I/O error handling hack
            if [[ $? -ne 0 ]] ; then
                NFS_IO_HACK_COUNTER=0
                NFS_IO_HACK_STATUS=0
                NFS_IO_HACK_FILECHECK="$BACKUP_DIR_PATH/nfs_io.check"       

                while [[ "${NFS_IO_HACK_STATUS}" -eq 0 ]] && [[ "${NFS_IO_HACK_COUNTER}" -lt 60 ]]; do
                    sleep 1
                    NFS_IO_HACK_COUNTER=$((NFS_IO_HACK_COUNTER+1))
                    touch "${NFS_IO_HACK_FILECHECK}"
                
                    [[ $? -eq 0 ]] && NFS_IO_HACK_STATUS=1
                done

                rm -rf "${NFS_IO_HACK_FILECHECK}"

                if [[ "${NFS_IO_HACK_STATUS}"  -eq 1 ]] ; then
                    logger "info" "Slept ${NFS_IO_HACK_COUNTER} seconds to work around NFS I/O error"
                else 
                    logger "info" "Slept ${NFS_IO_HACK_COUNTER} seconds but failed work around for NFS I/O error"
                fi
            fi
        fi
    done
    IFS=${ORIG_IFS}
}

storageInfo() {
    SECTION=$1

    #SOURCE DATASTORE
    SRC_DATASTORE_CAPACITY=$($VMWARE_CMD hostsvc/datastore/info "${VMFS_VOLUME}" | grep -i "capacity" | awk '{print $3}' | sed 's/,//g')
    SRC_DATASTORE_FREE=$($VMWARE_CMD hostsvc/datastore/info "${VMFS_VOLUME}" | grep -i "freespace" | awk '{print $3}' | sed 's/,//g')
    SRC_DATASTORE_BLOCKSIZE=$($VMWARE_CMD hostsvc/datastore/info "${VMFS_VOLUME}" | grep -i blockSizeMb | awk '{print $3}' | sed 's/,//g')
    if [[ -z ${SRC_DATASTORE_BLOCKSIZE} ]] ; then
        SRC_DATASTORE_BLOCKSIZE="NA"
        SRC_DATASTORE_MAX_FILE_SIZE="NA"
    else
        case ${SRC_DATASTORE_BLOCKSIZE} in
            1)SRC_DATASTORE_MAX_FILE_SIZE="256 GB";;
            2)SRC_DATASTORE_MAX_FILE_SIZE="512 GB";;
            4)SRC_DATASTORE_MAX_FILE_SIZE="1024 GB";;
            8)SRC_DATASTORE_MAX_FILE_SIZE="2048 GB";;
        esac
    fi
    SRC_DATASTORE_CAPACITY_GB=$(echo "${SRC_DATASTORE_CAPACITY}" | awk '{printf "%.1f\n",$1/1024/1024/1024}')
    SRC_DATASTORE_FREE_GB=$(echo "${SRC_DATASTORE_FREE}" | awk '{printf "%.1f\n",$1/1024/1024/1024}')

    #DESTINATION DATASTORE
    DST_VOL_1=$(echo "${VM_BACKUP_VOLUME#/*/*/}")
    DST_DATASTORE=$(echo "${DST_VOL_1%%/*}")
    DST_DATASTORE_CAPACITY=$($VMWARE_CMD hostsvc/datastore/info "${DST_DATASTORE}" | grep -i "capacity" | awk '{print $3}' | sed 's/,//g')
    DST_DATASTORE_FREE=$($VMWARE_CMD hostsvc/datastore/info "${DST_DATASTORE}" | grep -i "freespace" | awk '{print $3}' | sed 's/,//g')
    DST_DATASTORE_BLOCKSIZE=$($VMWARE_CMD hostsvc/datastore/info "${DST_DATASTORE}" | grep -i blockSizeMb | awk '{print $3}' | sed 's/,//g')

    if [[ -z ${DST_DATASTORE_BLOCKSIZE} ]] ; then
        DST_DATASTORE_BLOCKSIZE="NA"
        DST_DATASTORE_MAX_FILE_SIZE="NA"
    else
        case ${DST_DATASTORE_BLOCKSIZE} in
            1)DST_DATASTORE_MAX_FILE_SIZE="256 GB";;
            2)DST_DATASTORE_MAX_FILE_SIZE="512 GB";;
            4)DST_DATASTORE_MAX_FILE_SIZE="1024 GB";;
            8)DST_DATASTORE_MAX_FILE_SIZE="2048 GB";;
        esac
    fi

    DST_DATASTORE_CAPACITY_GB=$(echo "${DST_DATASTORE_CAPACITY}" | awk '{printf "%.1f\n",$1/1024/1024/1024}')
    DST_DATASTORE_FREE_GB=$(echo "${DST_DATASTORE_FREE}" | awk '{printf "%.1f\n",$1/1024/1024/1024}')

    logger "debug" "Storage Information ${SECTION} backup: "
    logger "debug" "SRC_DATASTORE: ${VMFS_VOLUME}"
    logger "debug" "SRC_DATASTORE_CAPACITY: ${SRC_DATASTORE_CAPACITY_GB} GB"
    logger "debug" "SRC_DATASTORE_FREE: ${SRC_DATASTORE_FREE_GB} GB"
    logger "debug" "SRC_DATASTORE_BLOCKSIZE: ${SRC_DATASTORE_BLOCKSIZE}"
    logger "debug" "SRC_DATASTORE_MAX_FILE_SIZE: ${SRC_DATASTORE_MAX_FILE_SIZE}"
    logger "debug" ""
    logger "debug" "DST_DATASTORE: ${DST_DATASTORE}"
    logger "debug" "DST_DATASTORE_CAPACITY: ${DST_DATASTORE_CAPACITY_GB} GB"
    logger "debug" "DST_DATASTORE_FREE: ${DST_DATASTORE_FREE_GB} GB"
    logger "debug" "DST_DATASTORE_BLOCKSIZE: ${DST_DATASTORE_BLOCKSIZE}"
    logger "debug" "DST_DATASTORE_MAX_FILE_SIZE: ${DST_DATASTORE_MAX_FILE_SIZE}"
    if [[ "${SRC_DATASTORE_BLOCKSIZE}" != "NA" ]] && [[ "${DST_DATASTORE_BLOCKSIZE}" != "NA" ]]; then
        if [[ "${SRC_DATASTORE_BLOCKSIZE}" -lt "${DST_DATASTORE_BLOCKSIZE}" ]]; then
            logger "debug" ""
            logger "debug" "SRC VMFS blocksze of ${SRC_DATASTORE_BLOCKSIZE}MB is less than DST VMFS blocksize of ${DST_DATASTORE_BLOCKSIZE}MB which can be an issue for VM snapshots"
        fi
    fi

logger "debug" ""
}

ghettoVCB() {
    VM_INPUT=$1
    VM_OK=0
    VM_FAILED=0
    VMDK_FAILED=0

    dumpHostInfo

    if [[ ${ENABLE_NON_PERSISTENT_NFS} -eq 1 ]] ; then
        VM_BACKUP_VOLUME="/vmfs/volumes/${NFS_LOCAL_NAME}/${NFS_VM_BACKUP_DIR}"
        if [[ "${LOG_LEVEL}" !=  "dryrun" ]] ; then
            #1 = readonly
            #0 = readwrite
            logger "debug" "Mounting NFS: ${NFS_SERVER}:${NFS_MOUNT} to /vmfs/volume/${NFS_LOCAL_NAME}"
            ${VMWARE_CMD} hostsvc/datastore/nas_create "${NFS_LOCAL_NAME}" "${NFS_SERVER}" "${NFS_MOUNT}" 0
        fi
    fi

    captureDefaultConfigurations

    if [[ "${USE_GLOBAL_CONF}" -eq 1 ]] ; then
        logger "info" "CONFIG - USING GLOBAL GHETTOVCB CONFIGURATION FILE = ${GLOBAL_CONF}"
    fi

    if [[ "${USE_VM_CONF}" -eq 0 ]] ; then
        dumpVMConfigurations
    fi

    #dump out all virtual machines allowing for spaces now
    ${VMWARE_CMD} vmsvc/getallvms | sed 's/[[:blank:]]\{3,\}/   /g' | awk -F'   ' '{print "\""$1"\";\""$2"\";\""$3"\""}' |  sed 's/\] /\]\";\"/g' | sed '1,1d' > ${WORKDIR}/vms_list

    if [[ "${BACKUP_ALL_VMS}" -eq 1 ]] ; then
        ${VMWARE_CMD} vmsvc/getallvms | sed 's/[[:blank:]]\{3,\}/   /g' | awk -F'   ' '{print ""$2""}' | sed '1,1d' | sed '/^$/d' > "${VM_INPUT}"
    fi

    ORIG_IFS=${IFS}
    IFS='
'
    for VM_NAME in $(cat "${VM_INPUT}" | grep -v "#" | sed '/^$/d' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//'); do
        IGNORE_VM=0
        if [[ "${EXCLUDE_SOME_VMS}" -eq 1 ]] ; then
            grep -E "${VM_NAME}" "${VM_EXCLUSION_FILE}" > /dev/null 2>&1
            if [[ $? -eq 0 ]] ; then
                IGNORE_VM=1
            fi
        fi
    
        VM_ID=$(grep -E "\"${VM_NAME}\"" ${WORKDIR}/vms_list | awk -F ";" '{print $1}' | sed 's/"//g')

        #ensure default value if one is not selected or variable is null
        if [[ -z ${VM_BACKUP_DIR_NAMING_CONVENTION} ]] ; then
            VM_BACKUP_DIR_NAMING_CONVENTION="$(date +%F_%k-%M-%S)"
        fi

        if [[ "${USE_VM_CONF}" -eq 1 ]] && [[ ! -z ${VM_ID} ]]; then
            reConfigureBackupParam "${VM_NAME}"
            dumpVMConfigurations
        fi

        VMFS_VOLUME=$(grep -E "\"${VM_NAME}\"" ${WORKDIR}/vms_list | awk -F ";" '{print $3}' | sed 's/\[//;s/\]//;s/"//g')
        VMX_CONF=$(grep -E "\"${VM_NAME}\"" ${WORKDIR}/vms_list | awk -F ";" '{print $4}' | sed 's/\[//;s/\]//;s/"//g')
        VMX_PATH="/vmfs/volumes/${VMFS_VOLUME}/${VMX_CONF}"
        VMX_DIR=$(dirname "${VMX_PATH}")

        #storage info
        if [[ ! -z ${VM_ID} ]] && [[ "${LOG_LEVEL}" != "dryrun" ]]; then
            storageInfo "before"
        fi

        #ignore VM as it's in the exclusion list
        if [[ "${IGNORE_VM}" -eq 1 ]] ; then 
            logger "debug" "Ignoring ${VM_NAME} for backup since its located in exclusion list\n"           
        #checks to see if we can pull out the VM_ID
        elif [[ -z ${VM_ID} ]] ; then
            logger "info" "ERROR: failed to locate and extract VM_ID for ${VM_NAME}!\n"
            VM_FAILED=1

        elif [[ "${LOG_LEVEL}" == "dryrun" ]] ; then
            logger "dryrun" "###############################################"
            logger "dryrun" "Virtual Machine: $VM_NAME"
            logger "dryrun" "VM_ID: $VM_ID"
            logger "dryrun" "VMX_PATH: $VMX_PATH"
            logger "dryrun" "VMX_DIR: $VMX_DIR"
            logger "dryrun" "VMX_CONF: $VMX_CONF"
            logger "dryrun" "VMFS_VOLUME: $VMFS_VOLUME"
            logger "dryrun" "VMDK(s): "

            TOTAL_VM_SIZE=0
            getVMDKs

            OLD_IFS="${IFS}"
            IFS=":"
            for j in ${VMDKS}; do
                J_VMDK=$(echo "${j}" | awk -F "###" '{print $1}')
                J_VMDK_SIZE=$(echo "${j}" | awk -F "###" '{print $2}')
                logger "dryrun" "\t${J_VMDK}\t${J_VMDK_SIZE} GB"
            done

            HAS_INDEPENDENT_DISKS=0
            logger "dryrun" "INDEPENDENT VMDK(s): "
            for k in ${INDEP_VMDKS}; do
                HAS_INDEPENDENT_DISKS=1
                K_VMDK=$(echo "${k}" | awk -F "###" '{print $1}')
                K_VMDK_SIZE=$(echo "${k}" | awk -F "###" '{print $2}')
                logger "dryrun" "\t${K_VMDK}\t${K_VMDK_SIZE} GB"
            done

            IFS="${OLD_IFS}"
            VMDKS=""
            INDEP_VMDKS=""

            logger "dryrun" "TOTAL_VM_SIZE_TO_BACKUP: ${TOTAL_VM_SIZE} GB"
            if [[ ${HAS_INDEPENDENT_DISKS} -eq 1 ]] ; then
                logger "dryrun" "Snapshots can not be taken for indepdenent disks!"
                logger "dryrun" "THIS VIRTUAL MACHINE WILL NOT HAVE ALL ITS VMDKS BACKED UP!"
            fi

            ls "${VMX_DIR}" | grep -q "\-delta\.vmdk" > /dev/null 2>&1;
            if [[ $? -eq 0 ]]; then
                logger "dryrun" "Snapshots found for this VM, please commit all snapshots before continuing!"
                logger "dryrun" "THIS VIRTUAL MACHINE WILL NOT BE BACKED UP DUE TO EXISTING SNAPSHOTS!"
            fi

            if [[ ${TOTAL_VM_SIZE} -eq 0 ]] ; then
                logger "dryrun" "THIS VIRTUAL MACHINE WILL NOT BE BACKED UP DUE TO EMPTY VMDK LIST!"
            fi
            logger "dryrun" "###############################################\n"

            #checks to see if the VM has any snapshots to start with
        elif ls "${VMX_DIR}" | grep -q "\-delta\.vmdk" > /dev/null 2>&1; then
            logger "info" "Snapshot found for ${VM_NAME}, backup will not take place\n"
            VM_FAILED=1

        elif [[ -f "${VMX_PATH}" ]] && [[ ! -z "${VMX_PATH}" ]]; then
            #nfs case and backup to root path of your NFS mount     
            if [[ ${ENABLE_NON_PERSISTENT_NFS} -eq 1 ]] ; then 
                BACKUP_DIR="/vmfs/volumes/${NFS_LOCAL_NAME}/${NFS_VM_BACKUP_DIR}/${VM_NAME}"
                if [[ -z ${VM_NAME} ]] || [[ -z ${NFS_LOCAL_NAME} ]] || [[ -z ${NFS_VM_BACKUP_DIR} ]]; then
                    logger "info" "ERROR: Variable BACKUP_DIR was not set properly, please ensure all required variables for non-persistent NFS backup option has been defined"
                    exit 1
                fi

                #non-nfs (SAN,LOCAL)    
            else
                BACKUP_DIR="${VM_BACKUP_VOLUME}/${VM_NAME}"
                if [[ -z ${VM_BACKUP_VOLUME} ]]; then
                    logger "info" "ERROR: Variable VM_BACKUP_VOLUME was not defined"
                    exit 1
                fi
            fi

            #initial root VM backup directory
            if [[ ! -d "${BACKUP_DIR}" ]] ; then
                mkdir -p "${BACKUP_DIR}"
                if [[ ! -d "${BACKUP_DIR}" ]] ; then
                    logger "info" "Unable to create \"${BACKUP_DIR}\"! - Ensure VM_BACKUP_VOLUME was defined correctly"
                    exit 1
                fi
            fi

            # directory name of the individual Virtual Machine backup followed by naming convention followed by count
            VM_BACKUP_DIR="${BACKUP_DIR}/${VM_NAME}-${VM_BACKUP_DIR_NAMING_CONVENTION}"

            # Rsync relative path variable if needed
            RSYNC_LINK_DIR="./${VM_NAME}-${VM_BACKUP_DIR_NAMING_CONVENTION}"

            mkdir -p "${VM_BACKUP_DIR}"

            cp "${VMX_PATH}" "${VM_BACKUP_DIR}"

            #new variable to keep track on whether VM has independent disks
            VM_HAS_INDEPENDENT_DISKS=0

            #extract all valid VMDK(s) from VM
            getVMDKs

            if [[ ! -z ${INDEP_VMDKS} ]] ; then
                VM_HAS_INDEPENDENT_DISKS=1
            fi

            ORGINAL_VM_POWER_STATE=$(${VMWARE_CMD} vmsvc/power.getstate ${VM_ID} | tail -1)
            CONTINUE_TO_BACKUP=1    

            #section that will power down a VM prior to taking a snapshot and backup and power it back on
            if [[ ${POWER_VM_DOWN_BEFORE_BACKUP} -eq 1 ]] ; then
                START_ITERATION=0
                logger "info" "Powering off initiated for ${VM_NAME}, backup will not begin until VM is off..."

                ${VMWARE_CMD} vmsvc/power.shutdown ${VM_ID} > /dev/null 2>&1
                while ${VMWARE_CMD} vmsvc/power.getstate ${VM_ID} | grep -i "Powered on" > /dev/null 2>&1; do
                    #enable hard power off code
                    if [[ ${ENABLE_HARD_POWER_OFF} -eq 1 ]] ; then
                        if [[ ${START_ITERATION} -ge ${ITER_TO_WAIT_SHUTDOWN} ]] ; then
                            logger "info" "Hard power off occured for ${VM_NAME}, waited for $((ITER_TO_WAIT_SHUTDOWN*60)) seconds" 
                            ${VMWARE_CMD} vmsvc/power.off ${VM_ID} > /dev/null 2>&1 
                            #this is needed for ESXi, even the hard power off did not take affect right away
                            sleep 60
                            break
                        fi
                    fi

                    logger "info" "VM is still on - Iteration: ${START_ITERATION} - sleeping for 60secs (Duration: $((START_ITERATION*60)) seconds)"
                    sleep 60

                    #logic to not backup this VM if unable to shutdown
                    #after certain timeout period
                    if [[ ${START_ITERATION} -ge ${POWER_DOWN_TIMEOUT} ]] ; then
                        logger "info" "Unable to power off ${VM_NAME}, waited for $((POWER_DOWN_TIMEOUT*60)) seconds! Ignoring ${VM_NAME} for backup!"
                        VM_FAILED=1
                        CONTINUE_TO_BACKUP=0
                        break
                    fi
                    START_ITERATION=$((START_ITERATION + 1))
                done
                if [[ ${CONTINUE_TO_BACKUP} -eq 1 ]] ; then
                    logger "info" "VM is powerdOff"
                fi
            fi

            if [[ ${CONTINUE_TO_BACKUP} -eq 1 ]] ; then 
                logger "info" "Initiate backup for ${VM_NAME}"
                startTimer

                SNAP_SUCCESS=1
                VM_VMDK_FAILED=0

                #powered on VMs only
                if [[ ! ${POWER_VM_DOWN_BEFORE_BACKUP} -eq 1 ]] && [[ "${ORGINAL_VM_POWER_STATE}" != "Powered off" ]]; then
                    SNAPSHOT_NAME="ghettoVCB-snapshot-$(date +%F)"
                    logger "info" "Creating Snapshot \"${SNAPSHOT_NAME}\" for ${VM_NAME}"
                    ${VMWARE_CMD} vmsvc/snapshot.create ${VM_ID} "${SNAPSHOT_NAME}" "${SNAPSHOT_NAME}" "${VM_SNAPSHOT_MEMORY}" "${VM_SNAPSHOT_QUIESCE}" > /dev/null 2>&1

                    logger "debug" "Waiting for snapshot \"${SNAPSHOT_NAME}\" to be created"
                    logger "debug" "Snapshot timeout set to: $((SNAPSHOT_TIMEOUT*60)) seconds"
                    START_ITERATION=0
                    while [[ $(${VMWARE_CMD} vmsvc/snapshot.get ${VM_ID} | wc -l) -eq 1 ]]; do
                        if [[ ${START_ITERATION} -ge ${SNAPSHOT_TIMEOUT} ]] ; then
                            logger "info" "Snapshot timed out, failed to create snapshot: \"${SNAPSHOT_NAME}\" for ${VM_NAME}"
                            SNAP_SUCCESS=0
                            echo "ERROR: Unable to backup ${VM_NAME} due to snapshot creation" >> ${VM_BACKUP_DIR}/STATUS.error
                            break
                        fi

                        logger "debug" "Waiting for snapshot creation to be completed - Iteration: ${START_ITERATION} - sleeping for 60secs (Duration: $((START_ITERATION*30)) seconds)"
                        sleep 60

                        START_ITERATION=$((START_ITERATION + 1))
                    done
                fi

                if [[ ${SNAP_SUCCESS} -eq 1 ]] ; then 
                    OLD_IFS="${IFS}"
                    IFS=":"
                    for j in ${VMDKS}; do
                        VMDK=$(echo "${j}" | awk -F "###" '{print $1}')
                        isVMDKFound=0

                        findVMDK "${VMDK}"

                        if [[ $isVMDKFound -eq 1 ]] || [[ "${VMDK_FILES_TO_BACKUP}" == "all" ]]; then 
                            #added this section to handle VMDK(s) stored in different datastore than the VM
                            echo ${VMDK} | grep "^/vmfs/volumes" > /dev/null 2>&1
                            if [[ $? -eq 0 ]] ; then
                                SOURCE_VMDK="${VMDK}"
                                DS_UUID="$(echo ${VMDK#/vmfs/volumes/*})"
                                DS_UUID="$(echo ${DS_UUID%/*/*})"
                                VMDK_DISK="$(echo ${VMDK##/*/})"
                                mkdir -p "${VM_BACKUP_DIR}/${DS_UUID}"
                                DESTINATION_VMDK="${VM_BACKUP_DIR}/${DS_UUID}/${VMDK_DISK}"
                            else
                                SOURCE_VMDK="${VMX_DIR}/${VMDK}"
                                DESTINATION_VMDK="${VM_BACKUP_DIR}/${VMDK}"
                            fi

                            #support for vRDM and deny pRDM
                            grep "vmfsPassthroughRawDeviceMap" "${SOURCE_VMDK}" > /dev/null 2>&1
                            if [[ $? -eq 1 ]] ; then
                                FORMAT_OPTION="UNKNOWN"
                                if [[ "${DISK_BACKUP_FORMAT}" == "zeroedthick" ]] ; then
                                    if [[ "${VER}" == "4" ]] || [[ "${VER}" == "5" ]] ; then
                                        FORMAT_OPTION="zeroedthick"
                                    else
                                        FORMAT_OPTION=""
                                    fi
                                elif [[ "${DISK_BACKUP_FORMAT}" == "2gbsparse" ]] ; then
                                    FORMAT_OPTION="2gbsparse"
                                elif [[ "${DISK_BACKUP_FORMAT}" == "thin" ]] ; then
                                    FORMAT_OPTION="thin"
                                elif [[ "${DISK_BACKUP_FORMAT}" == "eagerzeroedthick" ]] ; then
                                    if [[ "${VER}" == "4" ]] || [[ "${VER}" == "5" ]] ; then
                                        FORMAT_OPTION="eagerzeroedthick"
                                    else
                                        FORMAT_OPTION=""
                                    fi
                                fi

                                if  [[ "${FORMAT_OPTION}" == "UNKNOWN" ]] ; then
                                    logger "info" "ERROR: wrong DISK_BACKUP_FORMAT \"${DISK_BACKUP_FORMAT}\ specified for ${VM_NAME}"
                                    VM_VMDK_FAILED=1
                                else
                                    VMDK_OUTPUT=$(mktemp ${WORKDIR}/ghettovcb.XXXXXX)
                                    tail -f "${VMDK_OUTPUT}" &
                                    TAIL_PID=$!

                                    ADAPTER_FORMAT=$(grep -i "ddb.adapterType" "${SOURCE_VMDK}" | awk -F "=" '{print $2}' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//;s/"//g')

                                    if  [[ -z "${FORMAT_OPTION}" ]] ; then
                                        logger "debug" "${VMKFSTOOLS_CMD} -i \"${SOURCE_VMDK}\" -a \"${ADAPTER_FORMAT}\" \"${DESTINATION_VMDK}\""
                                        ${VMKFSTOOLS_CMD} -i "${SOURCE_VMDK}" -a "${ADAPTER_FORMAT}" "${DESTINATION_VMDK}" > "${VMDK_OUTPUT}" 2>&1                  
                                    else 
                                        logger "debug" "${VMKFSTOOLS_CMD} -i \"${SOURCE_VMDK}\" -a \"${ADAPTER_FORMAT}\" -d \"${FORMAT_OPTION}\" \"${DESTINATION_VMDK}\""
                                        ${VMKFSTOOLS_CMD} -i "${SOURCE_VMDK}" -a "${ADAPTER_FORMAT}" -d "${FORMAT_OPTION}" "${DESTINATION_VMDK}" > "${VMDK_OUTPUT}" 2>&1
                                    fi

                                    VMDK_EXIT_CODE=$?
                                    kill "${TAIL_PID}"
                                    cat "${VMDK_OUTPUT}" >> "${REDIRECT}"
                                    echo >> "${REDIRECT}"
                                    echo
                                    rm "${VMDK_OUTPUT}"

                                    if [[ "${VMDK_EXIT_CODE}" != 0 ]] ; then
                                        logger "info" "ERROR: error in backing up of \"${SOURCE_VMDK}\" for ${VM_NAME}"
                                        VM_VMDK_FAILED=1
                                    fi
                                fi
                            else
                                logger "info" "WARNING: A physical RDM \"${SOURCE_VMDK}\" was found for ${VM_NAME}, which will not be backed up"
                                VM_VMDK_FAILED=1
                            fi
                        fi
                    done
                    IFS="${OLD_IFS}"
                fi

                #powered on VMs only w/snapshots
                if [[ ${SNAP_SUCCESS} -eq 1 ]] && [[ ! ${POWER_VM_DOWN_BEFORE_BACKUP} -eq 1 ]] && [[ "${ORGINAL_VM_POWER_STATE}" == "Powered on" ]] || [[ "${ORGINAL_VM_POWER_STATE}" == "Suspended" ]]; then
                    if [[ "${NEW_VIMCMD_SNAPSHOT}" == "yes" ]] ; then
                        SNAPSHOT_ID=$(${VMWARE_CMD} vmsvc/snapshot.get ${VM_ID} | grep -E '(Snapshot Name|Snapshot Id)' | grep -A1 ${SNAPSHOT_NAME} | grep "Snapshot Id" | awk -F ":" '{print $2}' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
                        ${VMWARE_CMD} vmsvc/snapshot.remove ${VM_ID} ${SNAPSHOT_ID} > /dev/null 2>&1
                    else
                        ${VMWARE_CMD} vmsvc/snapshot.remove ${VM_ID} > /dev/null 2>&1
                    fi

                    #do not continue until all snapshots have been committed
                    logger "info" "Removing snapshot from ${VM_NAME} ..."
                    while ls "${VMX_DIR}" | grep -q "\-delta\.vmdk"; do
                        sleep 5
                    done
                fi

                if [[ ${POWER_VM_DOWN_BEFORE_BACKUP} -eq 1 ]] && [[ "${ORGINAL_VM_POWER_STATE}" == "Powered on" ]]; then
                    #power on vm that was powered off prior to backup
                    logger "info" "Powering back on ${VM_NAME}"
                    ${VMWARE_CMD} vmsvc/power.on ${VM_ID} > /dev/null 2>&1
                fi

                TMP_IFS=${IFS}
                IFS=${ORIG_IFS}
                if [[ ${ENABLE_COMPRESSION} -eq 1 ]] ; then
                    COMPRESSED_ARCHIVE_FILE="${BACKUP_DIR}/${VM_NAME}-${VM_BACKUP_DIR_NAMING_CONVENTION}.gz"

                    logger "info" "Compressing VM backup \"${COMPRESSED_ARCHIVE_FILE}\"..."
                    if [[ ${IS_4I} -eq 1 ]] ; then
                        busybox tar -cz -C "${BACKUP_DIR}" "${VM_NAME}-${VM_BACKUP_DIR_NAMING_CONVENTION}" -f "${COMPRESSED_ARCHIVE_FILE}"
                    else 
                        tar -cz -C "${BACKUP_DIR}" "${VM_NAME}-${VM_BACKUP_DIR_NAMING_CONVENTION}" -f "${COMPRESSED_ARCHIVE_FILE}"
                    fi

                    # verify compression
                    if [[ $? -eq 0 ]] && [[ -f "${COMPRESSED_ARCHIVE_FILE}" ]]; then
                        logger "info" "Successfully compressed backup for ${VM_NAME}!\n"
                        COMPRESSED_OK=1
                    else
                        logger "info" "Error in compressing ${VM_NAME}!\n"
                        COMPRESSED_OK=0
                    fi
                    rm -rf "${VM_BACKUP_DIR}"
                    checkVMBackupRotation "${BACKUP_DIR}" "${VM_NAME}"
                else
                    checkVMBackupRotation "${BACKUP_DIR}" "${VM_NAME}"
                fi
                IFS=${TMP_IFS}
                VMDKS=""
                INDEP_VMDKS=""

                endTimer
                if [[ ${SNAP_SUCCESS} -ne 1 ]] ; then
                    logger "info" "ERROR: Unable to backup ${VM_NAME} due to snapshot creation!\n"
                    [[ ${ENABLE_COMPRESSION} -eq 1 ]] && [[ $COMPRESSED_OK -eq 1 ]] || echo "ERROR: Unable to backup ${VM_NAME} due to snapshot creation" >> ${VM_BACKUP_DIR}/STATUS.error
                    VM_FAILED=1
                elif [[ ${VM_VMDK_FAILED} -ne 0 ]] ; then
                    logger "info" "ERROR: Unable to backup ${VM_NAME} due to error in VMDK backup!\n"
                    [[ ${ENABLE_COMPRESSION} -eq 1 ]] && [[ $COMPRESSED_OK -eq 1 ]] || echo "ERROR: Unable to backup ${VM_NAME} due to error in VMDK backup" >> ${VM_BACKUP_DIR}/STATUS.error
                    VMDK_FAILED=1
                elif [[ ${VM_HAS_INDEPENDENT_DISKS} -eq 1 ]] ; then
                    logger "info" "WARN: ${VM_NAME} has some Independent VMDKs that can not be backed up!\n";
                    [[ ${ENABLE_COMPRESSION} -eq 1 ]] && [[ $COMPRESSED_OK -eq 1 ]] || echo "WARN: ${VM_NAME} has some Independent VMDKs that can not be backed up" > ${VM_BACKUP_DIR}/STATUS.warn
                    VMDK_FAILED=1
                    #experimental
                    #create symlink for the very last backup to support rsync functionality for additinal replication
                    if [[ "${RSYNC_LINK}" -eq 1 ]] ; then
                        SYMLINK_DST=${VM_BACKUP_DIR}
                        if [[ ${ENABLE_COMPRESSION} -eq 1 ]]; then
                            SYMLINK_DST1="${RSYNC_LINK_DIR}.gz"
                        else
                            SYMLINK_DST1=${RSYNC_LINK_DIR}
                        fi
                        SYMLINK_SRC="$(echo "${SYMLINK_DST%*-*-*-*_*-*-*}")-symlink"
                        logger "info" "Creating symlink \"${SYMLINK_SRC}\" to \"${SYMLINK_DST1}\""
                        ln -sf "${SYMLINK_DST1}" "${SYMLINK_SRC}"
                    fi

                    #storage info after backup
                    storageInfo "after"
                else
                    logger "info" "Successfully completed backup for ${VM_NAME}!\n"
                    [[ ${ENABLE_COMPRESSION} -eq 1 ]] && [[ $COMPRESSED_OK -eq 1 ]] || echo "Successfully completed backup" > ${VM_BACKUP_DIR}/STATUS.ok
                    VM_OK=1

                    #experimental
                    #create symlink for the very last backup to support rsync functionality for additinal replication
                    if [[ "${RSYNC_LINK}" -eq 1 ]] ; then
                        SYMLINK_DST=${VM_BACKUP_DIR}
                        if [[ ${ENABLE_COMPRESSION} -eq 1 ]] ; then
                            SYMLINK_DST1="${RSYNC_LINK_DIR}.gz"
                        else
                            SYMLINK_DST1=${RSYNC_LINK_DIR}
                        fi
                        SYMLINK_SRC="$(echo "${SYMLINK_DST%*-*-*-*_*-*-*}")-symlink"
                        logger "info" "Creating symlink \"${SYMLINK_SRC}\" to \"${SYMLINK_DST1}\""
                        ln -sf "${SYMLINK_DST1}" "${SYMLINK_SRC}"
                    fi

                    #storage info after backup
                    storageInfo "after"
                fi
            else
                if [[ ${CONTINUE_TO_BACKUP} -eq 0 ]] ; then
                    logger "info" "ERROR: Failed to backup ${VM_NAME}!\n"
                    VM_FAILED=1
                else
                    logger "info" "ERROR: Failed to lookup ${VM_NAME}!\n"
                    VM_FAILED=1
                fi
            fi  
        fi
    done
    unset IFS

    if [[ ${ENABLE_NON_PERSISTENT_NFS} -eq 1 ]] && [[ ${UNMOUNT_NFS} -eq 1 ]] && [[ "${LOG_LEVEL}" != "dryrun" ]]; then
        logger "debug" "Sleeping for 30seconds before unmounting NFS volume"
        sleep 30
        ${VMWARE_CMD} hostsvc/datastore/destroy ${NFS_LOCAL_NAME}   
    fi
}

getFinalStatus() {
    if [[ "${LOG_TYPE}" == "dryrun" ]]; then
        FINAL_STATUS="###### Final status: OK, only a dryrun. ######"
        LOG_STATUS="OK"
        EXIT=0
    elif [[ $VM_OK == 1 ]] && [[ $VM_FAILED == 0 ]] && [[ $VMDK_FAILED == 0 ]]; then
        FINAL_STATUS="###### Final status: All VMs backed up OK! ######"
        LOG_STATUS="OK"
        EXIT=0
    elif [[ $VM_OK == 1 ]] && [[ $VM_FAILED == 0 ]] && [[ $VMDK_FAILED == 1 ]]; then
        FINAL_STATUS="###### Final status: WARNING: All VMs backed up, but some disk(s) failed! ######"
        LOG_STATUS="WARNING"
        EXIT=3
    elif [[ $VM_OK == 1 ]] && [[ $VM_FAILED == 1 ]] && [[ $VMDK_FAILED == 0 ]]; then
        FINAL_STATUS="###### Final status: ERROR: Only some of the VMs backed up! ######"
        LOG_STATUS="ERROR"
        EXIT=4
    elif [[ $VM_OK == 1 ]] && [[ $VM_FAILED == 1 ]] && [[ $VMDK_FAILED == 1 ]]; then
        FINAL_STATUS="###### Final status: ERROR: Only some of the VMs backed up, and some disk(s) failed! ######"
        LOG_STATUS="ERROR"
        EXIT=5
    elif [[ $VM_OK == 0 ]] && [[ $VM_FAILED == 1 ]]; then
        FINAL_STATUS="###### Final status: ERROR: All VMs failed! ######"
        LOG_STATUS="ERROR"
        EXIT=6
    elif [[ $VM_OK == 0 ]]; then
        FINAL_STATUS="###### Final status: ERROR: No VMs backed up! ######"
        LOG_STATUS="ERROR"
        EXIT=7
    fi
    logger "info" "$FINAL_STATUS\n"
}

buildHeaders() {
    EMAIL_ADDRESS=$1    

    echo -ne "HELO $(hostname -s)\r\n" > "${EMAIL_LOG_HEADER}"
    echo -ne "MAIL FROM: <${EMAIL_FROM}>\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "RCPT TO: <${EMAIL_ADDRESS}>\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "DATA\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "From: ${EMAIL_FROM}\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "To: ${EMAIL_ADDRESS}\r\n" >> "${EMAIL_LOG_HEADER}"
    echo -ne "Subject: ghettoVCB - ${FINAL_STATUS}\r\n" >> "${EMAIL_LOG_HEADER}"

    echo -en ".\r\n" >> "${EMAIL_LOG_OUTPUT}"
    echo -en "QUIT\r\n" >> "${EMAIL_LOG_OUTPUT}"

    cat "${EMAIL_LOG_HEADER}" > "${EMAIL_LOG_CONTENT}"
    cat "${EMAIL_LOG_OUTPUT}" >> "${EMAIL_LOG_CONTENT}"
}

sendMail() {
    #close email message
    if [[ "${EMAIL_LOG}" -eq 1 ]] ; then
        #validate firewall has email port open for ESXi 5
        if [[ "${VER}" == "5" ]] ; then
            /sbin/esxcli network firewall ruleset rule list | grep "${EMAIL_SERVER_PORT}" > /dev/null 2>&1
            if [[ $? -eq 1 ]] ; then
                logger "info" "ERROR: Please enable firewall rule for email traffic on port ${EMAIL_SERVER_PORT}\n"
                logger "info" "Please refer to ghettoVCB documentation for ESXi 5 firewall configuration\n"
            fi
        fi

        echo "${EMAIL_TO}" | grep "," > /dev/null 2>&1
        if [[ $? -eq 0 ]] ; then
            ORIG_IFS=${IFS}
            IFS=','
            for i in ${EMAIL_TO}; do
                buildHeaders ${i}   
                "${NC_BIN}" -i "${EMAIL_DELAY_INTERVAL}" "${EMAIL_SERVER}" "${EMAIL_SERVER_PORT}" < "${EMAIL_LOG_CONTENT}" > /dev/null 2>&1
                if [[ $? -eq 1 ]] ; then
                    logger "info" "ERROR: Failed to email log output to ${EMAIL_SERVER}:${EMAIL_SERVER_PORT} to ${EMAIL_TO}\n"
                fi
            done
            unset IFS
        else
            buildHeaders ${EMAIL_TO}
            "${NC_BIN}" -i "${EMAIL_DELAY_INTERVAL}" "${EMAIL_SERVER}" "${EMAIL_SERVER_PORT}" < "${EMAIL_LOG_CONTENT}" > /dev/null 2>&1
            if [[ $? -eq 1 ]] ; then
                logger "info" "ERROR: Failed to email log output to ${EMAIL_SERVER}:${EMAIL_SERVER_PORT} to ${EMAIL_TO}\n"
            fi
        fi
    fi
}

####################
#                  #
# Start of Script  #
#                  #
####################

IS_4I=0

[[ ! -f /bin/bash ]] && IS_4I=1

USE_VM_CONF=0
USE_GLOBAL_CONF=0
BACKUP_ALL_VMS=0
EXCLUDE_SOME_VMS=0

#read user input
while getopts ":af:c:g:w:m:l:d:e:" ARGS; do
    case $ARGS in
        w)
            WORKDIR="${OPTARG}"
            ;;
        a)
            BACKUP_ALL_VMS=1
            VM_FILE='${WORKDIR}/vm-input-list'
            ;;          
        f)  
            VM_FILE="${OPTARG}"
            ;;
        m)  
            VM_FILE='${WORKDIR}/vm-input-list'
            VM_ARG="${OPTARG}"
            ;;
        e)
            VM_EXCLUSION_FILE="${OPTARG}"
            EXCLUDE_SOME_VMS=1
            ;;
        c)
            CONFIG_DIR="${OPTARG}"
            USE_VM_CONF=1
            ;;
        g)
            GLOBAL_CONF="${OPTARG}"
            USE_GLOBAL_CONF=1
            ;;
        l)
            LOG_OUTPUT="${OPTARG}"
            ;;
        d)
            LOG_LEVEL="${OPTARG}"
            ;;
        :)
            echo "Option -${OPTARG} requires an argument."
            exit 1
            ;;
        *)
            printUsage
            exit 1
            ;;
    esac
done

WORKDIR=${WORKDIR:-"/tmp/ghettoVCB.work"}

EMAIL_LOG_HEADER=${WORKDIR}/ghettoVCB-email-$$.header
EMAIL_LOG_OUTPUT=${WORKDIR}/ghettoVCB-email-$$.log
EMAIL_LOG_CONTENT=${WORKDIR}/ghettoVCB-email-$$.content

#expand VM_FILE 
[[ -n "${VM_FILE}" ]] && VM_FILE=$(eval "echo $VM_FILE")


if mkdir "${WORKDIR}"; then

    # create VM_FILE if we're backing up everything/specified a vm on the command line
    [[ $BACKUP_ALL_VMS -eq 1 ]] && touch ${VM_FILE}
    [[ -n "${VM_ARG}" ]] && echo "${VM_ARG}" > "${VM_FILE}"

    # performs a check on the number of commandline arguments + verifies $2 is a valid file
    sanityCheck $# 

    GHETTOVCB_PID=$$
    echo $GHETTOVCB_PID > "${WORKDIR}/pid"

    logger "info" "============================== ghettoVCB LOG START ==============================\n"
    logger "debug" "Succesfully acquired lock directory - ${WORKDIR}\n"

    # remove lockdir when the script finishes, or when it receives a signal
    if [[ "${WORKDIR_DEBUG}" -eq 1 ]] ; then
        logger "info" "Workdir: ${WORKDIR} will not! be removed on exit"
    else
        trap 'rm -rf "${WORKDIR}"' 0    # remove workdir when script finishes
    fi

    trap "exit 2" 1 2 3 13 15       # terminate script when receiving signal

    ghettoVCB ${VM_FILE}

    getFinalStatus

    logger "debug" "Succesfully removed lock directory - ${WORKDIR}\n"
    logger "info" "============================== ghettoVCB LOG END ================================\n"

    sendMail

    # practically redundant
    [[ "${WORKDIR_DEBUG}" -eq 0 ]] && rm -rf "${WORKDIR}"
    exit $EXIT
else 
    logger "info" "Failed to acquire lock, another instance of script may be running, giving up on ${WORKDIR}\n"
    exit 1
fi

# Author: William Lam 
# 08/18/2009
# http://www.engineering.ucsb.edu/~duonglt/vmware/
##################################################################

###### DO NOT EDIT PASS THIS LINE ######

LAST_MODIFIED="09/15/2010"

printUsage() {
	echo "###############################################################################"
	echo "#"
	echo "# ghettoVCB-restore for ESX/ESXi 3.5u2+ & 4.x+"
	echo "# Author: William Lam"
	echo "# http://www.engineering.ucsb.edu/~duonglt/vmware/"
	echo "# Created: 08/18/2009"
	echo "# Last modified: ${LAST_MODIFIED}"
	echo "#"
	echo "###############################################################################"
	echo
	echo "Usage: $0 -c [VM_BACKUP_UP_LIST] -l [LOG_FILE]"
	echo
	echo "OPTIONS:"
        echo "   -c     VM backup list"
        echo "   -l     File ot output logging"
        echo
        echo "(e.g.)"
	echo -e "\nOutput will go to stdout"
        echo -e "\t$0 -c vms_to_restore "
	echo -e "\nOutput will log to /tmp/ghettoVCB-restore.log"
        echo -e "\t$0 -c vms_to_restore -l /tmp/ghettoVCB-restore.log"
	echo
	exit 1
}

logger() {
	MSG=$1
	if [ "${LOG_TO_STDOUT}" -eq 1 ]; then
		echo -e "${MSG}"
	else
		echo -e "${MSG}" >> "${LOG_OUTPUT}"
	fi
}

sanityCheck() {
	NUM_OF_ARGS=$1

	if [[ ${NUM_OF_ARGS} -ne 2 ]] && [[ ${NUM_OF_ARGS} -ne 4 ]] && [[ ${NUM_OF_ARGS} -ne 6 ]]; then
                printUsage
        fi

	#log to stdout or to logfile
        if [ -z "${LOG_OUTPUT}" ]; then
                LOG_TO_STDOUT=1
		REDIRECT=/dev/null
        else
                LOG_TO_STDOUT=0
		REDIRECT=${LOG_OUTPUT}
                echo "Logging output to \"${LOG_OUTPUT}\" ..."
                touch "${LOG_OUTPUT}"
        fi

	if [[ "${DEVEL_MODE}" == "1" ]] && [[ "${DEVEL_MODE}" == "2" ]] && [[ "${DEVEL_MODE}" == "0" ]]; then
		DEVEL_MODE=0
	fi

        if [ -f /usr/bin/vmware-vim-cmd ]; then
                VMWARE_CMD=/usr/bin/vmware-vim-cmd
                VMKFSTOOLS_CMD=/usr/sbin/vmkfstools
        elif [ -f /bin/vim-cmd ]; then
                VMWARE_CMD=/bin/vim-cmd
                VMKFSTOOLS_CMD=/sbin/vmkfstools
        else
		logger "ERROR: Unable to locate *vimsh*! You're not running ESX(i) 3.5+ or 4.x+!"
		echo "ERROR: Unable to locate *vimsh*! You're not running ESX(i) 3.5+ or 4.x+!"
                exit
        fi

        ESX_VERSION=$(vmware -v | awk '{print $3}')
	if [[ "${ESX_VERSION}" == "4.0.0" ]] || [[ "${ESX_VERSION}" == "4.1.0" ]]; then
                VER=4
        else
                ESX_VERSION=$(vmware -v | awk '{print $4}')
                if [[ "${ESX_VERSION}" == "3.5.0" ]] || [[ "${ESX_VERSION}" == "3i" ]]; then
                        VER=3
                else
			logger "ERROR: You're not running ESX(i) 3.5+ or 4.x+!"
                        exit
                fi
        fi

        if [ ! "`whoami`" == "root" ]; then
		logger "ERROR: This script needs to be executed by \"root\"!"
		echo "ERROR: This script needs to be executed by \"root\"!"
                exit 1
        fi

	#ensure input file exists
	if [ ! -f "${CONFIG_FILE}" ]; then
		logger "ERROR: \"${CONFIG_FILE}\" input file does not exists\n"
		echo -e "ERROR: \"${CONFIG_FILE}\" input file does not exists\n"
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
	logger "\nStart time: ${START_TIME}"
	logger "End   time: ${END_TIME}"
        DURATION=$(echo $((E_TIME - S_TIME)))

        #calculate overall completion time
        if [ ${DURATION} -le 60 ]; then
		logger "Duration  : ${DURATION} Seconds"
        else
		logger "Duration  : $(awk 'BEGIN{ printf "%.2f\n", '${DURATION}'/60}') Minutes\n"
        fi
        logger "\n---------------------------------------------------------------------------------------------------------------\n"
	echo
}

ghettoVCBrestore() {
	VM_FILE=$1
	
	startTimer

	ORIG_IFS=${IFS}
        IFS='
'
	for LINE in $(cat "${VM_FILE}" | sed '/^$/d' | sed -e '/^#/d' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//');
	do	
		VM_TO_RESTORE=$(echo "${LINE}" | awk -F ';' '{print $1}' | sed 's/"//g' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
		DATASTORE_TO_RESTORE_TO=$(echo "${LINE}" | awk -F ';' '{print $2}' | sed 's/"//g' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
		RESTORE_DISK_FORMAT=$(echo "${LINE}" | awk -F ';' '{print $3}' | sed 's/"//g' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//')

		#figure the disk format to use
		if [ "${RESTORE_DISK_FORMAT}" -eq 1 ]; then
			FORMAT_STRING=zeroedthick
		elif [ "${RESTORE_DISK_FORMAT}" -eq 2 ]; then
                        FORMAT_STRING=2gbsparse
		elif [ "${RESTORE_DISK_FORMAT}" -eq 3 ]; then
                        FORMAT_STRING=thin
		elif [ "${RESTORE_DISK_FORMAT}" -eq 4 ]; then
                        FORMAT_STRING=eagerzeroedthick
		fi

		IS_DIR=0		
		#supports DIR or .TGZ from ghettoVCB.sh ONLY!
		if [ -d "${VM_TO_RESTORE}" ]; then
			#figure out the contents of the directory (*.vmdk,*-flat.vmdk,*.vmx)
			VM_VMX=$(ls "${VM_TO_RESTORE}" | grep ".vmx")
			VM_VMDK_DESCRS=$(ls "${VM_TO_RESTORE}" | grep ".vmdk" | grep -v "\-flat.vmdk")
			VMDKS_FOUND=$(grep -iE '(scsi|ide)' "${VM_TO_RESTORE}/${VM_VMX}" | grep -i fileName | awk -F " " '{print $1}')
			VM_DISPLAY_NAME=$(grep -i "displayName" "${VM_TO_RESTORE}/${VM_VMX}" | awk -F '=' '{print $2}' | sed 's/"//g' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
			VM_ORIG_FOLDER_NAME=$(echo "${VM_TO_RESTORE##*/}")
			VM_FOLDER_NAME=$(echo "${VM_ORIG_FOLDER_NAME}" | sed 's/-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]--[0-1]*//g')
			
			#figure out the VMDK rename, esepcially important if original backup had VMDKs spread across multiple datastores
			#restoration will not support that since I can't assume the original system will be availabl with same ds/etc.
			#files will be restored to single VMFS volume without disrupting original backup

			NUM_OF_VMDKS=0
			TMP_IFS=${IFS}
                        IFS=${ORIG_IFS}
			for VMDK in ${VMDKS_FOUND};
			do
				#extract the SCSI ID and use it to check for valid vmdk disk
				SCSI_ID=$(echo ${VMDK%%.*})
				grep -i "${SCSI_ID}.present" "${VM_TO_RESTORE}/${VM_VMX}" | grep -i "true" > /dev/null 2>&1
				#if valid, then we use the vmdk file
                                if [ $? -eq 0 ]; then
                                        grep -i "${SCSI_ID}.deviceType" "${VM_TO_RESTORE}/${VM_VMX}" | grep -i "scsi-hardDisk" > /dev/null 2>&1
					#if we find the device type is of scsi-disk, then proceed
                                        if [ $? -eq 0 ]; then
						DISK=$(grep -i ${SCSI_ID}.fileName "${VM_TO_RESTORE}/${VM_VMX}")
					else
                                                #if the deviceType is NULL for IDE which it is, thanks for the inconsistency VMware
                                                #we'll do one more level of verification by checking to see if an ext. of .vmdk exists
                                                #since we can not rely on the deviceType showing "ide-hardDisk"
                                                grep -i ${SCSI_ID}.fileName "${VM_TO_RESTORE}/${VM_VMX}" | grep -i ".vmdk" > /dev/null 2>&1
						if [ $? -eq 0 ]; then
							DISK=$(grep -i ${SCSI_ID}.fileName "${VM_TO_RESTORE}/${VM_VMX}")
						fi
					fi

					
					if [ "${DISK}" != "" ]; then 
						SCSI_CONTROLLER=$(echo ${DISK} | awk -F '=' '{print $1}')
                                        	RENAME_DESTINATION_LINE_VMDK_DISK="${SCSI_CONTROLLER} = \"${VM_DISPLAY_NAME}-${NUM_OF_VMDKS}.vmdk\""
                                        	if [ -z "${VMDK_LIST_TO_MODIFY}" ]; then
                                                	VMDK_LIST_TO_MODIFY="${DISK},${RENAME_DESTINATION_LINE_VMDK_DISK}"
                                        	else
                                                	VMDK_LIST_TO_MODIFY="${VMDK_LIST_TO_MODIFY};${DISK},${RENAME_DESTINATION_LINE_VMDK_DISK}"
                                        	fi
						DISK=''
					fi
				fi
				NUM_OF_VMDKS=$((NUM_OF_VMDKS+1))
			done	
			IFS=${TMP_IFS}
		else 
			logger "Support for .tgz not supported - \"${VM_TO_RESTORE}\" will not be backed up!"
			IS_TGZ=1
		fi

if [ ! "${IS_TGZ}" == "1" ]; then
		if [ "${DEVEL_MODE}" == "1" ]; then
			logger "\n################ DEBUG MODE ##############"
			logger "Virtual Machine: \"${VM_DISPLAY_NAME}\""
			logger "VM_VMX: \"${VM_VMX}\""
			logger "VM_ORG_FOLDER: \"${VM_ORIG_FOLDER_NAME}\""
			logger "VM_FOLDER_NAME: \"${VM_FOLDER_NAME}\""
			logger "VMDK_LIST_TO_MODIFY:"
			OLD_IFS="${IFS}"
                        IFS=";"
			for i in ${VMDK_LIST_TO_MODIFY}
			do
				VMDK_1=$(echo $i | awk -F ',' '{print $1}')
        			VMDK_2=$(echo $i | awk -F ',' '{print $2}')
        			logger "${VMDK_1}"
        			logger "${VMDK_2}"
			done
			unset IFS
			IFS="${OLD_IFS}"
                        logger "##########################################\n"
		else
			#validates the datastore to restore is valid and available
			if [ ! -d "${DATASTORE_TO_RESTORE_TO}" ]; then
				logger "ERROR: Unable to verify datastore locateion: \"${DATASTORE_TO_RESTORE_TO}\"! Ensure this exists"
			#validates that all 4 required variables are defined before continuing 
			elif [[ -z "${VM_VMX}" ]] && [[ -z "${VM_VMDK_DESCRS}" ]] && [[ -z "${VM_DISPLAY_NAME}" ]] && [[ -z "${VM_FOLDER_NAME}" ]]; then			     	     logger "ERROR: Unable to define all required variables: VM_VMX, VM_VMDK_DESCR and VM_DISPLAY_NAME!"	
			#validates that a directory with the same VM does not already exists
			elif [ -d "${DATASTORE_TO_RESTORE_TO}/${VM_FOLDER_NAME}" ]; then
				logger "ERROR: Directory \"${DATASTORE_TO_RESTORE_TO}/${VM_FOLDER_NAME}\" looks like it already exists, please check contents and remove directory before trying to restore!" 
			else		
				logger "################## Restoring VM: $VM_DISPLAY_NAME  #####################"
				if [ "${DEVEL_MODE}" == "2" ]; then
					logger "==========> DEBUG MODE LEVEL 2 ENABLED <=========="
				fi
                	        logger "Start time: $(date)"
                        	logger "Restoring VM from: \"${VM_TO_RESTORE}\""
	                        logger "Restoring VM to Datastore: \"${DATASTORE_TO_RESTORE_TO}\" using Disk Format: \"${FORMAT_STRING}\""
	
				VM_RESTORE_DIR="${DATASTORE_TO_RESTORE_TO}/${VM_FOLDER_NAME}"

				#create VM folder on datastore if it doesn't already exists
				logger "Creating VM directory: \"${VM_RESTORE_DIR}\" ..."
				if [ ! "${DEVEL_MODE}" == "2" ]; then	
					mkdir -p "${VM_RESTORE_DIR}"
				fi

				#copy .vmx file
				logger "Copying \"${VM_VMX}\" file ..."
				if [ ! "${DEVEL_MODE}" == "2" ]; then
					cp "${VM_TO_RESTORE}/${VM_VMX}" "${VM_RESTORE_DIR}/${VM_VMX}"
				fi

				#loop through all VMDK(s) and vmkfstools copy to destination
				logger "Restoring VM's VMDK(s) ..."
				#MAX=${#ORIGINAL_VMX_VMDK_LINES[*]}
				OLD_IFS="${IFS}"
                        	IFS=";"
				for i in ${VMDK_LIST_TO_MODIFY}
				do
					#retrieve individual VMDKs
					SOURCE_LINE_VMDK=$(echo "${i}" | awk -F ',' '{print $1}' | awk -F '=' '{print $2}' | sed 's/"//g' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
					DESTINATION_LINE_VMDK=$(echo "${i}" | awk -F ',' '{print $2}' | awk -F '=' '{print $2}' | sed 's/"//g' | sed -e 's/^[[:blank:]]*//;s/[[:blank:]]*$//')
					#retrieve individual VMDK lines in .vmx file to update
					ORIGINAL_VMX_LINE=$(echo "${i}" | awk -F ',' '{print $1}')
                                        MODIFIED_VMX_LINE=$(echo "${i}" | awk -F ',' '{print $2}')
					
					#update restored VM to match VMDKs
					logger "Updating VMDK entry in \"${VM_VMX}\" file ..."
					if [ ! "${DEVEL_MODE}" == "2" ]; then
						sed -i "s#${ORIGINAL_VMX_LINE}#${MODIFIED_VMX_LINE}#g" "${VM_RESTORE_DIR}/${VM_VMX}"
					fi

					echo "${SOURCE_LINE_VMDK}" | grep "/vmfs/volumes" > /dev/null 2>&1
					if [ $? -eq 0 ]; then
						#SOURCE_VMDK="${SOURCE_LINE_VMDK}"
						DS_VMDK_PATH=$(echo "${SOURCE_LINE_VMDK}" | sed 's/\/vmfs\/volumes\///g')
						VMDK_DATASTORE=$(echo "${DS_VMDK_PATH%%/*}")
						VMDK_VM=$(echo "${DS_VMDK_PATH##*/}")
						SOURCE_VMDK="${VM_TO_RESTORE}/${VMDK_DATASTORE}/${VMDK_VM}"
					else
						SOURCE_VMDK="${VM_TO_RESTORE}/${SOURCE_LINE_VMDK}"
					fi
					DESTINATION_VMDK="${VM_RESTORE_DIR}/${DESTINATION_LINE_VMDK}"

					if [ ! "${DEVEL_MODE}" == "2" ]; then
						if [ ${RESTORE_DISK_FORMAT} -eq 1 ]; then
	                                		if [ "${VER}" == "4" ]; then
        	                                		${VMKFSTOOLS_CMD} -i "${SOURCE_VMDK}" -d zeroedthick "${DESTINATION_VMDK}" 2>&1 | tee "${REDIRECT}"
		                                        else
        		        	                        ${VMKFSTOOLS_CMD} -i "${SOURCE_VMDK}" "${DESTINATION_VMDK}" 2>&1 | tee "${REDIRECT}"
                		                        fi
		                                elif [ ${RESTORE_DISK_FORMAT} -eq 2 ]; then
        		                                ${VMKFSTOOLS_CMD} -i "${SOURCE_VMDK}" -d 2gbsparse "${DESTINATION_VMDK}" 2>&1 | tee "${REDIRECT}"
                		                elif [ ${RESTORE_DISK_FORMAT} -eq 3 ]; then
                        		                ${VMKFSTOOLS_CMD} -i "${SOURCE_VMDK}" -d thin "${DESTINATION_VMDK}" 2>&1 | tee "${REDIRECT}"
	                                	elif [ ${RESTORE_DISK_FORMAT} -eq 4 ]; then
        	                                	if [ "${VER}" == "4" ]; then
                	        	                	${VMKFSTOOLS_CMD} -i "${SOURCE_VMDK}" -d eagerzeroedthick "${DESTINATION_VMDK}" 2>&1 | tee "${REDIRECT}"
	                	                        else
        	                	                        ${VMKFSTOOLS_CMD} -i "${SOURCE_VMDK}" "${DESTINATION_VMDK}" 2>&1 | tee "${REDIRECT}"
	                	                        fi
        	                	        fi
					else
						logger "\nSOURCE: \"${SOURCE_VMDK}\""
						logger "\tORIGINAL_VMX_LINE: -->${ORIGINAL_VMX_LINE}<--"
						logger "DESTINATION: \"${DESTINATION_VMDK}\""
						logger "\tMODIFIED_VMX_LINE: -->${MODIFIED_VMX_LINE}<--"
					fi
				done
				unset IFS
				IFS="${OLD_IFS}"				

				#register VM on ESX(i) host
				logger "Registering $VM_DISPLAY_NAME ..."

				if [ ! "${DEVEL_MODE}" == "2" ]; then
					${VMWARE_CMD} solo/registervm "${VM_RESTORE_DIR}/${VM_VMX}"
				fi

				logger "End time: $(date)"
				logger "################## Completed restore for $VM_DISPLAY_NAME! #####################\n"
			fi
		fi
fi
		VMDK_LIST_TO_MODIFY=''
	done
	unset IFS	

	endTimer
}

####################
#                  #
# Start of Script  #
#                  #
####################

IS_4I=0

if [ ! -f /bin/bash ]; then
        IS_4I=1
fi

#read user input
while getopts ":c:l:d:" ARGS; do
        case $ARGS in
                c)      CONFIG_FILE="${OPTARG}"
                        ;;
                l)
                        LOG_OUTPUT="${OPTARG}"
                        ;;
                d)
                	DEVEL_MODE="${OPTARG}"
                	;;
                :)
                        echo "Option -${OPTARG} requires an argument."
                        exit 1
                        ;;
                *)
                        usage
                        exit 1
                        ;;
        esac
done

#performs a check on the number of commandline arguments + verifies $2 is a valid file
sanityCheck $#

ghettoVCBrestore ${CONFIG_FILE}

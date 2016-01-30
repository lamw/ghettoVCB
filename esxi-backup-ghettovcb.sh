#!/bin/sh

# ESXi Server (VMs)
SOURCE_ESX_IP=192.168.1.14
SOURCE_ESX_SSH_USR=root
SOURCE_ESX_SSH_KEY=~/.ssh/id_source_esxi

# ESXi with NFS Server VM, having IPMI (for power on/off)
TARGET_IPMI_IP=192.168.1.11
TARGET_IPMI_USR=root
# protected password for IPMI 
TARGET_IPMI_PWD=~/ipmitool.pwd

TARGET_ESX_IP=192.168.1.12
TARGET_ESX_SSH_USR=root
TARGET_ESX_SSH_KEY=~/.ssh/id_target_esxi

# ESXi hosted NFS Server (backup system)
TARGET_NAS_IP=192.168.1.13
TARGET_NAS_SSH_USR=root
TARGET_NAS_SSH_KEY=~/.ssh/id_nas_nfs


######################################################################################
PING_CMD="`which ping` -c1";
PING_LIMIT=1;
SSH_OPT="-aTx -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5";

waitUntilStarted() {
	local MAX_PING_COUNT=${PING_LIMIT};
	if [ -n "$1" ]; then
		while ! ${PING_CMD} "$1">/dev/null 2>&1; do 
			[ ${MAX_PING_COUNT} -eq 0 ] && return 2;
			MAX_PING_COUNT=`expr ${MAX_PING_COUNT} - 1`;
		done;
		return 0;
	else
		echo "waitUntilStarted: Server name or IP expected.";
		return 1;
	fi;
}

waitForShutdown() {
	local MAX_PING_COUNT=${PING_LIMIT};
	if [ -n "$1" ]; then
		while ${PING_CMD} "$1">/dev/null 2>&1; do
			[ ${MAX_PING_COUNT} -eq 0 ] && return 2;
			MAX_PING_COUNT=`expr ${MAX_PING_COUNT} - 1`;
		done;
		return 0;
	else
		echo "waitForShutdown: Server name or IP expected.";
		return 1;
	fi;
}

showErrorMessage() {
	echo -n "+++ ERROR [`date +"%Y-%m-%d %H:%M:%S.%N"`] +++ ";
	[ -n "$1" ] || exit 999 ;
	case $1 in
		10 )
			echo "IPMI: Cannot show power status of ${TARGET_IPMI_IP}";
			;;
		11 )
			echo "IPMI: Cannot power on ${TARGET_IPMI_IP}";
			;;
		20 )
			echo "PING: Cannot reach ESXi server ${TARGET_ESX_IP}";
			;;
		21 )
			echo "PING: Cannot reach NAS server ${TARGET_NAS_IP}";
			;;
		30 )
			echo "SSH: Cannot execute backup task on ${TARGET_NAS_IP}";
			;;
		40 )
			echo "SSH: Cannot execute shutdown command on ${TARGET_NAS_IP}";
			;;
		41 )
			echo "PING: ${TARGET_NAS_IP} is still responding";
			;;
		42 )
			echo "SSH: Cannot execute shutdown command on ${TARGET_ESX_IP}";
			;;
		43 )
			echo "PING: ${TARGET_ESX_IP} is still responding";
			;;
	esac;
	#exit $1;
}

echo "==================================================================";
echo "  Start: 	  `date +"%Y-%m-%d %H:%M:%S.%N"`";
echo "==================================================================";
echo "";

# start quad.goha.lan
echo "  `date +"%Y-%m-%d %H:%M:%S.%N"` - Power on backup system";
echo "------------------------------------------------------------------";
ipmitool -I lan -H ${TARGET_IPMI_IP} -U ${TARGET_IPMI_USR} -f ${TARGET_IPMI_PWD} power status || showErrorMessage 10
ipmitool -I lan -H ${TARGET_IPMI_IP} -U ${TARGET_IPMI_USR} -f ${TARGET_IPMI_PWD} power on     || showErrorMessage 11;
echo "";


echo "  `date +"%Y-%m-%d %H:%M:%S.%N"` - Wait for ESXi and VM";
echo "------------------------------------------------------------------";
# wait for quad.goha.lan
waitUntilStarted ${TARGET_ESX_IP} || showErrorMessage 20;
# wait for omvesxibackup.goha.lan
waitUntilStarted ${TARGET_NAS_IP} || showErrorMessage 21;
sleep 20
echo "";


# start backup script
echo "  `date +"%Y-%m-%d %H:%M:%S.%N"` - Start backup script ";
echo "------------------------------------------------------------------";
ssh ${SSH_OPT} -l ${SOURCE_ESX_SSH_USR} -i ${SOURCE_ESX_SSH_KEY} ${SOURCE_ESX_IP} << EOF
echo "";

# status of source system
echo "  `date +"%Y-%m-%d %H:%M:%S.%N"` - Status source system ";
echo "------------------------------------------------------------------";
esxcli storage nfs list
df -h /vmfs/volumes/ | grep -vi vfat
echo "";

echo "  `date +"%Y-%m-%d %H:%M:%S.%N"` - Start ghettoVCB ";
echo "------------------------------------------------------------------";
# run ghettoVCB script
sh /vmfs/volumes/datastore1/ghettoVCB/run.sh
# sync
sync
echo "";


# create status
echo "  `date +"%Y-%m-%d %H:%M:%S.%N"` - Status source and target ";
echo "------------------------------------------------------------------";
esxcli storage nfs list
df -h /vmfs/volumes/ | grep -vi vfat
find /vmfs/volumes/esxi_backup/ -iname status*
echo "";

# disconnect nfs storage
echo "  `date +"%Y-%m-%d %H:%M:%S.%N"` - Disconnect backup storage ";
echo "------------------------------------------------------------------";
esxcli storage nfs remove -v esxi_backup
echo "";
EOF
[ "$?" -eq "0" ] || showErrorMessage 30;


# shutdown omvesxibackup.goha.lan
echo "  `date +"%Y-%m-%d %H:%M:%S.%N"` - Shutdown VM";
echo "------------------------------------------------------------------";
ssh ${SSH_OPT} -l ${TARGET_NAS_SSH_USR} -i ${TARGET_NAS_SSH_KEY} ${TARGET_NAS_IP} "shutdown -h -y now" || showErrorMessage 40;
waitForShutdown ${TARGET_NAS_IP} || showErrorMessage 41;
echo "";

# shutdown quad.goha.lan
echo "  `date +"%Y-%m-%d %H:%M:%S.%N"` - Shutdown ESXi";
echo "------------------------------------------------------------------";
ssh ${SSH_OPT} -l ${TARGET_ESX_SSH_USR} -i ${TARGET_ESX_SSH_KEY} ${TARGET_ESX_IP} "poweroff" || showErrorMessage 42;
waitForShutdown ${TARGET_ESX_IP} || showErrorMessage 43;
echo "";


echo "";
echo "==================================================================";
echo "  Finished: `date +"%Y-%m-%d %H:%M:%S.%N"`";
echo "==================================================================";

return 0;
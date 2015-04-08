# Author : Thibaut Meyer
# Created Date: 09/07/2014


extractDate(){
	ls $VM_BACKUP_VOLUME"/"$vm"/" | while read name
	do
		echo "Liste fichier backup"
		dateStr=${name:${#vm}:9};
		dt2=$(date -d ${dateStr:1});
		echo $dt2;
		echo $name;
	done
}

printUsage() {
	echo $0": "$1" : wrong option"
    echo "Usage: $0 -b [VM_TO_BACKUP] -r [VM_TO_RESTORE] [PATH_TO_RESTORE] -rm"
    echo
    echo "OPTIONS:"
    echo "   -b     Backup VM"
    echo "   -r     Restore VM"
    echo "   -d    Remove all backup"
    echo
    exit 1
}

while test $# -ne 0 ;do
	case $1 in
	
-b)shift;
	vm=$1; shift;
	echo "Run backup $vm";
	sh ./ghettoVCB.sh -m $vm -g ghettoVCB.conf;
	echo "Backup end"
	;;

-r)shift;
	vm=$1; shift;
	PATH_TO_RESTORE=$1; shift;
	echo "Run restore $vm"

	source ghettoVCB.conf
	cat ghettoVCB-restore_vm_restore_configuration_template > vm_to_restore;
	echo "\""$vm";"$PATH_TO_RESTORE";3\"" >> vm_to_restore;
	sh ./ghettoVCB-restore.sh -c vm_to_restore -f 1;
	echo "Restore end"
	;;

-d)shift;
	echo "Remove all backup of this vm"
	vm=$1; shift;
	source ghettoVCB.conf
	rm -R $VM_BACKUP_VOLUME"/"$vm;
	echo "All backup of this vm are removed"
;;

-h)shift;
	printUsage
	exit 1;
	;;

*)printUsage
	exit 1;
	;;
esac
done

exit 0;
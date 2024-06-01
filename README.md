# ghettoVCB

## Table of Contents

* [Description](#description)
* [Features](#features)
* [Requirements](#requirements)
* [Download](#download)
* [Install](#install)
* [Uninstall](#uninstall)
* [Build VIB and Offline Bundle](#build-vib-and-offline-bundle)
* [Configuration Options](#configuration-options)
* [Usage](#usage)
* [Sample Execution](#sample-execution)
    * [Dry Run](#dry-run)
    * [Debug](#debug)
    * [Backup VMs stored in a list](#backup-vms-stored-in-a-list)
    * [Backup Single VM using CLI](#backup-single-vm-using-cli)
    * [Backup All VMs residing on specific host](#backup-all-vms-residing-on-specific-host)
    * [Backup VMs based on individual VM backup policies](#backup-vms-based-on-individual-vm-backup-policies)
* [Stopping ghettoVCB Process](#stopping-ghettovcb-process)
* [Scheduling Backups using Cron](#scheduling-backups-using-cron)
* [Restore Backups](#restore-backups)


## Description

The ghettoVCB script performs backups of virtual machines residing on ESX(i) 3.x, 4.x, 5.x, 6.x, 7.x & 8.x servers using methodology similar to VMware's VCB tool. The script takes snapshots of live running virtual machines, backs up the  master VMDK(s) and then upon completion, deletes the snapshot until the next backup. The only caveat is that it utilizes resources available to the ESXi Shell running the backups as opposed to following the traditional method of offloading virtual machine backups through a VCB proxy.

This script has been tested on ESX 3.5/4.x/5.x and ESXi 3.5/4.x/5.x/6.x/7.x/8.x and supports the following backup mediums: LOCAL STORAGE, SAN and NFS. The script is non-interactive and can be setup to run via cron. Currently, this script accepts a text file that lists the display names of virtual machine(s) that are to be backed up. Additionally, one can specify a folder containing configuration files on a per VM basis for  granular control over backup policies.

Additionally, for ESX(i) environments that don't have persistent NFS datastores designated for backups, the script offers the ability to automatically connect the ESX(i) server to a NFS exported folder and then upon backup completion, disconnect it from the ESX(i) server. The connection is established by creating an NFS datastore link which enables monolithic (or thick) VMDK backups as opposed to using the usual  *nix mount command which necessitates breaking VMDK files into the 2gbsparse format for backup. Enabling this mode is self-explanatory and will evidently be so when editing the script (Note: `VM_BACKUP_VOLUME` variable is ignored if `ENABLE_NON_PERSISTENT_NFS=1`).

In its current configuration, the script will allow up to 3 unique backups of the Virtual Machine before it will overwrite the previous backups; this however, can be modified to fit procedures if need be. Please be diligent in running the script in a test or staging environment before using it on production live Virtual Machines; this script functions well within our environment but there is a chance that  it may not fit well into other environments.

**Note:** If you have found this script to be useful and would like to contribute back, feel free to [donate a cup of coffee](https://www.buymeacoffee.com/lamw) ☕😁

## Features
* Online back up of VM(s)
* Support for multiple VMDK disk(s) backup per VM
    * Only valid VMDK(s) presented to the VM will be backed up
* Ability to shutdown guestOS and initiate backup process and power on VM afterwards with the option of hard power timeout
* Allow spaces in VM(s) backup list (not recommended and not a best practice)
* Ensure that snapshot removal process completes prior to to continuing onto the next VM backup
    * VM(s) that intially contain snapshots will not be backed up and will be ignored
* Ability to specify the number of backup rotations for VM
* Output back up VMDK(s) in either ZEROEDTHICK (default behavior) or 2GB SPARSE or THIN or EAGERZEROEDTHICK format
* Support for both SCSI and IDE disks
* Non-persistent NFS backup
* Fully support VMDK(s) stored across multiple datastores
* Ability to compress backups
* Ability to configure individual VM backup policies
* Ability to include/exclude specific VMDK(s) per VM (requires individual VM backup policy setup)
* Ability to configure logging output to file
* Independent disk awareness (will ignore VMDK)
* New timeout variables for shutdown and snapshot creations
* Ability to configure snapshots with both memory and/or quiesce options
* Ability to configure disk adapter format
* Additional debugging information including dry run execution
* Support for VMs with both virtual/physical RDM (pRDM will be ignored and not backed up)
* Support for global ghettoVCB configuration file
* Support for VM exclusion list
* Ability to backup all VMs residing on a specific host w/o specifying VM list
* Implemented simple locking mechenism to ensure only 1 instance of ghettoVCB is running per host
* Updated backup directory structure - rsync friendly
* Additional logging and final status output
* Logging of ghettoVCB PID (proces id)
* Email backup logs
* Rsync "Link" Support (Experimental Suppport)
* Enhanced "dryrun" details including configuration and/or VMDK(s) issues
* New storage debugging details pre/post backup
* Quick email status summary
* Support for individual VM backup via command-line
* Support VM(s) with existing snapshots
* Support mulitple running instances of ghettoVCB
* Configure VM shutdown/startup order
* Support changing custom VM name during restore

## Requirements:
* VMs running on ESX(i) 3.5/4.x+/5.x/6.x/7.x/8.x
* SSH console access to ESX(i) host

## Download

Latest ghettoVCB VIB and Offline Bundle can be downloaded from [here](https://github.com/lamw/ghettoVCB/releases)

## Install

You can quickly install/update ghettoVCB by downloading and installing either the [VIB or offline bundle](https://github.com/lamw/ghettoVCB/releases) using the following commands. If you wish to update to latest ghettoVCB release and are using the ghettovcb.conf file and wish to have your settings persist, make sure to use the *update* command instead of *install*

Once installed, you will find all ghettoVCB configuration files located in:
```console
/opt/ghettovcb/ghettoVCB.conf
/opt/ghettovcb/ghettoVCB-restore_vm_restore_configuration_template
/opt/ghettovcb/ghettoVCB-vm_backup_configuration_template
```

Both ghettoVCB and ghettoVCB-restore scripts are located in:
```console
/opt/ghettovcb/bin/ghettoVCB.sh
/opt/ghettovcb/bin/ghettoVCB-restore.sh
```

### For ESXi 5.x to 6.x

Install VIB
```
esxcli software vib install -v /vghetto-ghettoVCB-7x.vib -f
```

Update VIB
```
esxcli software vib update -v /vghetto-ghettoVCB-7x.vib -f
```

Retrieve installation
```console
esxcli software vib get -n ghettoVCB
```

### For ESXi 7.x

Install VIB
```
esxcli software vib install -v /vghetto-ghettoVCB-7x.vib -f
```

Install offline bundle
```
esxcli software vib install -d /vghetto-ghettoVCB-offline-bundle-7x.zip -f
```

Update VIB
```
esxcli software vib update -v /vghetto-ghettoVCB-7x.vib -f
```

Update offline bundle
```
esxcli software vib update -d /vghetto-ghettoVCB-offline-bundle-7x.zip -f
```

Retrieve installation
```console
esxcli software vib get -n ghettoVCB
```

### For ESXi 8.x and later

Install VIB
```
esxcli software vib install -v /vghetto-ghettoVCB-8x.vib -f
```

Install offline bundle
```
esxcli software vib install -d /vghetto-ghettoVCB-offline-bundle-8x.zip -f
```

Update VIB
```
esxcli software vib update -v /vghetto-ghettoVCB-8x.vib -f
```

Update offline bundle
```
esxcli software vib update -d /vghetto-ghettoVCB-offline-bundle-8x.zip -f
```

Retrieve installation
```console
esxcli software vib get -n ghettoVCB
```

## Uninstall

Remove ghettoVCB

```console
esxcli software vib remove -n ghettoVCB
```

> **Note:** If the installation takes some time. Just wait. This is normal.

## Build VIB and Offline Bundle

See the build documentation [here](build/README.md)

## Configuration Options

The following variables need to be defined within the script or in VM backup policy prior to execution.

Defining the backup datastore and folder in which the backups are stored (if folder does not exist, it will automatically be created):

```console
VM_BACKUP_VOLUME=/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS
```

Defining the backup disk format (zeroedthick, eagerzeroedthick, thin, and 2gbsparse are available):
```console
DISK_BACKUP_FORMAT=thin
```

> **Note:** If you are using the 2gbsparse on an ESXi 5.1 host, backups may fail. Please download the latest version of the ghettoVCB script which automatically resolves this or take a look at [this article](https://williamlam.com/2012/09/2gbsparse-disk-format-no-longer-working.html) for the details.

Defining the backup rotation per VM:
```console
VM_BACKUP_ROTATION_COUNT=3
```

Defining whether the VM is powered down or not prior to backup (1 = enable, 0 = disable):
```console
POWER_VM_DOWN_BEFORE_BACKUP=0
```

> **Note:** VM(s) that are powered off will not require snapshoting

Defining whether the VM can be hard powered off when `POWER_VM_DOWN_BEFORE_BACKUP` is enabled and VM does not have VMware Tools installed
```console
ENABLE_HARD_POWER_OFF=0
```

If `ENABLE_HARD_POWER_OFF` is enabled, then this defines the number of (60sec) iterations the script will before executing a hard power off when:
```console
ITER_TO_WAIT_SHUTDOWN=3
```

The number (60sec) iterations the script will wait when powering off the VM and will give up and ignore the particular VM for backup:
```console
POWER_DOWN_TIMEOUT=5
```

The number (60sec) iterations the script will wait when taking a snapshot of a VM and will give up and ignore the particular VM for  backup:
```console
SNAPSHOT_TIMEOUT=15
```

Defining whether or not to enable compression (1 = enable, 0 = disable):
```console
ENABLE_COMPRESSION=0
```

> **Note:** With ESXi 3.x/4.x/5.x, there is a limitation of the maximum size of a VM for compression within the unsupported Busybox Console which _should_ not affect backups running classic ESX 3.x,4.x or 5.x. On ESXi 3.x the largest supported VM is 4GB for compression and on ESXi 4.x the largest supported VM is 8GB. If you try to compress a larger VM, you may run into issues when trying to extract upon a restore. **PLEASE TEST THE RESTORE PROCESS BEFORE MOVING TO PRODUCTION SYSTEMS!**. Please note, do not mix uncompressed backups with  compressed backups. Ensure that directories selected for backups do not contain any backups with previous versions of ghettoVCB before enabling  and implementing the compressed backups feature.

Defining whether virtual machine memory is snapped and if quiescing is enabled (1 = enable, 0 = disable):
```console
VM_SNAPSHOT_MEMORY=0
VM_SNAPSHOT_QUIESCE=0
```

> **Note:** `VM_SNAPSHOT_MEMORY` is only used to ensure when the snapshot is taken, it's memory contents  are also captured. This is only relevant to the actual snapshot and it's  not used in any shape/way/form in regards to the backup. All backups  taken whether your VM is running or offline will result in an offline VM  backup when you restore. This was originally added for debugging  purposes and in generally should be left disabled

Defining VMDK(s) to backup from a particular VM either a list of vmdks or "all"
```console
VMDK_FILES_TO_BACKUP="myvmdk.vmdk"
```

Defining whether or not VM(s) with existing snapshots can be backed up. This flag means it will **CONSOLIDATE ALL EXISTING SNAPSHOTS** for a VM prior to starting the backup (1 = yes, 0 = no):
```console
ALLOW_VMS_WITH_SNAPSHOTS_TO_BE_BACKEDUP=0
```

Defining the order of which VM(s) should be shutdown first, especially if there is a dependency between multiple VM(s). This should be a comma seperate list of VM(s)
```console
VM_SHUTDOWN_ORDER=vm1,vm2,vm3
```

Defining the order of VM(s) that should be started up first after backups have completed, especially if there is a dependency between multiple VM(s). This should be a comma seperate list of VM(s)
```console
VM_STARTUP_ORDER=vm3,vm2,vm1
```

Defining NON-PERSISTENT NFS Backup Volume (1 = yes, 0 = no):
```console
ENABLE_NON_PERSISTENT_NFS=0
```

> **Note:** This is meant for environments that do not want a persisted connection to their NFS backup volume and allows the NFS volume to only be mounted during backups. The script expects the following 5 variables to be defined if this is to be used: `UNMOUNT_NFS`, `NFS_SERVER`, `NFS_MOUN`T`, `NFS_LOCAL_NAME` and `NFS_VM_BACKUP_DIR`

Defining whether or not to unmount the NFS backup volume (1 = yes, 0 = no):
```console
UNMOUNT_NFS=0
```

Defining the NFS server address (IP/hostname):
```console
NFS_SERVER=172.51.0.192
```

Defining the NFS export path:
```console
NFS_MOUNT=/upload
```

Defining the NFS datastore name:
```console
NFS_LOCAL_NAME=backup
```

Defining the NFS backup directory for VMs:
```console
NFS_VM_BACKUP_DIR=mybackups
```

> **Note:** Only supported if you are running vSphere 4. and later. If you are having issues with sending mail, please take a look at Email Backup Log section

Defining whether or not to email backup logs (1 = yes, 0 = no):
```console
EMAIL_LOG=1
```

Defining whether or not to email message will be deleted off the host  whether it is successful in sending, this is used for debugging  purposes. (1 = yes, 0 = no):
```console
EMAIL_DEBUG=1
```

Defining email server:
```console
EMAIL_SERVER=auroa.primp-industries.com
```

Defining email server port:
```console
EMAIL_SERVER_PORT=25
```

Defining email delay interval (useful if you have slow SMTP server and would like to include a delay in netcat using -i param, default is 1second):
```console
EMAIL_DELAY_INTERVAL=1
```

Defining recipient of the email (comma separated):
```console
EMAIL_TO=auroa@primp-industries.com
```

Defining from user which may require specific domain entry depending on email server configurations:
```console
EMAIL_FROM=root@ghettoVCB
```

> **Note:** nc (netcat) utility must be present for email support to function, this utility is a now a default with the release of vSphere 4.1 or greater, previous releases of VI 3.5 and/or vSphere 4.0 does not contain this utility. The reason this is listed as experimental is it may not be compatible with all email servers as the script utlizes nc (netcat) utility to communicate to an email server. This feature is  provided as-is with no guarantees. If you enable this feature, a  separate log will be generated along side  any normal logging which will be used to email recipient. If for whatever reason, the email fails to  send, an entry will appear per the normal logging mechanism.

If you are running ESXi 5.1 and later, you will need to create a custom firewall rule to allow your email traffic to go out which I will assume is default port 25. Here are the steps for creating a custom email rule.

Step 1 - Create a file called /etc/vmware/firewall/email.xml with contains the following:
```console
<ConfigRoot>
  <service>
    <id>email</id>
    <rule id="0000">
      <direction>outbound</direction>
      <protocol>tcp</protocol>
      <porttype>dst</porttype>
      <port>25</port>
    </rule>
    <enabled>true</enabled>
    <required>false</required>
  </service>
</ConfigRoot>
```

Step 2 - Reload the ESXi firewall by running the following ESXCLI command:
```console
# esxcli network firewall refresh
```

Step 3 - Confirm that your email rule has been loaded by running the following ESXCLI command:
```console
# esxcli network firewall ruleset list | grep email
email                  true
```

Step 4 - Connect to your email server by usingn nc (netcat) by running the following command and specifying the IP Address/Port of your email server:
```console

# nc 172.30.0.107 25
220 mail.primp-industries.com ESMTP Postfix
```

You should recieve a response from your email server and you can enter Ctrl+C to exit. This custom ESXi firewall rule will not persist after a reboot, so you should create a custom VIB to ensure it persists after a system reboot. Please take a look at [this article](https://williamlam.com/2023/07/creating-a-custom-vib-for-esxi-8-x.html) for the details.


Defining to support RSYNC symbolic link creation (1 = yes, 0 = no):
```console
RSYNC_LINK=0
```

To make use of this feature, modify the variable RSYNC_LINK from 0  to 1. Please note, this is an experimental feature request from users that rely on rsync to replicate changes from one datastore volume to  another datastore volume. The premise of this feature is to have a standardized folder that rsync can monitor for changes to replicate to  another backup datastore. When this feature is enabled, a symbolic link  will be generated with the format of "<VMNAME>-symlink" and will  reference the latest successful VM backup. You can then rely on this  symbolic link to watch for changes and replicate to your backup  datastore.

Here is an example of what this would look like:
```console
[root@himalaya ghettoVCB]# ls -la /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS/vcma/
total 0
drwxr-xr-x 1 nobody nobody 110 Sep 27 08:08 .
drwxr-xr-x 1 nobody nobody  17 Sep 16 14:01 ..
lrwxrwxrwx 1 nobody nobody  89 Sep 27 08:08 vcma-symlink -> /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS/vcma/vcma-2010-09-27_08-07-37
drwxr-xr-x 1 nobody nobody  58 Sep 27 08:04 vcma-2010-09-27_08-04-26
drwxr-xr-x 1 nobody nobody  58 Sep 27 08:06 vcma-2010-09-27_08-05-55
drwxr-xr-x 1 nobody nobody  58 Sep 27 08:08 vcma-2010-09-27_08-07-37
```

> **Note:** This enables an automatic creation of a generic symbolic link (both a  relative & absolution path) in which users can refer to run  replication backups using rsync from a remote host. This does not  actually support rsync backups with ghettoVCB. Please take a look at the  Rsync Section of the documentation for more details.

A sample global ghettoVCB configuration file is included with the download called ghettoVCB.conf. It contains the same variables as defined from above and allows a user  to customize and define multiple global configurations based on a user's environment.

```console
# cat ghettoVCB.conf
VM_BACKUP_VOLUME=/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS
DISK_BACKUP_FORMAT=thin
VM_BACKUP_ROTATION_COUNT=3
POWER_VM_DOWN_BEFORE_BACKUP=0
ENABLE_HARD_POWER_OFF=0
ITER_TO_WAIT_SHUTDOWN=3
POWER_DOWN_TIMEOUT=5
ENABLE_COMPRESSION=0
VM_SNAPSHOT_MEMORY=0
VM_SNAPSHOT_QUIESCE=0
ALLOW_VMS_WITH_SNAPSHOTS_TO_BE_BACKEDUP=0
ENABLE_NON_PERSISTENT_NFS=0
UNMOUNT_NFS=0
NFS_SERVER=172.30.0.195
NFS_MOUNT=/nfsshare
NFS_LOCAL_NAME=nfs_storage_backup
NFS_VM_BACKUP_DIR=mybackups
SNAPSHOT_TIMEOUT=15
EMAIL_LOG=0
EMAIL_SERVER=auroa.primp-industries.com
EMAIL_SERVER_PORT=25
EMAIL_DELAY_INTERVAL=1
EMAIL_TO=auroa@primp-industries.com
EMAIL_FROM=root@ghettoVCB
WORKDIR_DEBUG=0
VM_SHUTDOWN_ORDER=
VM_STARTUP_ORDER=
```

To override any existing configurations within the ghettoVCB.sh script and to use a global configuration file, user just needs to specify the -g flag and path to global configuration file.

Running multiple instances of ghettoVCB is now supported with the latest release by specifying the working directory (-w) flag.

By default, the working directory of the ghettoVCB instance is /tmp/ghettoVCB.work and you can run another instance by providing an alternate working directory. You should try to minimize the number of ghettoVCB instances running on your ESXi host as it does consume some amount of resources when running in the ESXi Shell. This is considered an experimental feature, so please test in a development environment to ensure everything is working prior to moving to production system.

## Usage

```
# /opt/ghettovcb/bin/ghettoVCB.sh
###############################################################################
#
# ghettoVCB for ESX/ESXi 3.5, 4.x, 5.x, 6.x, 7.x & 8.x
# Author: William Lam
# http://www.virtuallyghetto.com/
# Documentation: http://communities.vmware.com/docs/DOC-8760
# Created: 11/17/2008
# Last modified: 2023_09_29 Version 1
#
###############################################################################

Usage: ghettoVCB.sh [options]

OPTIONS:
   -a     Backup all VMs on host
   -f     List of VMs to backup
   -m     Name of VM to backup (overrides -f)
   -j     Job name to show in email report subject (makes sense only in conjunction with -f)
   -c     VM configuration directory for VM backups
   -g     Path to global ghettoVCB configuration file
   -l     File to output logging
   -w     ghettoVCB work directory (default: /tmp/ghettoVCB.work)
   -d     Debug level [info|debug|dryrun] (default: info)

(e.g.)

Backup list of VMs from a file (optionally include a job name for the email report)
	/opt/ghettovcb/bin/ghettoVCB.sh -f vms_to_backup [ -j myJob ]

Backup a single VM
	/opt/ghettovcb/bin/ghettoVCB.sh -m vm_to_backup

Backup all VMs residing on this host
	/opt/ghettovcb/bin/ghettoVCB.sh -a

Backup all VMs residing on this host except for the VMs in the exclusion list
	/opt/ghettovcb/bin/ghettoVCB.sh -a -e vm_exclusion_list

Backup VMs based on specific configuration located in directory
	/opt/ghettovcb/bin/ghettoVCB.sh -f vms_to_backup -c vm_backup_configs

Backup VMs using global ghettoVCB configuration file
	/opt/ghettovcb/bin/ghettoVCB.sh -f vms_to_backup -g /global/ghettoVCB.conf

Output will log to /tmp/ghettoVCB.log (consider logging to local or remote datastore to persist logs)
	/opt/ghettovcb/bin/ghettoVCB.sh -f vms_to_backup -l /vmfs/volume/local-storage/ghettoVCB.log

Dry run (no backup will take place)
	/opt/ghettovcb/bin/ghettoVCB.sh -f vms_to_backup -d dryrun
```

The input to this script is a file that contains the display name of the  virtual machine(s) separated by a newline. When creating this file on a non-Linux/UNIX system, you may introduce ^M character which can cause  the script to miss-behave. To ensure this does not occur, plesae create  the file on the ESX/ESXi host.

Here is a sample of what the file would look like:
```console
[root@himalaya ~]# cat vms_to_backup
vCOPS
vMA
vCloudConnector
```

## Sample Execution:

### Dry Run

This execution mode provides a quick summary of details on whether a given set of VM(s)/VMDK(s) will be backed up. It provides additional information such as VMs that may have snapshots, VMDK(s) that are configured as independent disks, or other issues that may cause a VM or VMDK to not backed up.

* Log verbosity: dryrun
* Log output: stdout & /tmp (default)
    * Logs by default will be stored in /tmp, these log files may not persist through reboots, especially when dealing with ESXi. You should log to either a local or remote datastore to ensure that logs are kept upon a reboot.

```console
[root@himalaya]# /opt/ghettovcb/bin/ghettoVCB.sh -f vms_to_backup -d dryrun
Logging output to "/tmp/ghettoVCB-2011-03-13_15-19-57.log" ...
2011-03-13 15:19:57 -- info: ============================== ghettoVCB LOG START ==============================

2011-03-13 15:19:57 -- info: CONFIG - VERSION = 2011_03_13_1
2011-03-13 15:19:57 -- info: CONFIG - GHETTOVCB_PID = 30157
2011-03-13 15:19:57 -- info: CONFIG - VM_BACKUP_VOLUME = /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS
2011-03-13 15:19:57 -- info: CONFIG - VM_BACKUP_ROTATION_COUNT = 3
2011-03-13 15:19:57 -- info: CONFIG - VM_BACKUP_DIR_NAMING_CONVENTION = 2011-03-13_15-19-57
2011-03-13 15:19:57 -- info: CONFIG - DISK_BACKUP_FORMAT = thin
2011-03-13 15:19:57 -- info: CONFIG - POWER_VM_DOWN_BEFORE_BACKUP = 0
2011-03-13 15:19:57 -- info: CONFIG - ENABLE_HARD_POWER_OFF = 0
2011-03-13 15:19:57 -- info: CONFIG - ITER_TO_WAIT_SHUTDOWN = 3
2011-03-13 15:19:57 -- info: CONFIG - POWER_DOWN_TIMEOUT = 5
2011-03-13 15:19:57 -- info: CONFIG - SNAPSHOT_TIMEOUT = 15
2011-03-13 15:19:57 -- info: CONFIG - LOG_LEVEL = dryrun
2011-03-13 15:19:57 -- info: CONFIG - BACKUP_LOG_OUTPUT = /tmp/ghettoVCB-2011-03-13_15-19-57.log
2011-03-13 15:19:57 -- info: CONFIG - VM_SNAPSHOT_MEMORY = 0
2011-03-13 15:19:57 -- info: CONFIG - VM_SNAPSHOT_QUIESCE = 0
2011-03-13 15:19:57 -- info: CONFIG - VMDK_FILES_TO_BACKUP = all
2011-03-13 15:19:57 -- info: CONFIG - EMAIL_LOG = 0
2011-03-13 15:19:57 -- info:
2011-03-13 15:19:57 -- dryrun: ###############################################
2011-03-13 15:19:57 -- dryrun: Virtual Machine: scofield
2011-03-13 15:19:57 -- dryrun: VM_ID: 704
2011-03-13 15:19:57 -- dryrun: VMX_PATH: /vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield.vmx
2011-03-13 15:19:57 -- dryrun: VMX_DIR: /vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield
2011-03-13 15:19:57 -- dryrun: VMX_CONF: scofield/scofield.vmx
2011-03-13 15:19:57 -- dryrun: VMFS_VOLUME: himalaya-local-SATA.RE4-GP:Storage
2011-03-13 15:19:57 -- dryrun: VMDK(s):
2011-03-13 15:19:58 -- dryrun:  scofield_3.vmdk 3 GB
2011-03-13 15:19:58 -- dryrun:  scofield_2.vmdk 2 GB
2011-03-13 15:19:58 -- dryrun:  scofield_1.vmdk 1 GB
2011-03-13 15:19:58 -- dryrun:  scofield.vmdk   5 GB
2011-03-13 15:19:58 -- dryrun: INDEPENDENT VMDK(s):
2011-03-13 15:19:58 -- dryrun: TOTAL_VM_SIZE_TO_BACKUP: 11 GB
2011-03-13 15:19:58 -- dryrun: ###############################################

2011-03-13 15:19:58 -- dryrun: ###############################################
2011-03-13 15:19:58 -- dryrun: Virtual Machine: vMA
2011-03-13 15:19:58 -- dryrun: VM_ID: 1440
2011-03-13 15:19:58 -- dryrun: VMX_PATH: /vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/vMA/vMA.vmx
2011-03-13 15:19:58 -- dryrun: VMX_DIR: /vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/vMA
2011-03-13 15:19:58 -- dryrun: VMX_CONF: vMA/vMA.vmx
2011-03-13 15:19:58 -- dryrun: VMFS_VOLUME: himalaya-local-SATA.RE4-GP:Storage
2011-03-13 15:19:58 -- dryrun: VMDK(s):
2011-03-13 15:19:58 -- dryrun:  vMA-000002.vmdk 5 GB
2011-03-13 15:19:58 -- dryrun: INDEPENDENT VMDK(s):
2011-03-13 15:19:58 -- dryrun: TOTAL_VM_SIZE_TO_BACKUP: 5 GB
2011-03-13 15:19:58 -- dryrun: Snapshots found for this VM, please commit all snapshots before continuing!
2011-03-13 15:19:58 -- dryrun: THIS VIRTUAL MACHINE WILL NOT BE BACKED UP DUE TO EXISTING SNAPSHOTS!
2011-03-13 15:19:58 -- dryrun: ###############################################

2011-03-13 15:19:58 -- dryrun: ###############################################
2011-03-13 15:19:58 -- dryrun: Virtual Machine: vCloudConnector
2011-03-13 15:19:58 -- dryrun: VM_ID: 2064
2011-03-13 15:19:58 -- dryrun: VMX_PATH: /vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/vCloudConnector/vCloudConnector.vmx
2011-03-13 15:19:58 -- dryrun: VMX_DIR: /vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/vCloudConnector
2011-03-13 15:19:58 -- dryrun: VMX_CONF: vCloudConnector/vCloudConnector.vmx
2011-03-13 15:19:58 -- dryrun: VMFS_VOLUME: himalaya-local-SATA.RE4-GP:Storage
2011-03-13 15:19:58 -- dryrun: VMDK(s):
2011-03-13 15:19:59 -- dryrun:  vCloudConnector.vmdk    3 GB
2011-03-13 15:19:59 -- dryrun: INDEPENDENT VMDK(s):
2011-03-13 15:19:59 -- dryrun:  vCloudConnector_1.vmdk  40 GB
2011-03-13 15:19:59 -- dryrun: TOTAL_VM_SIZE_TO_BACKUP: 3 GB
2011-03-13 15:19:59 -- dryrun: Snapshots can not be taken for indepdenent disks!
2011-03-13 15:19:59 -- dryrun: THIS VIRTUAL MACHINE WILL NOT HAVE ALL ITS VMDKS BACKED UP!
2011-03-13 15:19:59 -- dryrun: ###############################################

2011-03-13 15:19:59 -- info: ###### Final status: OK, only a dryrun. ######

2011-03-13 15:19:59 -- info: ============================== ghettoVCB LOG END ================================
```

In the example above, we have 3 VMs to be backed up:

* scofield has 4 VMDK(s) that total up to 11GB and does not contain any snapshots/independent disks and this VM should backup without any issues
* vMA has 1 VMDK but it also contains a snapshot and clearly this VM will not be backed up until the snapshot has been committed
* vCloudConnector has 2 VMDK(s), one which is 3GB and another which is 40GB and configured as an independent disk. Since snapshots do not affect independent disk, only the 3GB VMDK will be backed up for this VM as denoted by the "TOTAL_VM_SIZE_TO_BACKUP"

### Debug

This execution modes provides more in-depth information about environment/backup process including additional storage debugging information which provides information about both the source/destination datastore pre and post backups. This can be very useful in troubleshooting backups

* Log verbosity: debug
* Log output: stdout & /tmp (default)
    * Logs by default will be stored in /tmp, these log files may not persist  through reboots, especially when dealing with ESXi. You should log to  either a local or remote datastore to ensure that logs are kept upon a reboot.

```console
[root@himalaya]# /opt/ghettovcb/bin/ghettoVCB.sh -f vms_to_backup -d debug
Logging output to "/tmp/ghettoVCB-2011-03-13_15-27-59.log" ...
2011-03-13 15:27:59 -- info: ============================== ghettoVCB LOG START ==============================

2011-03-13 15:27:59 -- debug: Succesfully acquired lock directory - /tmp/ghettoVCB.lock

2011-03-13 15:27:59 -- debug: HOST VERSION: VMware ESX 4.1.0 build-260247
2011-03-13 15:27:59 -- debug: HOST LEVEL: VMware ESX 4.1.0 GA
2011-03-13 15:27:59 -- debug: HOSTNAME: himalaya.primp-industries.com

2011-03-13 15:27:59 -- info: CONFIG - VERSION = 2011_03_13_1
2011-03-13 15:27:59 -- info: CONFIG - GHETTOVCB_PID = 31074
2011-03-13 15:27:59 -- info: CONFIG - VM_BACKUP_VOLUME = /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS
2011-03-13 15:27:59 -- info: CONFIG - VM_BACKUP_ROTATION_COUNT = 3
2011-03-13 15:27:59 -- info: CONFIG - VM_BACKUP_DIR_NAMING_CONVENTION = 2011-03-13_15-27-59
2011-03-13 15:27:59 -- info: CONFIG - DISK_BACKUP_FORMAT = thin
2011-03-13 15:27:59 -- info: CONFIG - POWER_VM_DOWN_BEFORE_BACKUP = 0
2011-03-13 15:27:59 -- info: CONFIG - ENABLE_HARD_POWER_OFF = 0
2011-03-13 15:27:59 -- info: CONFIG - ITER_TO_WAIT_SHUTDOWN = 3
2011-03-13 15:27:59 -- info: CONFIG - POWER_DOWN_TIMEOUT = 5
2011-03-13 15:27:59 -- info: CONFIG - SNAPSHOT_TIMEOUT = 15
2011-03-13 15:27:59 -- info: CONFIG - LOG_LEVEL = debug
2011-03-13 15:27:59 -- info: CONFIG - BACKUP_LOG_OUTPUT = /tmp/ghettoVCB-2011-03-13_15-27-59.log
2011-03-13 15:27:59 -- info: CONFIG - VM_SNAPSHOT_MEMORY = 0
2011-03-13 15:27:59 -- info: CONFIG - VM_SNAPSHOT_QUIESCE = 0
2011-03-13 15:27:59 -- info: CONFIG - VMDK_FILES_TO_BACKUP = all
2011-03-13 15:27:59 -- info: CONFIG - EMAIL_LOG = 0
2011-03-13 15:27:59 -- info:
2011-03-13 15:28:01 -- debug: Storage Information before backup:
2011-03-13 15:28:01 -- debug: SRC_DATASTORE: himalaya-local-SATA.RE4-GP:Storage
2011-03-13 15:28:01 -- debug: SRC_DATASTORE_CAPACITY: 1830.5 GB
2011-03-13 15:28:01 -- debug: SRC_DATASTORE_FREE: 539.4 GB
2011-03-13 15:28:01 -- debug: SRC_DATASTORE_BLOCKSIZE: 4
2011-03-13 15:28:01 -- debug: SRC_DATASTORE_MAX_FILE_SIZE: 1024 GB
2011-03-13 15:28:01 -- debug:
2011-03-13 15:28:01 -- debug: DST_DATASTORE: dlgCore-NFS-bigboi.VM-Backups
2011-03-13 15:28:01 -- debug: DST_DATASTORE_CAPACITY: 1348.4 GB
2011-03-13 15:28:01 -- debug: DST_DATASTORE_FREE: 296.8 GB
2011-03-13 15:28:01 -- debug: DST_DATASTORE_BLOCKSIZE: NA
2011-03-13 15:28:01 -- debug: DST_DATASTORE_MAX_FILE_SIZE: NA
2011-03-13 15:28:01 -- debug:
2011-03-13 15:28:02 -- info: Initiate backup for scofield
2011-03-13 15:28:02 -- debug: /usr/sbin/vmkfstools -i "/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield_3.vmdk" -a "buslogic" -d "thin" "/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS/scofield/scofield-2011-03-13_15-27-59/scofield_3.vmdk"
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield_3.vmdk'...
Clone: 37% done.
2011-03-13 15:28:04 -- debug: /usr/sbin/vmkfstools -i "/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield_2.vmdk" -a "buslogic" -d "thin" "/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS/scofield/scofield-2011-03-13_15-27-59/scofield_2.vmdk"
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield_2.vmdk'...
Clone: 85% done.
2011-03-13 15:28:05 -- debug: /usr/sbin/vmkfstools -i "/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield_1.vmdk" -a "buslogic" -d "thin" "/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS/scofield/scofield-2011-03-13_15-27-59/scofield_1.vmdk"

2011-03-13 15:28:06 -- debug: /usr/sbin/vmkfstools -i "/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield.vmdk" -a "buslogic" -d "thin" "/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS/scofield/scofield-2011-03-13_15-27-59/scofield.vmdk"
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield.vmdk'...
Clone: 78% done.
2011-03-13 15:29:52 -- info: Backup Duration: 1.83 Minutes
2011-03-13 15:29:52 -- info: Successfully completed backup for scofield!

2011-03-13 15:29:54 -- debug: Storage Information after backup:
2011-03-13 15:29:54 -- debug: SRC_DATASTORE: himalaya-local-SATA.RE4-GP:Storage
2011-03-13 15:29:54 -- debug: SRC_DATASTORE_CAPACITY: 1830.5 GB
2011-03-13 15:29:54 -- debug: SRC_DATASTORE_FREE: 539.4 GB
2011-03-13 15:29:54 -- debug: SRC_DATASTORE_BLOCKSIZE: 4
2011-03-13 15:29:54 -- debug: SRC_DATASTORE_MAX_FILE_SIZE: 1024 GB
2011-03-13 15:29:54 -- debug:
2011-03-13 15:29:54 -- debug: DST_DATASTORE: dlgCore-NFS-bigboi.VM-Backups
2011-03-13 15:29:54 -- debug: DST_DATASTORE_CAPACITY: 1348.4 GB
2011-03-13 15:29:54 -- debug: DST_DATASTORE_FREE: 296.8 GB
2011-03-13 15:29:54 -- debug: DST_DATASTORE_BLOCKSIZE: NA
2011-03-13 15:29:54 -- debug: DST_DATASTORE_MAX_FILE_SIZE: NA
2011-03-13 15:29:54 -- debug:
2011-03-13 15:29:55 -- debug: Storage Information before backup:
2011-03-13 15:29:55 -- debug: SRC_DATASTORE: himalaya-local-SATA.RE4-GP:Storage
2011-03-13 15:29:55 -- debug: SRC_DATASTORE_CAPACITY: 1830.5 GB
2011-03-13 15:29:55 -- debug: SRC_DATASTORE_FREE: 539.4 GB
2011-03-13 15:29:55 -- debug: SRC_DATASTORE_BLOCKSIZE: 4
2011-03-13 15:29:55 -- debug: SRC_DATASTORE_MAX_FILE_SIZE: 1024 GB
2011-03-13 15:29:55 -- debug:
2011-03-13 15:29:55 -- debug: DST_DATASTORE: dlgCore-NFS-bigboi.VM-Backups
2011-03-13 15:29:55 -- debug: DST_DATASTORE_CAPACITY: 1348.4 GB
2011-03-13 15:29:55 -- debug: DST_DATASTORE_FREE: 296.8 GB
2011-03-13 15:29:55 -- debug: DST_DATASTORE_BLOCKSIZE: NA
2011-03-13 15:29:55 -- debug: DST_DATASTORE_MAX_FILE_SIZE: NA
2011-03-13 15:29:55 -- debug:
2011-03-13 15:29:55 -- info: Snapshot found for vMA, backup will not take place

2011-03-13 15:29:57 -- debug: Storage Information before backup:
2011-03-13 15:29:57 -- debug: SRC_DATASTORE: himalaya-local-SATA.RE4-GP:Storage
2011-03-13 15:29:57 -- debug: SRC_DATASTORE_CAPACITY: 1830.5 GB
2011-03-13 15:29:57 -- debug: SRC_DATASTORE_FREE: 539.4 GB
2011-03-13 15:29:57 -- debug: SRC_DATASTORE_BLOCKSIZE: 4
2011-03-13 15:29:57 -- debug: SRC_DATASTORE_MAX_FILE_SIZE: 1024 GB
2011-03-13 15:29:57 -- debug:
2011-03-13 15:29:57 -- debug: DST_DATASTORE: dlgCore-NFS-bigboi.VM-Backups
2011-03-13 15:29:57 -- debug: DST_DATASTORE_CAPACITY: 1348.4 GB
2011-03-13 15:29:57 -- debug: DST_DATASTORE_FREE: 296.8 GB
2011-03-13 15:29:57 -- debug: DST_DATASTORE_BLOCKSIZE: NA
2011-03-13 15:29:57 -- debug: DST_DATASTORE_MAX_FILE_SIZE: NA
2011-03-13 15:29:57 -- debug:
2011-03-13 15:29:58 -- info: Initiate backup for vCloudConnector
2011-03-13 15:29:58 -- debug: /usr/sbin/vmkfstools -i "/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/vCloudConnector/vCloudConnector.vmdk" -a "buslogic" -d "thin" "/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS/vCloudConnector/vCloudConnector-2011-03-13_15-27-59/vCloudConnector.vmdk"
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/vCloudConnector/vCloudConnector.vmdk'...
Clone: 97% done.
2011-03-13 15:30:45 -- info: Backup Duration: 47 Seconds
2011-03-13 15:30:45 -- info: WARN: vCloudConnector has some Independent VMDKs that can not be backed up!

2011-03-13 15:30:45 -- info: ###### Final status: ERROR: Only some of the VMs backed up, and some disk(s) failed! ######

2011-03-13 15:30:45 -- debug: Succesfully removed lock directory - /tmp/ghettoVCB.lock

2011-03-13 15:30:45 -- info: ============================== ghettoVCB LOG END ================================
```

### Backup VMs stored in a list

```console
[root@himalaya ~]# /opt/ghettovcb/bin/ghettoVCB.sh -f vms_to_backup
```

### Backup Single VM using CLI
```console
[root@himalaya ~]# /opt/ghettovcb/bin/ghettoVCB.sh -m MyVM
```

### Backup All VMs residing on specific host
```console
[root@himalaya ~]# /opt/ghettovcb/bin/ghettoVCB.sh -a
```

### Backup All VMs residing on specific host and exclude the VMs in the exclusion list
```console
[root@himalaya ~]# /opt/ghettovcb/bin/ghettoVCB.sh -a -e vm_exclusion_list
```

### Backup VMs based on individual VM backup policies

* Log verbosity: info (default)
* Log output: /tmp/ghettoVCB.log
 * Logs by default will be stored in /tmp, these log files may not persist through reboots, especially when dealing with ESXi. You should log to  either a local or remote datastore to ensure that logs are kept upon a  reboot.

1. Create folder to hold individual VM backup policies (can be named anything):
```console
[root@himalaya ~]# mkdir backup_config
```

2. Create individual VM backup policies for each VM that ensure each  file is named exactly as the display name of the VM being backed up (use  provided template to create duplicates):
```console
[root@himalaya]# cp /opt/ghettovcb/ghettoVCB-vm_backup_configuration_template scofield
[root@himalaya]# cp /opt/ghettovcb/ghettoVCB-vm_backup_configuration_template vCloudConnector
```

Listing of VM backup policy within backup configuration directory
```console
[root@himalaya backup_config]# ls
ghettoVCB-vm_backup_configuration_template  scofield  vCloudConnector
```

Backup policy for "scofield" (backup only 2 specific VMDKs)
```console
[root@himalaya backup_config]# cat scofield
VM_BACKUP_VOLUME=/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS
DISK_BACKUP_FORMAT=thin
VM_BACKUP_ROTATION_COUNT=3
POWER_VM_DOWN_BEFORE_BACKUP=0
ENABLE_HARD_POWER_OFF=0
ITER_TO_WAIT_SHUTDOWN=4
POWER_DOWN_TIMEOUT=5
SNAPSHOT_TIMEOUT=15
ENABLE_COMPRESSION=0
VM_SNAPSHOT_MEMORY=0
VM_SNAPSHOT_QUIESCE=0
VMDK_FILES_TO_BACKUP="scofield_2.vmdk,scofield_1.vmdk"
```

Backup policy for VM "vCloudConnector" (backup all VMDKs found)
```console
[root@himalaya backup_config]# cat vCloudConnector
VM_BACKUP_VOLUME=/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS
DISK_BACKUP_FORMAT=thin
VM_BACKUP_ROTATION_COUNT=3
POWER_VM_DOWN_BEFORE_BACKUP=0
ENABLE_HARD_POWER_OFF=0
ITER_TO_WAIT_SHUTDOWN=4
POWER_DOWN_TIMEOUT=5
SNAPSHOT_TIMEOUT=15
ENABLE_COMPRESSION=0
VM_SNAPSHOT_MEMORY=0
VM_SNAPSHOT_QUIESCE=0
VMDK_FILES_TO_BACKUP="vCloudConnector.vmdk"
```

> **Note:** When specifying -c option (individual VM backup policy mode) if a VM is listed in the backup list but DOES NOT have a corresponding backup policy, the VM will be backed up using the default configuration found within the ghettoVCB.sh script.

Execution of backup
```console
[root@himalaya ~]# /opt/ghettovcb/bin/ghettoVCB.sh -f vms_to_backup -c backup_config -l /tmp/ghettoVCB.log

2011-03-13 15:40:50 -- info: ============================== ghettoVCB LOG START ==============================

2011-03-13 15:40:51 -- info: CONFIG - USING CONFIGURATION FILE = backup_config//scofield
2011-03-13 15:40:51 -- info: CONFIG - VERSION = 2011_03_13_1
2011-03-13 15:40:51 -- info: CONFIG - GHETTOVCB_PID = 2967
2011-03-13 15:40:51 -- info: CONFIG - VM_BACKUP_VOLUME = /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS
2011-03-13 15:40:51 -- info: CONFIG - VM_BACKUP_ROTATION_COUNT = 3
2011-03-13 15:40:51 -- info: CONFIG - VM_BACKUP_DIR_NAMING_CONVENTION = 2011-03-13_15-40-50
2011-03-13 15:40:51 -- info: CONFIG - DISK_BACKUP_FORMAT = thin
2011-03-13 15:40:51 -- info: CONFIG - POWER_VM_DOWN_BEFORE_BACKUP = 0
2011-03-13 15:40:51 -- info: CONFIG - ENABLE_HARD_POWER_OFF = 0
2011-03-13 15:40:51 -- info: CONFIG - ITER_TO_WAIT_SHUTDOWN = 4
2011-03-13 15:40:51 -- info: CONFIG - POWER_DOWN_TIMEOUT = 5
2011-03-13 15:40:51 -- info: CONFIG - SNAPSHOT_TIMEOUT = 15
2011-03-13 15:40:51 -- info: CONFIG - LOG_LEVEL = info
2011-03-13 15:40:51 -- info: CONFIG - BACKUP_LOG_OUTPUT = /tmp/ghettoVCB.log
2011-03-13 15:40:51 -- info: CONFIG - VM_SNAPSHOT_MEMORY = 0
2011-03-13 15:40:51 -- info: CONFIG - VM_SNAPSHOT_QUIESCE = 0
2011-03-13 15:40:51 -- info: CONFIG - VMDK_FILES_TO_BACKUP = scofield_2.vmdk,scofield_1.vmdk
2011-03-13 15:40:51 -- info: CONFIG - EMAIL_LOG = 0
2011-03-13 15:40:51 -- info:
2011-03-13 15:40:53 -- info: Initiate backup for scofield
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield_2.vmdk'...
Clone: 100% done.

Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/scofield/scofield_1.vmdk'...
Clone: 100% done.

2011-03-13 15:40:55 -- info: Backup Duration: 2 Seconds
2011-03-13 15:40:55 -- info: Successfully completed backup for scofield!

2011-03-13 15:40:57 -- info: CONFIG - VERSION = 2011_03_13_1
2011-03-13 15:40:57 -- info: CONFIG - GHETTOVCB_PID = 2967
2011-03-13 15:40:57 -- info: CONFIG - VM_BACKUP_VOLUME = /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS
2011-03-13 15:40:57 -- info: CONFIG - VM_BACKUP_ROTATION_COUNT = 3
2011-03-13 15:40:57 -- info: CONFIG - VM_BACKUP_DIR_NAMING_CONVENTION = 2011-03-13_15-40-50
2011-03-13 15:40:57 -- info: CONFIG - DISK_BACKUP_FORMAT = thin
2011-03-13 15:40:57 -- info: CONFIG - POWER_VM_DOWN_BEFORE_BACKUP = 0
2011-03-13 15:40:57 -- info: CONFIG - ENABLE_HARD_POWER_OFF = 0
2011-03-13 15:40:57 -- info: CONFIG - ITER_TO_WAIT_SHUTDOWN = 3
2011-03-13 15:40:57 -- info: CONFIG - POWER_DOWN_TIMEOUT = 5
2011-03-13 15:40:57 -- info: CONFIG - SNAPSHOT_TIMEOUT = 15
2011-03-13 15:40:57 -- info: CONFIG - LOG_LEVEL = info
2011-03-13 15:40:57 -- info: CONFIG - BACKUP_LOG_OUTPUT = /tmp/ghettoVCB.log
2011-03-13 15:40:57 -- info: CONFIG - VM_SNAPSHOT_MEMORY = 0
2011-03-13 15:40:57 -- info: CONFIG - VM_SNAPSHOT_QUIESCE = 0
2011-03-13 15:40:57 -- info: CONFIG - VMDK_FILES_TO_BACKUP = all
2011-03-13 15:40:57 -- info: CONFIG - EMAIL_LOG = 0
2011-03-13 15:40:57 -- info:
2011-03-13 15:40:59 -- info: Snapshot found for vMA, backup will not take place

2011-03-13 15:40:59 -- info: CONFIG - USING CONFIGURATION FILE = backup_config//vCloudConnector
2011-03-13 15:40:59 -- info: CONFIG - VERSION = 2011_03_13_1
2011-03-13 15:40:59 -- info: CONFIG - GHETTOVCB_PID = 2967
2011-03-13 15:40:59 -- info: CONFIG - VM_BACKUP_VOLUME = /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS
2011-03-13 15:40:59 -- info: CONFIG - VM_BACKUP_ROTATION_COUNT = 3
2011-03-13 15:40:59 -- info: CONFIG - VM_BACKUP_DIR_NAMING_CONVENTION = 2011-03-13_15-40-50
2011-03-13 15:40:59 -- info: CONFIG - DISK_BACKUP_FORMAT = thin
2011-03-13 15:40:59 -- info: CONFIG - POWER_VM_DOWN_BEFORE_BACKUP = 0
2011-03-13 15:40:59 -- info: CONFIG - ENABLE_HARD_POWER_OFF = 0
2011-03-13 15:40:59 -- info: CONFIG - ITER_TO_WAIT_SHUTDOWN = 4
2011-03-13 15:40:59 -- info: CONFIG - POWER_DOWN_TIMEOUT = 5
2011-03-13 15:40:59 -- info: CONFIG - SNAPSHOT_TIMEOUT = 15
2011-03-13 15:40:59 -- info: CONFIG - LOG_LEVEL = info
2011-03-13 15:40:59 -- info: CONFIG - BACKUP_LOG_OUTPUT = /tmp/ghettoVCB.log
2011-03-13 15:40:59 -- info: CONFIG - VM_SNAPSHOT_MEMORY = 0
2011-03-13 15:40:59 -- info: CONFIG - VM_SNAPSHOT_QUIESCE = 0
2011-03-13 15:40:59 -- info: CONFIG - VMDK_FILES_TO_BACKUP = vCloudConnector.vmdk
2011-03-13 15:40:59 -- info: CONFIG - EMAIL_LOG = 0
2011-03-13 15:40:59 -- info:
2011-03-13 15:41:01 -- info: Initiate backup for vCloudConnector
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage/vCloudConnector/vCloudConnector.vmdk'...
Clone: 100% done.

2011-03-13 15:41:51 -- info: Backup Duration: 50 Seconds
2011-03-13 15:41:51 -- info: WARN: vCloudConnector has some Independent VMDKs that can not be backed up!

2011-03-13 15:41:51 -- info: ###### Final status: ERROR: Only some of the VMs backed up, and some disk(s) failed! ######

2011-03-13 15:41:51 -- info: ============================== ghettoVCB LOG END ================================
```
## Enable compression for backups

To make use of this feature, modify the variable ENABLE_COMPRESSION from 0 to 1. Please note, do not mix uncompressed backups with  compressed backups. Ensure that directories selected for backups do not contain any backups with previous versions of ghettoVCB before enabling  and implementing the compressed backups feature.

## Stopping ghettoVCB Process

There may be a situation where you need to stop the ghettoVCB process and entering Ctrl+C will only kill off the main ghettoVCB process, however there may still be other spawn processes that you may need to identify and stop. Below are two scenarios you may encounter and the process to completely stop all processes related to ghettoVCB.

**Interactively running ghettoVCB:**

Step 1 - Press Ctrl+C which will kill off the main ghettoVCB instance

Step 2 - Search for any existing ghettoVCB process by running the following:
```console
# ps -c | grep ghettoVCB | grep -v grep
3360136 3360136 tail                 tail -f /tmp/ghettoVCB.work/ghettovcb.Cs1M1x
```

Step 3 - Here we can see there is a tail command that was used in the script. We need to stop this process by using the kill command which accepts the PID (Process ID) which is identified by the first value on the far left hand side of the command. In this example, it is 3360136.
```console
# kill -9 3360136
```

> **Note:** Make sure you identify the correct PID, else you could accidently impact a running VM or worse your ESXi host.

Step 4 - Depending on where you stopped the ghettoVCB process, you may need to consolidate or remove any existing snapshots that may exist on the VM that was being backed up. You can easily do so by using the vSphere Client.

**Non-Interactively running ghettoVCB:**

Step 1 - Search for the ghettoVCB process (you can also validate the PID from the logs)
```console
~ # ps -c | grep ghettoVCB | grep -v grep
3360393 3360393 busybox              ash ./ghettoVCB.sh -f list -d debug
3360790 3360790 tail                 tail -f /tmp/ghettoVCB.work/ghettovcb.deGeB7
```

Step 2 - Stop both the main ghettoVCB instance & tail command by using the kill command and specifying their respective PID IDs:
```console
kill -9 3360393
kill -9 3360790
```

Step 3 - If a VM was in the process of being backed up, there is an additional process for the actual vmkfstools copy. You will need to identify the process for that and kill that as well. We will again use ps -c command and search for any vmkfstools that are running:
```console
# ps -c | grep vmkfstools | grep -v grep
3360796 3360796 vmkfstools           /sbin/vmkfstools -i /vmfs/volumes/himalaya-temporary/VC-Windows/VC-Windows.vmdk -a lsilogic -d thin /vmfs/volumes/test-dont-use-this-volume/backups/VC-Windows/VC-Windows-2013-01-26_16-45-35/VC-Windows.vmdk
```

Step 4 - In case there is someone manually running a vmkfstools, make sure you take a look at the command itself and that it maps back to the current VM that was being backed up before kill the process. Once you have identified the proper PID, go ahead and use the kill command:
```console
# kill -9 3360796
```

Step 5 - Depending on where you stopped the  ghettoVCB process, you may need to consolidate or remove any existing  snapshots that may exist on the VM that was being backed up. You can  easily do so by using the vSphere Client.

## Scheduling Backups using Cron

First, please review this [primer on what is cronjob](https://web.archive.org/web/20231110163544/http://www.cyberciti.biz/faq/how-do-i-add-jobs-to-cron-under-linux-or-unix-oses/)

The task of configuring cronjobs on classic ESX servers (with Service Console) is no different than traditional cronjobs on *nix operating  systems (this procedure is outlined in the link above). With ESXi on the  other hand, additional factors need to be taken into account when  setting up cronjobs in the limited shell console called Busybox because changes made do not persist through a system reboot. The following document will outline steps to ensure that cronjob configurations are saved and present upon a reboot.

> **Note:** Always redirect the ghettoVCB output to /dev/null and/or to a log when automating via cron, this becomes very important as one user has identified a limited amount of buffer capacity in which once filled, may cause ghettoVCB to stop in the middle of a backup. This primarily only affects users on ESXi, but it is good practice to always redirect the output. Also ensure you are specifying the FULL PATH when referencing the ghettoVCB script, input or log files.

e.g.
```console
0 0 * * 1-5 /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/ghettoVCB.sh -f /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/backuplist > /dev/null
```
or

```copnsole
0 0 * * 1-5 /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/ghettoVCB.sh -f /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/backuplist > /tmp/ghettoVCB.log
```

Example - Configure ghettoVCB.sh to execute a backup five days a week (M-F) at 12AM (midnight) everyday and send output to a unique log file


### Configure on ESX:

1. As root, you'll install your cronjob by issuing:
```console
[root@himalaya ~]# crontab -e
```

2. Append the following entry:
```console
0 0 * * 1-5 /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/ghettoVCB.sh -f /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/backuplist > /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/ghettoVCB-backup-$(date +\%s).log
```

3. Save and exit
```console
[root@himalaya dlgCore-NFS-bigboi.VM-Backups]# crontab -e
no crontab for root - using an empty one
crontab: installing new crontab
```

4. List out and verify the cronjob that was just created:
```console
[root@himalaya dlgCore-NFS-bigboi.VM-Backups]# crontab -l
0 0 * * 1-5 /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/ghettoVCB.sh -f /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/backuplist > /vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/ghettoVCB-backup-$(date +\%s).log
```

### Configure on ESXi:

1. Setup the cronjob by appending the following line to `/var/spool/cron/crontabs/root`:
```console
0 0 * * 1-5 /vmfs/volumes/simplejack-local-storage/ghettoVCB.sh -f /vmfs/volumes/simplejack-local-storage/backuplist > /vmfs/volumes/simplejack-local-storage/ghettoVCB-backup-$(date +\%s).log
```

If you are unable to edit/modify `/var/spool/cron/crontabs/root`, please make a copy and then edit the copy with the changes
```console
cp /var/spool/cron/crontabs/root /var/spool/cron/crontabs/root.backup
```
Once your changes have been made, then "mv" the backup to the original file. This may occur on ESXi 4.x or 5.x hosts
```console
mv /var/spool/cron/crontabs/root.backup /var/spool/cron/crontabs/root
```
You can now verify the crontab entry has been updated by using "cat" utility.


2. Kill the current crond (cron daemon) and then restart the crond for the changes to take affect:

On ESXi < 3.5u3
```console
kill $(ps | grep crond | cut -f 1 -d ' ')
```

On ESXi 3.5u3+
```console
~ # kill $(pidof crond)
~ # crond
```

On ESXi 4.x/5.0
```console
~ # kill $(cat /var/run/crond.pid)
~ # busybox crond
```

On ESXi 5.1 to 6.x
```console
~ # kill $(cat /var/run/crond.pid)
~ # crond
```

On ESXi 7.x
```console
~ # kill $(cat /var/run/crond.pid)
~ # /usr/lib/vmware/busybox/bin/busybox crond
```

3. Now that the cronjob is ready to go, you need to ensure that this  cronjob will persist through a reboot. You'll need to add the following two lines to /etc/rc.local (ensure that the cron entry matches what was defined above). In ESXi 5.1, you will need to edit /etc/rc.local.d/local.sh instead of /etc/rc.local as that is no longer valid.

On ESXi 3.5
```console
/bin/kill $(pidof crond)
/bin/echo "0 0 * * 1-5 /vmfs/volumes/simplejack-local-storage/ghettoVCB.sh -f /vmfs/volumes/simplejack-local-storage/backuplist > /vmfs/volumes/simplejack-local-storage/ghettoVCB-backup-\$(date +\\%s).log" >> /var/spool/cron/crontabs/root
crond
```

On ESXi 4.x/5.0
```console
/bin/kill $(cat /var/run/crond.pid)
/bin/echo "0 0 * * 1-5 /vmfs/volumes/simplejack-local-storage/ghettoVCB.sh -f /vmfs/volumes/simplejack-local-storage/backuplist > /vmfs/volumes/simplejack-local-storage/ghettoVCB-backup-\$(date +\\%s).log" >> /var/spool/cron/crontabs/root
/bin/busybox crond
```

On ESXi 5.1 to 6.x
```console
/bin/kill $(cat /var/run/crond.pid)
/bin/echo "0 0 * * 1-5 /vmfs/volumes/simplejack-local-storage/ghettoVCB.sh -f /vmfs/volumes/simplejack-local-storage/backuplist > /vmfs/volumes/simplejack-local-storage/ghettoVCB-backup-\$(date +\\%s).log" >> /var/spool/cron/crontabs/root
crond
```

On ESXi 7.x and later
```console
/bin/kill $(cat /var/run/crond.pid) > /dev/null 2>&1
/bin/echo "0 0 * * 1-5 /vmfs/volumes/simplejack-local-storage/ghettoVCB.sh -f /vmfs/volumes/simplejack-local-storage/backuplist > /vmfs/volumes/simplejack-local-storage/ghettoVCB-backup-\$(date +\\%s).log" >> /var/spool/cron/crontabs/root
/usr/lib/vmware/busybox/bin/busybox crond
```

Afterwards the file should look like the following:
```console
~ # cat /etc/rc.local
#! /bin/ash
export PATH=/sbin:/bin

log() {
   echo "$1"
   logger init "$1"
}

#execute all service retgistered in /etc/rc.local.d
if [http:// -d /etc/rc.local.d |http:// -d /etc/rc.local.d ]; then
   for filename in `find /etc/rc.local.d/ | sort`
      do
         if [ -f $filename ] && [ -x $filename ]; then
            log "running $filename"
            $filename
         fi
      done
fi

/bin/kill $(cat /var/run/crond.pid)
/bin/echo "0 0 * * 1-5 /vmfs/volumes/simplejack-local-storage/ghettoVCB.sh -f /vmfs/volumes/simplejack-local-storage/backuplist > /vmfs/volumes/simplejack-local-storage/ghettoVCB-backup-\$(date +\\%s).log" >> /var/spool/cron/crontabs/root
/bin/busybox crond
```

This will ensure that the cronjob is re-created upon a reboot of the system through a startup script

2. To ensure that this is saved in the ESXi configuration, we need to manually initiate an ESXi backup by running:
```console
~ # /sbin/auto-backup.sh
config implicitly loaded
local.tgz
etc/vmware/vmkiscsid/vmkiscsid.db
etc/dropbear/dropbear_dss_host_key
etc/dropbear/dropbear_rsa_host_key
etc/opt/vmware/vpxa/vpxa.cfg
etc/opt/vmware/vpxa/dasConfig.xml
etc/sysconfig/network
etc/vmware/hostd/authorization.xml
etc/vmware/hostd/hostsvc.xml
etc/vmware/hostd/pools.xml
etc/vmware/hostd/vmAutoStart.xml
etc/vmware/hostd/vmInventory.xml
etc/vmware/hostd/proxy.xml
etc/vmware/ssl/rui.crt
etc/vmware/ssl/rui.key
etc/vmware/vmkiscsid/initiatorname.iscsi
etc/vmware/vmkiscsid/iscsid.conf
etc/vmware/vmware.lic
etc/vmware/config
etc/vmware/dvsdata.db
etc/vmware/esx.conf
etc/vmware/license.cfg
etc/vmware/locker.conf
etc/vmware/snmp.xml
etc/group
etc/hosts
etc/inetd.conf
etc/rc.local
etc/chkconfig.db
etc/ntp.conf
etc/passwd
etc/random-seed
etc/resolv.conf
etc/shadow
etc/sfcb/repository/root/interop/cim_indicationfilter.idx
etc/sfcb/repository/root/interop/cim_indicationhandlercimxml.idx
etc/sfcb/repository/root/interop/cim_listenerdestinationcimxml.idx
etc/sfcb/repository/root/interop/cim_indicationsubscription.idx
Binary files /etc/vmware/dvsdata.db and /tmp/auto-backup.31345.dir/etc/vmware/dvsdata.db differ
config implicitly loaded
Saving current state in /bootbank
Clock updated.
Time: 20:40:36   Date: 08/14/2009   UTC
```

Now you're really done!

If you're still having trouble getting the cronjob to work, ensure that  you've specified the correct parameters and there aren’t any typos in  any part of the syntax.

Ensure crond (cron daemon) is running:

ESX 3.x/4.0:
```console
[root@himalaya dlgCore-NFS-bigboi.VM-Backups]# ps -ef | grep crond | grep -v grep
root      2625     1  0 Aug13 ?        00:00:00 crond
```

ESXi 3.x/4.x/5.x:
```console
~ # ps | grep crond | grep -v grep
5196 5196 busybox              crond
```

Ensure that the date/time on your ESX(i) host is setup correctly:

ESX(i):
```console
[root@himalaya dlgCore-NFS-bigboi.VM-Backups]# date
Fri Aug 14 23:44:47 PDT 2009
```

Note: Careful attention must be noted if more than one backup is performed per day. Backup windows  should be staggered to avoid contention or saturation of resources  during these periods.

## Restore Backups

The [ghettoVCB-restore.sh]() script performs a restore of virtual machines backed up using ghettoVCB. Tasks are performed directly within the service console of the ESX(i) server involved in the restore process. Two main use cases are supported:

1) Restore a VM that contains ALL VMDKs on one datastore
2) Restore a VM that has VMDKs located on multiple datastores

In all cases, restored VMs will have VMDKs that reside on the SAME  datastore chosen for the restore process. Please ensure that there is  sufficient space on the target datastore before attempting a restore  operation. In the near future, restoration of VMs backed up using the compression feature of ghettoVCB will be implemented.

Features
* Support for logging output
* Support for various debugging output
* Allow spaces in VM(s) backup list (not recommended and not a best practice)
* Support for restore in the following formats: ZEROEDTHICK (default behavior), 2GB SPARSE, THIN or EAGERZEROEDTHICK
* Support changing custom VM name during restore

### Usage

```console
[root@himalaya ~]# /opt/ghettovcb/bin/ghettoVCB-restore.sh
###############################################################################
#
# ghettoVCB-restore for ESX/ESXi 3.5, 4.x and 5.x
# Author: William Lam
# http://www.virtuallyghetto.com/
# Created: 08/18/2009
# Last modified: 2011_11_19_1
#
###############################################################################

Usage: ./ghettoVCB-restore.sh -c [VM_BACKUP_UP_LIST] -l [LOG_FILE] -d [DRYRUN_DEBUG_INFO]

OPTIONS:
   -c     VM backup list
   -l     File ot output logging
   -d     Dryrun/Debug Info [1|2]

(e.g.)

Output will go to stdout
        ./ghettoVCB-restore.sh -c vms_to_restore

Output will log to /tmp/ghettoVCB-restore.log
        ./ghettoVCB-restore.sh -c vms_to_restore -l /tmp/ghettoVCB-restore.log

Dryrun/Debug Info (dryrun only)
        ./ghettoVCB-restore.sh -c vms_to_restore -d 1
        ./ghettoVCB-restore.sh -c vms_to_restore -d 2
```

Standard input for script is a file that contains:

1) Full path to the backed up VM
2) Full restore path
3) Restoration disk format
4) Restored VM Display Name (NEW!)

Reminder: When creating this file on a non-Linux/UNIX system, one may  introduce ^M characters that will cause the script to misbehave. To  ensure that this does not occur, please create the file on the ESX/ESXi  host.

Here is a sample of what the file should look like:
```console
[root@himalaya ~]# cat vms_to_restore
#"<DIRECTORY or .TGZ>;<DATASTORE_TO_RESTORE_TO>;<DISK_FORMAT_TO_RESTORE>;<OPTIONAL_RESTORED_VM_DISPLAY_NAME>"
# DISK_FORMATS
# 1 = zeroedthick
# 2 = 2gbsparse
# 3 = thin
# 4 = eagerzeroedthick
# e.g.
# "/vmfs/volumes/dlgCore-NFS-bigboi.VM-Backups/WILLIAM_BACKUPS/VCAP/VCAP-2009-08-18--1;/vmfs/volumes/himalaya-local-SATA.RE4-GP:Storage;1"
"/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36;/vmfs/volumes/mini-local-datastore-1;3"
"/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36;/vmfs/volumes/mini-local-datastore-1;1;VCSA-RESTORE"
```

Comments in the input file is acceptable so long as the intended line is preceded by a #.

The above sample VM restore file, vms_to_restore, describes the following backup:
| VM to restore                                                                      | Datastore to restore to              | VMDK format | Restore VM Name |
|------------------------------------------------------------------------------------|--------------------------------------|-------------|-----------------|
| /vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36 | /vmfs/volumes/mini-local-datastore-1 | thin        | VCSA-5.1        |
| /vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36 | /vmfs/volumes/mini-local-datastore-1 | zeroedthick | VCSA-RESTORE    |

### Sample Execution:
Perform a dryrun by displaying debug information ( restore will not take place)

Display debug information level 1:
```console
# /opt/ghettovcb/bin/ghettoVCB-restore.sh -c vms_to_restore -d 1

################ DEBUG MODE ##############
Virtual Machine: "VCSA-5.1"
VM_ORIG_VMX: "VCSA-5.1.vmx"
VM_ORG_FOLDER: "VCSA-5.1-2012-12-25_01-30-36"
VM_RESTORE_VMX: "VCSA-5.1.vmx"
VM_RESTORE_FOLDER: "VCSA-5.1"
VMDK_LIST_TO_MODIFY:
scsi0:0.fileName = "VCSA-5.1.vmdk"
scsi0:0.fileName  = "VCSA-5.1-0.vmdk"
scsi0:1.fileName = "VCSA-5.1_1.vmdk"
scsi0:1.fileName  = "VCSA-5.1-1.vmdk"
##########################################


################ DEBUG MODE ##############
Virtual Machine: "VCSA-RESTORE"
VM_ORIG_VMX: "VCSA-5.1.vmx"
VM_ORG_FOLDER: "VCSA-5.1-2012-12-25_01-30-36"
VM_RESTORE_VMX: "VCSA-RESTORE.vmx"
VM_RESTORE_FOLDER: "VCSA-RESTORE"
VMDK_LIST_TO_MODIFY:
scsi0:0.fileName = "VCSA-5.1.vmdk"
scsi0:0.fileName  = "VCSA-RESTORE-0.vmdk"
scsi0:1.fileName = "VCSA-5.1_1.vmdk"
scsi0:1.fileName  = "VCSA-RESTORE-1.vmdk"
##########################################


Start time: Sun Jan 13 16:45:12 UTC 2013
End   time: Sun Jan 13 16:45:14 UTC 2013
Duration  : 2 Seconds
```

Display debug information level 2:
```console
[root@himalaya ~]# /opt/ghettovcb/bin/ghettoVCB-restore.sh -c vms_to_restore -d 2


################## Restoring VM: VCSA-5.1  #####################
==========> DEBUG MODE LEVEL 2 ENABLED <==========
Start time: Sun Jan 13 16:45:35 UTC 2013
Restoring VM from: "/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36"
Restoring VM to Datastore: "/vmfs/volumes/mini-local-datastore-1" using Disk Format: "thin"
Creating VM directory: "/vmfs/volumes/mini-local-datastore-1/VCSA-5.1" ...
Copying "VCSA-5.1.vmx" file ...
Restoring VM's VMDK(s) ...
Updating VMDK entry in "VCSA-5.1.vmx" file ...

SOURCE: "/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36/VCSA-5.1.vmdk"
    ORIGINAL_VMX_LINE: -->scsi0:0.fileName = "VCSA-5.1.vmdk"<--
DESTINATION: "/vmfs/volumes/mini-local-datastore-1/VCSA-5.1/VCSA-5.1-0.vmdk"
    MODIFIED_VMX_LINE: -->scsi0:0.fileName  = "VCSA-5.1-0.vmdk"<--
Updating VMDK entry in "VCSA-5.1.vmx" file ...

SOURCE: "/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36/VCSA-5.1_1.vmdk"
    ORIGINAL_VMX_LINE: -->scsi0:1.fileName = "VCSA-5.1_1.vmdk"<--
DESTINATION: "/vmfs/volumes/mini-local-datastore-1/VCSA-5.1/VCSA-5.1-1.vmdk"
    MODIFIED_VMX_LINE: -->scsi0:1.fileName  = "VCSA-5.1-1.vmdk"<--
Registering VCSA-5.1 ...
End time: Sun Jan 13 16:45:35 UTC 2013
################## Completed restore for VCSA-5.1! #####################

################## Restoring VM: VCSA-RESTORE  #####################
==========> DEBUG MODE LEVEL 2 ENABLED <==========
Start time: Sun Jan 13 16:45:35 UTC 2013
Restoring VM from: "/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36"
Restoring VM to Datastore: "/vmfs/volumes/mini-local-datastore-1" using Disk Format: "zeroedthick"
Creating VM directory: "/vmfs/volumes/mini-local-datastore-1/VCSA-RESTORE" ...
Copying "VCSA-5.1.vmx" file ...
Restoring VM's VMDK(s) ...
Updating VMDK entry in "VCSA-RESTORE.vmx" file ...

SOURCE: "/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36/VCSA-5.1.vmdk"
    ORIGINAL_VMX_LINE: -->scsi0:0.fileName = "VCSA-5.1.vmdk"<--
DESTINATION: "/vmfs/volumes/mini-local-datastore-1/VCSA-RESTORE/VCSA-RESTORE-0.vmdk"
    MODIFIED_VMX_LINE: -->scsi0:0.fileName  = "VCSA-RESTORE-0.vmdk"<--
Updating VMDK entry in "VCSA-RESTORE.vmx" file ...

SOURCE: "/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36/VCSA-5.1_1.vmdk"
    ORIGINAL_VMX_LINE: -->scsi0:1.fileName = "VCSA-5.1_1.vmdk"<--
DESTINATION: "/vmfs/volumes/mini-local-datastore-1/VCSA-RESTORE/VCSA-RESTORE-1.vmdk"
    MODIFIED_VMX_LINE: -->scsi0:1.fileName  = "VCSA-RESTORE-1.vmdk"<--
Registering VCSA-RESTORE ...
End time: Sun Jan 13 16:45:35 UTC 2013
################## Completed restore for VCSA-RESTORE! #####################


Start time: Sun Jan 13 16:45:34 UTC 2013
End   time: Sun Jan 13 16:45:35 UTC 2013
Duration  : 1 Seconds

---------------------------------------------------------------------------------------------------------------
```

Execute restore with output going to stdout (restore the first two VMs listed from above):

Input file:
```console
[root@himalaya ~]# cat vms_to_restore

"/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36;/vmfs/volumes/mini-local-datastore-1;3"
"/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36;/vmfs/volumes/mini-local-datastore-1;1;VCSA-RESTORE"
```

```console
[root@himalaya ~]# /opt/ghettovcb/bin/ghettoVCB-restore.sh -c vms_to_restore

################## Restoring VM: VCSA-5.1  #####################
Start time: Sun Jan 13 16:46:41 UTC 2013
Restoring VM from: "/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36"
Restoring VM to Datastore: "/vmfs/volumes/mini-local-datastore-1" using Disk Format: "thin"
Creating VM directory: "/vmfs/volumes/mini-local-datastore-1/VCSA-5.1" ...
Copying "VCSA-5.1.vmx" file ...
Restoring VM's VMDK(s) ...
Updating VMDK entry in "VCSA-5.1.vmx" file ...
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36/VCSA-5.1.vmdk'...
Clone: 100% done.
Updating VMDK entry in "VCSA-5.1.vmx" file ...
Destination disk format: VMFS thin-provisioned
Cloning disk '/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36/VCSA-5.1_1.vmdk'...
Clone: 100% done.
Registering VCSA-5.1 ...
34
End time: Sun Jan 13 16:48:51 UTC 2013
################## Completed restore for VCSA-5.1! #####################

################## Restoring VM: VCSA-RESTORE  #####################
Start time: Sun Jan 13 16:48:52 UTC 2013
Restoring VM from: "/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36"
Restoring VM to Datastore: "/vmfs/volumes/mini-local-datastore-1" using Disk Format: "zeroedthick"
Creating VM directory: "/vmfs/volumes/mini-local-datastore-1/VCSA-RESTORE" ...
Copying "VCSA-5.1.vmx" file ...
Restoring VM's VMDK(s) ...
Updating VMDK entry in "VCSA-RESTORE.vmx" file ...
Destination disk format: VMFS zeroedthick
Cloning disk '/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36/VCSA-5.1.vmdk'...
Clone: 100% done.
Updating VMDK entry in "VCSA-RESTORE.vmx" file ...
Failed to clone disk: There is not enough space on the file system for the selected operation (13).
Destination disk format: VMFS zeroedthick
Cloning disk '/vmfs/volumes/mini-local-datastore-2/backups/VCSA-5.1/VCSA-5.1-2012-12-25_01-30-36/VCSA-5.1_1.vmdk'...
Registering VCSA-RESTORE ...
35
End time: Sun Jan 13 16:50:19 UTC 2013
################## Completed restore for VCSA-RESTORE! #####################


Start time: Sun Jan 13 16:46:40 UTC 2013
End   time: Sun Jan 13 16:50:19 UTC 2013
Duration  : 3.65 Minutes


---------------------------------------------------------------------------------------------------------------
```

Execute restore with output going to log file

/tmp/ghettoVCB-restore.log (restore the last two VMs listed from above):
```console
[root@himalaya ~]# ./ghettoVCB-restore.sh -c vms_to_restore -l /tmp/ghettoVCB-restore.log
Logging output to "/tmp/ghettoVCB-restore.log" ...
```
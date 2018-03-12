# Author: Mart Verburg
# http://datamind.no
# Created Date: 2015-04-14
# published on GitHub.com in Datamind fork Datamind-dot-no/da-ghettoVCB 
# forked from lamw/ghettoVCB
##
# ghettoVCB-backup-crontab-setup.sh
# Purpose: setup ghettoVCB cron schaduling functionality and persistance 
# across ESXi restarts
# appends the ghettoVCB to the busybox bootstrap local init script
# will hardcode the SCRIPTPATH in the crontab-init script that is called from init.d

# Where we want the logs sent
LOGDIR=/vmfs/volumes/datastore1/log

# which file contains the custom ghettoVCB cronjobs
GHETTOCRONFILE=ghettoVCB-backup-crontab-entries.txt

INITDSCRIPT=/etc/rc.local.d/local.sh 

##
## No need to edit anything below here 
## -- unless you think you're more of a hacker like me ;-)
##

# Establish path to ghettoVCB dir
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

## hardcode the scriptpath into the crontab entries file
#   use a sed in-place search and replace inside the file, 
#   use % as delimiter to avoid the slash in the path,
#   match the path starting from leading / to the scriptname, 
#   and replace with the new path :-|)
sed -i "s%/.*ghettoVCB-backup-wrap.sh%$SCRIPTPATH/ghettoVCB-backup-wrap.sh%g" $SCRIPTPATH/$GHETTOCRONFILE

## Append the init.sh script to the InitD bootstrap routine for ESXi
# strip any ghettoVCB lines that may be in place beforehand
sed -i '/ghettoVCB/d' $INITDSCRIPT

## put line for our ghettoVCB crontab init shellscript to the ESXi initD script
# must be before the "exit 0" line found at the end if the default script in ESXi5.5
# hard to anchor this line anywhere, safest to put it right after the shebang at line 
# number 2 using 2i in sed string, who knows what future updates may change in the default file
sed -i "2i$SCRIPTPATH/ghettoVCB-backup-crontab-init.sh" $INITDSCRIPT

## init.d should now be rigged to start our custom crontab init at next reboot
## run the init script right now as well to establish the new crontab and not wait for next reboot
$SCRIPTPATH/ghettoVCB-backup-crontab-init.sh

## To ensure that this is saved in the ESXi configuration, we need to manually initiate an ESXi backup by running:
/sbin/auto-backup.sh

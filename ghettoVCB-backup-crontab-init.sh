# Author: Mart Verburg
# http://datamind.no
# Created Date: 2015-04-13
# published on GitHub.com in Datamind fork Datamind-dot-no/da-ghettoVCB 
# forked from lamw/ghettoVCB
##
# ghettoVCB-backup-crontab-init.sh
# Purpose: setup the email firewall rules, and the setup root crontab schedule with 
#  entries from GHETTOCRONFILE
# This script automates our most common setup steps as documented at  
#
# An automatic call to this script is supposed to be appended to the vSphere bootstrap 
# script /etc/rc.local.d/local.sh so it wil run at boot.  
# This bootstrap setup is performed by 
# the setup script ghettoVCB-backup-crontab-setup.sh
#
# pre: the ESXi busybox will have restarted and reverted previous
#   adjustments made to the firewall and crontab
# post1: custom firewall rule is established to allow email out
# post2: root Crontab is updated with da-ghettoVCB entries from 



# Where we want the logs sent
LOGDIR=/vmfs/volumes/datastore1/log

##
## No need to edit anything below here 
## -- unless you think you're more of a hacker like me ;-)
##

# which file contains the custom ghettoVCB cronjobs
GHETTOCRONFILE=ghettoVCB-backup-crontab-entries.txt

# establish the working dir
# ghettoVCB folder is used to find config files
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

# The Crontab to adjust
CRONTAB=/var/spool/cron/crontabs/root

# copy config file for firewall rule into place
cp $SCRIPTPATH/ghettoVCB-firewallrule-allow-smtp-outbound.xml /etc/vmware/firewall/email.xml

# reload firewall config
esxcli network firewall refresh

#  Confirm that your email rule has been loaded by running the following ESXCLI command
# esxcli network firewall ruleset list | grep email

# Note to self - ToDo: maybe add a firewall check here
esxcli network firewall ruleset list | grep email


# Connect to your email server by usingn nc (netcat) by running the following command and specifying the IP Address/Port of your email server:
# ~ # nc 172.30.0.107 25
# 220 mail.primp-industries.com ESMTP Postfix


## Now on to rig the crontab in our favor

# kill the cron daemon so we are free to modify the settings file
kill $(cat /var/run/crond.pid)


# strip any ghettoVCB lines that were in place beforehand
sed -i '/ghettoVCB/d' $CRONTAB


# add our changes to the standard root crontab, only 
# lines that were not in crontab already will be added to crontab, and 
# sorted in the same errand
# hail Stéphane Chazelas at http://unix.stackexchange.com/questions/164808/add-content-one-file-to-another
# LC_ALL=C sort -uo "$file2" "$file1" "$file2"
LC_ALL=C sort -uo $CRONTAB $SCRIPTPATH/$GHETTOCRONFILE $CRONTAB

# start the cron daemon again
crond

# 
# ghettoVCB-backup-wrap.sh
# - a wrapper for more comprehensible invocations from cron job or cli
#
# First argument is the list name. The list name is assumed to start 
# with this script name minus the -wrap.sh
#
# Remaining arguments are passed to the regular main GhettoVCB.sh script
#


# Where we want the logs sent
LOGDIR=/vmfs/volumes/datastore1/log

##
## No need to edit anything below here 
## -- unless you think you're more of a hacker like me ;-)
##

# establish the working dir
# Used to be hardcoded like so: 
# WORKDIR=/vmfs/volumes/datastore1/scripts/backup/ghettoVCB
# 
SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

STRIP="-wrap.sh"
SCRIPTNAME=$(basename "$SCRIPT")
#LISTNAME="${$SCRIPTNAME/$STRIP/$1}"
LISTNAME="$(echo $SCRIPTNAME | sed -e "s/${STRIP}/-${1}/")"

cd $SCRIPTPATH

# in order to keep the first argument for this wrapper, and pass the rest
# over to the main script
shift 1

./ghettoVCB.sh \
  -g ghettoVCB.conf \
  -l $LOGDIR/$(date +%F_%H-%M-%S)-log-$LISTNAME \
  -f $LISTNAME \
  "$@"
  
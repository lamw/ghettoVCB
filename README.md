ghettoVCB
===
This modified bundle is based on fork of lamw/ghettoVCB master branch.

  Author: William Lam
  Website: http://www.virtuallyghetto.com/

   ghettoVCB Documentation - http://communities.vmware.com/docs/DOC-8760
   ghettoVCB VMTN Group - http://communities.vmware.com/groups/ghettovcb
   ghettoVCB Restore Documentation - http://communities.vmware.com/docs/DOC-10595

-----------
**NOTE!**

> You will use this bundle in your environment at your own risk.  The authors of this package can not be held responsible for any issues this bundle may cause in your system.

================

History of modifications:
===

- 06.11.15  Merged modifications of lamw/ghettoVCB until 06.11.2015 into this bundle. Fixes and modifications listed below are included in this bundle.

- 23.10.14  Fixed value displayed as "DST_DATASTORE_FREE" in debug mode. Fixed message when faulty backup is deleted to match situation where nothing is deleted (VM_BACKUP_ROTATION_COUNT). Do not continue backup of vm if backup of vmdk's of it has failed for some reason.

- 22.10.14  Fixed value displayed as "SRC_DATASTORE_FREE" in debug mode. Command'.. | grep -i "capacity" ..' returned two values in VMware 5.5.0: "maxVirtualDiskCapacity" and "capacity" => parameter -i removed.

- 17.10.14  Fixed errors with optional pause: do not pause after last vmdk of vm. Added more debug messages.

- 16.10.14  Fixed message "Succesfully removed lock directory" of debug mode. In case backup of any vmdk's of vm fails, make backup of vm fail too: do not compress faulty backup if compress is enabled (ENABLE_COMPRESSION), instead delete this faulty backup (in checkVMBackupRotation). Prev. is fix for symlink creation too because it has not been created in this case while backups were anyway rotated (RSYNC_LINK,SYMLINK_SRC). Changed location of compress and rsync blocks. Optional pause between backup of vmdk's (debug "file already exist" errors).

- 01.10.14  Added VMKFSTOOLS_CMD_OPTIONS for VMKFSTOOLS_CMD command (f.ex VMKFSTOOLS_CMD_OPTIONS="-v 10")

- 05.09.14  In ghettoVCB.sh fixed typo indepdenent => independent.

- 29.08.14  Fixed handling of "-w" parameter, it does not have to be located before parameters -a and -m on command line anymore.
            Trap settings for removing workdir modified in case WORKDIR_DEBUG=1,
            also fixed call of reConfigureGhettoVCBConfiguration which was placed too late inside sanityCheck.
            NOTE! Remember to use own ghettoVCB specific temp directory for WORKDIR, it may be removed in the end of script.
            In ghettoVCB-restore.sh fixed one typo.

- 27.08.14  Fixed status messages of dryrun.
            Fixed "Final status" message when VM has independant VMDKs and at least one normal VMDK.

- 23.08.14  Forked from https://github.com/lamw/ghettoVCB.git.
            After help text is displayed, exit.
            Spaces in the end of lines were removed by editor. Real modifications have been marked with dates.


========================

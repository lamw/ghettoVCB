ghettoVCB
===
This bundle is fork of lamw/ghettoVCB:

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

-05.09.14   In ghettoVCB.sh fixed typo indepdenent => independent.

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

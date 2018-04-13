# da-ghettoVCB

### Description

The ghettoVCB script performs backups of virtual machines residing on ESX(i) 3.x, 4.x, 5.x & 6.x servers using methodology similar to VMware's VCB tool. The script takes snapshots of live running virtual machines, backs up the  master VMDK(s) and then upon completion, deletes the snapshot until the next backup. The only caveat is that it utilizes resources available to the ESXi Shell running the backups as opposed to following the traditional method of offloading virtual machine backups through a VCB proxy.

### why fork
da-ghettoVCB is forked from lamw/ghettoVCB

The purpose of this fork is to add Datamind AS setup scripts for cron and e-mail, these automate instructions provided in the parent project documentation at https://communities.vmware.com/docs/DOC-8760

This setup is rigged for a typical Datamind AS use case of scheduling backup of lists of VMs running on each host each day, workday, weekly.  We also want e-mail logs at first, and when proper production routine is established, failure alerts by e-mail only.

A "feature" is added to not issue warnings when ghettoVCB backup of independent disks is skipped as we don't expect those to be included, and warnings are logged anyway.  We often setup large data volumes as independant virtual disks with an alternate backup system. We find ghettoVCB is not fast enough to process these, probably due to limited resources available to esxi cli.

This version installs the crontab setup script by adding it as a call to the local.sh initd script in order to provide vSphere restart persistance. Future versions may merge to use the VIB or offline bundle mechanism for install like recent versions of Williams original do.

When running provided setup scripts, you need not change to the installation directory, the scripts assume related files are in the same directory


### setup
Assuming you're using *Nux like us where both git and scp are readily available.

Clone the github repo onto your admin computer using git or download and extract the zip archive  
```git clone https://github.com/Datamind-dot-no/da-ghettoVCB.git```  
```cd da-ghettoVCB```

We'll install onto persistant storage location of your choice on the vShpere host.  We like to go with the default name of the first persistant datastore as in /vmfs/volumes/**datastore1**/scripts/backup/da-ghettoVCB/  
We're assuming you already enabled SSH on the host  
Firstly create the directory you want to install into in the vSphere host, and one for the logs  
```mkdir -p /vmfs/volumes/datastore1/script/backup/da-ghettoVCB```  
```mkdir -p /vmfs/volumes/datastore1/log/da-ghettoVCB```

Now copy over the files and folders.  We recommend using CyberDuck, scp, or WinSCp.  
```scp -r . root@esxi01.example.lan:/vmfs/volumes/datastore1/script/backup/da-ghettoVCB/```

Login to vshpere ESXi shell, and change directory to new ghettoVCB folder, or prefix the folowing commands with your install path  
ssh root@esxi01.example.lan

Set permission to enable execution of our scripts in vSphere host ESXi shell if you installed by other means and didn't get the executable flag on the scripts  
```chmod +x *.sh```

Edit the main settings file, setup the backup location and the email parameters as recommended in the comments  
```vi ghettoVCB.conf```

Add a the name of a VM to test with to the daily backup list, preferably one using little storage space  
```vi ghettoVCB-backup-list-cron-daily.txt```

Copy the Crontab template to your settings file  
```cp ghettoVCB-backup-crontab-entries.template.txt ghettoVCB-backup-crontab-entries.txt```

Check desired scheduling time, remember to account for your timezone offset as vSphere runs on GMT.  
```vi ghettoVCB-backup-crontab-entries.txt```

Test your parameters by manually running crontab command, remember to **add the -d dryrun** parameter at the end
```./ghettoVCB-backup-wrap.sh list-cron-daily.txt -d dryrun```  
If all is well you got log output detailing what would be done on screen, as well as by e-mail.  You'll need to check well and correct if needed before proceeding.

Let's setup the cron jobs.  You need to use absolute path for the commands, and the script output needs to be redirected to /dev/null. Make the necessary changes for the commands from the template your environment in your ```ghettoVCB-backup-crontab-entries.txt```. It will then look something like this
<pre><code>
## template for scheduling ghettoVCB backup lists with cron.  Remember cron runs on GMT
## timezone, check your offset first, e.g. by running date
## Copy this file to ghettoVCB-backup-crontab-entries.txt before running ghettoVCB-backup-crontab-init.sh
#min hour day mon dow     command
0   17    *   *   *       /vmfs/volumes/datastore1/scripts/backup/ghettoVCB/ghettoVCB-backup-wrap.sh list-cron-daily.txt  > /dev/null
0   20    *   *   mon-fri /vmfs/volumes/datastore1/scripts/backup/ghettoVCB/ghettoVCB-backup-wrap.sh list-cron-weekdays.txt  > /dev/null
0   17    *   *   fri     /vmfs/volumes/datastore1/scripts/backup/ghettoVCB/ghettoVCB-backup-wrap.sh list-cron-weekly.txt  > /dev/null
</pre></code>

Now Now you can test the scheduling by adding the previous command as a cron job with a one-off date (this year) a couple of minutes in the future.
<pre><code>
#min hour day mon dow     command
<b>15  11    12  3   *       /vmfs/volumes/datastore1/scripts/backup/ghettoVCB/ghettoVCB-backup-wrap.sh list-cron-daily.txt -d dryrun > /dev/null</b>
</pre></code>

You can now schedule the dryrun in cron by running the init script  
```./ghettoVCB-backup-crontab-init.sh```

The scheduled job should be creating a logfile at ```/vmfs/volumes/datastore1/log/da-ghettoVCB```

When you're satisfied, run the setup script, this will make the setup persistant after reboot
```./ghettoVCB-backup-crontab-setup.sh```


### Additional Documentation & Resources
- [ghettoVCB Documentation](http://communities.vmware.com/docs/DOC-8760)
- [ghettoVCB VMTN Group](http://communities.vmware.com/groups/ghettovcb)
- [ghettoVCB Restore Documentation](http://communities.vmware.com/docs/DOC-10595)

### Licensing

The MIT License (MIT)

Copyright (c) 2015 www.virtuallyghetto.com!

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

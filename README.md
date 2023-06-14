# ghettoVCB

## Description

The ghettoVCB script performs backups of virtual machines residing on ESX(i) 3.x, 4.x, 5.x, 6.x, 7.x & 8.x servers using methodology similar to VMware's VCB tool. The script takes snapshots of live running virtual machines, backs up the  master VMDK(s) and then upon completion, deletes the snapshot until the next backup. The only caveat is that it utilizes resources available to the ESXi Shell running the backups as opposed to following the traditional method of offloading virtual machine backups through a VCB proxy.

## Download

Latest ghettoVCB VIB and Offline Bundle can be downloaded from [here](https://github.com/lamw/ghettoVCB/releases)

## Install

You can quickly install/update ghettoVCB by downloading and installing either the [VIB or offline bundle](https://github.com/lamw/ghettoVCB/releases) using the following commands. If you wish to update to latest ghettoVCB release and are using the ghettovcb.conf file and wish to have the setting persist, make sure to use the *update* command instead of *install*

Once installed, you will find all ghettoVCB configuration files located in:
```console
/etc/ghettovcb/ghettoVCB.conf
/etc/ghettovcb/ghettoVCB-restore_vm_restore_configuration_template
/etc/ghettovcb/ghettoVCB-vm_backup_configuration_template
```

Both ghettoVCB and ghettoVCB-restore scripts are located in:
```console
/opt/ghettovcb/bin/ghettoVCB.sh
/opt/ghettovcb/bin/ghettoVCB-restore.sh
```

Install VIB
```
esxcli software vib install -v /vghetto-ghettoVCB.vib -f
```

Install offline bundle
```
esxcli software vib install -d /vghetto-ghettoVCB-offline-bundle.zip -f
```

Update VIB
```
esxcli software vib update -v /vghetto-ghettoVCB.vib -f
```

Update offline bundle
```
esxcli software vib update -d /vghetto-ghettoVCB-offline-bundle.zip -f
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

> Note: If the installation takes some time. Just wait. This is normal.

## Build VIB/Offline Bundle

See the build documentation [here](build/README.md)

## Additional Documentation & Resources
- [ghettoVCB Documentation](http://communities.vmware.com/docs/DOC-8760)
- [ghettoVCB Restore Documentation](http://communities.vmware.com/docs/DOC-10595)
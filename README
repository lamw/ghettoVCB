ghettoVCB

### Description

This script performs backups of virtual machines residing on ESX(i) 3.x, 4.x, 5.x & 6.x servers using methodology similar to VMware's VCB tool. The script takes snapshots of live running virtual machines, backs up the  master VMDK(s) and then upon completion, deletes the snapshot until the next backup. The only caveat is that it utilizes resources available to the ESXi Shell running the backups as opposed to following the traditional method of offloading virtual machine backups through a VCB proxy.

### How to install

You can quickly install ghettoVCB by downloading and install either the VIB or offline bundle using the following commands:

Install VIB
```
esxcli software vib install -v /vghetto-ghettoVCB.vib -f
```

Install offline bundle
```
esxcli software vib install -d /vghetto-ghettoVCB-offline-bundle.zip -f
```

### Additional Documentation & Resources
- [ghettoVCB Documentation](http://communities.vmware.com/docs/DOC-8760)
- [ghettoVCB VMTN Group](http://communities.vmware.com/groups/ghettovcb)
- [ghettoVCB Restore Documentation](http://communities.vmware.com/docs/DOC-10595)

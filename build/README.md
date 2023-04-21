# Build ghettoVCB VIB/Offline Bundle

The `build.sh` shell script is used to create both the ghettoVCB VIB and Offline Bundle which is available for download in the [ghettoVCB Releases page](https://github.com/lamw/ghettoVCB/releases). For those interested, you can also use this script to generate your own VIB/Offline Bundled which automatically pulls from the latest ghettoVCB source code.

The build script requires `docker` to be installed and uses the [vibauthor docker](https://hub.docker.com/repository/docker/lamw/vibauthor) container to generate the VIB/Offline Bundle.

Here is an example of running the script:

```code
❯ ./build.sh

Untagged: ghettovcb:latest
Deleted: sha256:4961ac02e829aa3d71401565027e395f254b4a220570333b9deebd588d5bd8b0
Deleted: sha256:b2203f902261eee689c7cd066fed48687fe1dcbf72bf5c337f3e878b759b221a
Deleted: sha256:5cd0340cce143df29664f5b095bafbe993e57b4fb7f7cb41c9f43b1fe36fd6fc
Deleted: sha256:cd201ab3ba5c8a3bd20ed924fb67600c164d0950416630107303da6090c16c5c
Deleted: sha256:085f155aaa2fcccc938ab899675ed05f6712f33a212f5015e7029e255ff85d53
Deleted: sha256:3f435a105eaf07a4f931b9e5438b4f753d12e4dbeb99aa30726f662c03a5ad3a
Deleted: sha256:47227020e006eea1af0f5061ee277402bbd96a49ccb3f5c9e7c5fd5e1f456cf8
Sending build context to Docker daemon  9.728kB
Step 1/8 : FROM lamw/vibauthor
 ---> a673ffe4ba43
Step 2/8 : RUN rpm --rebuilddb
 ---> Running in 894b1e52ce30
Removing intermediate container 894b1e52ce30
 ---> e105a98f75ef
Step 3/8 : RUN yum clean all
 ---> Running in 5418e2b59881
Loaded plugins: fastestmirror, ovl
Cleaning repos: base extras updates
Cleaning up Everything
Removing intermediate container 5418e2b59881
 ---> 1710944fd26b
Step 4/8 : RUN yum update -y nss curl libcurl;yum clean all
 ---> Running in ab7ac3f661c4
Loaded plugins: fastestmirror, ovl
Setting up Update Process
Determining fastest mirrors
Resolving Dependencies
--> Running transaction check
---> Package curl.x86_64 0:7.19.7-53.el6_9 will be updated
---> Package curl.x86_64 0:7.19.7-54.el6_10 will be an update
---> Package libcurl.x86_64 0:7.19.7-53.el6_9 will be updated
---> Package libcurl.x86_64 0:7.19.7-54.el6_10 will be an update
---> Package nss.x86_64 0:3.36.0-8.el6 will be updated
--> Processing Dependency: nss = 3.36.0-8.el6 for package: nss-sysinit-3.36.0-8.el6.x86_64
--> Processing Dependency: nss(x86-64) = 3.36.0-8.el6 for package: nss-tools-3.36.0-8.el6.x86_64
---> Package nss.x86_64 0:3.44.0-7.el6_10 will be an update
--> Processing Dependency: nss-softokn(x86-64) >= 3.44.0-1 for package: nss-3.44.0-7.el6_10.x86_64
--> Running transaction check
---> Package nss-softokn.x86_64 0:3.14.3-23.3.el6_8 will be updated
---> Package nss-softokn.x86_64 0:3.44.0-6.el6_10 will be an update
---> Package nss-sysinit.x86_64 0:3.36.0-8.el6 will be updated
---> Package nss-sysinit.x86_64 0:3.44.0-7.el6_10 will be an update
---> Package nss-tools.x86_64 0:3.36.0-8.el6 will be updated
---> Package nss-tools.x86_64 0:3.44.0-7.el6_10 will be an update
--> Finished Dependency Resolution

Dependencies Resolved

================================================================================
 Package            Arch          Version                  Repository      Size
================================================================================
Updating:
 curl               x86_64        7.19.7-54.el6_10         updates        198 k
 libcurl            x86_64        7.19.7-54.el6_10         updates        170 k
 nss                x86_64        3.44.0-7.el6_10          updates        883 k
Updating for dependencies:
 nss-softokn        x86_64        3.44.0-6.el6_10          updates        288 k
 nss-sysinit        x86_64        3.44.0-7.el6_10          updates         54 k
 nss-tools          x86_64        3.44.0-7.el6_10          updates        472 k

Transaction Summary
================================================================================
Upgrade       6 Package(s)

Total download size: 2.0 M
Downloading Packages:
--------------------------------------------------------------------------------
Total                                            12 MB/s | 2.0 MB     00:00
Running rpm_check_debug
Running Transaction Test
Transaction Test Succeeded
Running Transaction
Warning: RPMDB altered outside of yum.
  Updating   : nss-softokn-3.44.0-6.el6_10.x86_64                          1/12
  Updating   : nss-sysinit-3.44.0-7.el6_10.x86_64                          2/12
  Updating   : nss-3.44.0-7.el6_10.x86_64                                  3/12
  Updating   : libcurl-7.19.7-54.el6_10.x86_64                             4/12
  Updating   : curl-7.19.7-54.el6_10.x86_64                                5/12
  Updating   : nss-tools-3.44.0-7.el6_10.x86_64                            6/12
  Cleanup    : nss-tools-3.36.0-8.el6.x86_64                               7/12
  Cleanup    : curl-7.19.7-53.el6_9.x86_64                                 8/12
  Cleanup    : libcurl-7.19.7-53.el6_9.x86_64                              9/12
  Cleanup    : nss-sysinit-3.36.0-8.el6.x86_64                            10/12
  Cleanup    : nss-3.36.0-8.el6.x86_64                                    11/12
  Cleanup    : nss-softokn-3.14.3-23.3.el6_8.x86_64                       12/12
  Verifying  : curl-7.19.7-54.el6_10.x86_64                                1/12
  Verifying  : libcurl-7.19.7-54.el6_10.x86_64                             2/12
  Verifying  : nss-softokn-3.44.0-6.el6_10.x86_64                          3/12
  Verifying  : nss-tools-3.44.0-7.el6_10.x86_64                            4/12
  Verifying  : nss-sysinit-3.44.0-7.el6_10.x86_64                          5/12
  Verifying  : nss-3.44.0-7.el6_10.x86_64                                  6/12
  Verifying  : nss-softokn-3.14.3-23.3.el6_8.x86_64                        7/12
  Verifying  : nss-3.36.0-8.el6.x86_64                                     8/12
  Verifying  : nss-sysinit-3.36.0-8.el6.x86_64                             9/12
  Verifying  : libcurl-7.19.7-53.el6_9.x86_64                             10/12
  Verifying  : curl-7.19.7-53.el6_9.x86_64                                11/12
  Verifying  : nss-tools-3.36.0-8.el6.x86_64                              12/12

Updated:
  curl.x86_64 0:7.19.7-54.el6_10        libcurl.x86_64 0:7.19.7-54.el6_10
  nss.x86_64 0:3.44.0-7.el6_10

Dependency Updated:
  nss-softokn.x86_64 0:3.44.0-6.el6_10   nss-sysinit.x86_64 0:3.44.0-7.el6_10
  nss-tools.x86_64 0:3.44.0-7.el6_10

Complete!
Loaded plugins: fastestmirror, ovl
Cleaning repos: base extras updates
Cleaning up Everything
Cleaning up list of fastest mirrors
Removing intermediate container ab7ac3f661c4
 ---> 5690d9c8f3b0
Step 5/8 : COPY create_ghettoVCB_vib.sh create_ghettoVCB_vib.sh
 ---> 41528c8b4a87
Step 6/8 : RUN chmod +x create_ghettoVCB_vib.sh
 ---> Running in 1ae6b4f7a749
Removing intermediate container 1ae6b4f7a749
 ---> c10f6341e862
Step 7/8 : RUN /root/create_ghettoVCB_vib.sh
 ---> Running in bd605bcc5442
Initialized empty Git repository in /root/ghettoVCB/.git/
Successfully created vghetto-ghettoVCB.vib.
Successfully created vghetto-ghettoVCB-offline-bundle.zip.
Removing intermediate container bd605bcc5442
 ---> 7d64d39dea4d
Step 8/8 : CMD ["/bin/bash"]
 ---> Running in 043692b22cde
Removing intermediate container 043692b22cde
 ---> 7e1196135f15
Successfully built 7e1196135f15
Successfully tagged ghettovcb:latest
```

Upon success, you should have a new directory called `artifacts` which contains both the VIB and Offline Bundle

```code
❯ tree artifacts

artifacts
├── vghetto-ghettoVCB-offline-bundle.zip
└── vghetto-ghettoVCB.vib
```
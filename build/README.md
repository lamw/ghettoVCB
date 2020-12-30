# Build ghettoVCB VIB/Offline Bundle

The `build.sh` shell script is used to create both the ghettoVCB VIB and Offline Bundle which is available for download in the [ghettoVCB Releases page](https://github.com/lamw/ghettoVCB/releases). For those interested, you can also use this script to generate your own VIB/Offline Bundled which automatically pulls from the latest ghettoVCB source code.

The build script requires `docker` to be installed and uses the [vibauthor docker](https://hub.docker.com/repository/docker/lamw/vibauthor) container to generate the VIB/Offline Bundle.

Here is an example of running the script:

```code
❯ ./build.sh

Untagged: ghettovcb:latest
Deleted: sha256:af50b3cc12eec9277e04921e556fe6a62c64d9e503d850d7de59a9cf47b401bb
Deleted: sha256:bbf8b88d685825840508451014e38f84e459ffb75e7b2a4e185e7f5c47c7b618
Deleted: sha256:a72afa7385618d5865b88300b1889385b9e6204547bd88c6f719fb15a81217e3
Deleted: sha256:d221fb0ba5af54c0de4d15e2eec3fdafcee97fd895aab6c359372fd76f84b339
Sending build context to Docker daemon  6.656kB
Step 1/8 : FROM lamw/vibauthor
 ---> a673ffe4ba43
Step 2/8 : RUN rpm --rebuilddb
 ---> Using cache
 ---> 753af48ef9af
Step 3/8 : RUN yum clean all
 ---> Using cache
 ---> 689b05a480e2
Step 4/8 : RUN yum update -y nss curl libcurl;yum clean all
 ---> Using cache
 ---> c51671aed6fa
Step 5/8 : COPY create_ghettoVCB_vib.sh create_ghettoVCB_vib.sh
 ---> 7d2e7dffd928
Step 6/8 : RUN chmod +x create_ghettoVCB_vib.sh
 ---> Running in feaffc690f72
Removing intermediate container feaffc690f72
 ---> 25dbc3dee22a
Step 7/8 : RUN /root/create_ghettoVCB_vib.sh
 ---> Running in 9eae129c4da1
Initialized empty Git repository in /root/ghettoVCB/.git/
Successfully created vghetto-ghettoVCB.vib.
Successfully created vghetto-ghettoVCB-offline-bundle.zip.
Removing intermediate container 9eae129c4da1
 ---> ddb549b11636
Step 8/8 : CMD ["/bin/bash"]
 ---> Running in dda3680d7a69
Removing intermediate container dda3680d7a69
 ---> 616ef9508225
Successfully built 616ef9508225
Successfully tagged ghettovcb:latest
```

Upon success, you should have a new directory called `artifacts` which contains both the VIB and Offline Bundle

```code
❯ tree artifacts

artifacts
├── vghetto-ghettoVCB-offline-bundle.zip
└── vghetto-ghettoVCB.vib
```
FROM lamw/vibauthor

# Due to https://stackoverflow.com/a/49026601
RUN rpm --rebuilddb
RUN yum clean all
RUN yum update -y nss curl libcurl;yum clean all

# Copy ghettoVCB VIB build script
COPY create_ghettoVCB_vib.sh create_ghettoVCB_vib.sh
RUN chmod +x create_ghettoVCB_vib.sh

# Run ghettoVCB VIB build script
RUN /root/create_ghettoVCB_vib.sh

CMD ["/bin/bash"]

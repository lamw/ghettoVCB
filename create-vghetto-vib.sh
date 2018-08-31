# requires ar from binutils:
# apt install binutils

OLDPWD=$PWD
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
version=1.0.0
#revision=13
esxserver=vmserver-2
revision=$(svn info |grep Revision|awk '{print $2}')
module_name=ghettoVCB
vibversion="${version}-${revision}"

get_xml_filelist () {
    if [ ! -z $1 ]; then
        cd $1
    fi
    echo "    <file-list>"
    find opt etc -not -path '*/\.*' -type f | while read file;do
        echo "        <file>${file}</file>"
    done
    echo "    </file-list>"
}
XML_FILELIST=$(get_xml_filelist $DIR)
mkdir -p $DIR/dist

tar -cf dist/${module_name:0:8} -C $DIR opt etc 
cd $DIR/dist
ls
TAR_SHA1=$(sha1sum ${module_name:0:8} | cut -d" " -f1)

gzip ${module_name:0:8}
mv ${module_name:0:8}.gz ${module_name:0:8}
GZIP_SHA256=$(sha256sum ${module_name:0:8} | cut -d" " -f1)
GZIP_SIZE=$(du --bytes ${module_name:0:8} | cut -f1)

touch sig.pkcs7

cat << EOF > descriptor.xml
<vib version="5.0">
    <type>bootbank</type>
    <name>${module_name}</name>
    <version>${vibversion}</version>
    <vendor>virtuallyGhetto</vendor>
    <summary>[Fling] ghettoVCB VM backup and restore script</summary>
    <description>61b1ebaad353abf4c8e3f2a15413d8c3e00f2e88</description>
    <release-date>$(date +%Y-%m-%dT%H:%M:%S.000000+00:00)</release-date>
    <urls>
        <url key="ghettoVCB">https://github.com/lamw/ghettoVCB</url>
    </urls>
    <relationships>
        <depends/>
        <conflicts/>
        <replaces/>
        <provides/>
        <compatibleWith/>
    </relationships>
    <software-tags/>
    <system-requires>
        <maintenance-mode>false</maintenance-mode>
    </system-requires>
${XML_FILELIST}
    <acceptance-level>community</acceptance-level>
    <live-install-allowed>true</live-install-allowed>
    <live-remove-allowed>true</live-remove-allowed>
    <cimom-restart>false</cimom-restart>
    <stateless-ready>true</stateless-ready>
    <overlay>false</overlay>
    <payloads>
        <payload name="${module_name:0:8}" type="tgz" size="${GZIP_SIZE}">
            <checksum checksum-type="sha-256">${GZIP_SHA256}</checksum>
            <checksum checksum-type="sha-1" verify-process="gunzip">${TAR_SHA1}</checksum>
        </payload>
    </payloads>
</vib>
EOF

ar -r $module_name-${vibversion}.vib descriptor.xml sig.pkcs7 ${module_name:0:8}

echo "FINISHED"
echo ""
echo "you could deploy the new vib by running:"
echo "scp dist/$module_name-${vibversion}.vib root@$esxserver:/tmp/"
echo "ssh root@$esxserver \"esxcli software vib remove -f -n $module_name\""
echo "ssh root@$esxserver \"esxcli software vib install -f -v /tmp/$module_name-${vibversion}.vib\""

cd $OLDPWD

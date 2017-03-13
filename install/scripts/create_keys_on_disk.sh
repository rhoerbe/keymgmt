#!/usr/bin/env bash
#set -eu -o pipefail


main() {
    get_commandline_opts $@
    #mount_ramdisk
    set_openssl_config
    create_keypair_and_certificate
}


get_commandline_opts() {
    keysize=2048
    x509subject='C=AT/ST=Wien/L=Wien/O=Testfirma/OU=IT/CN=localhost'
    keyname='signer'
    while getopts ":k:n:s:v" opt; do
      case $opt in
        k) keysize=$OPTARG
           re='^[0-9]{3,5}$'
           if ! [[ $OPTARG =~ $re ]] ; then
              echo "error: -k argument is not a number in the range from 1024 .. 16384" >&2; exit 1
           fi;;
        n) keyname=$OPTARG;;
        v) verbose="True";;
        s) x509subject=$OPTARG;;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 0;;
      esac
    done
    #shift $((OPTIND-1))
}


usage() {
    cat << EOF
        usage: $0 [-k <NNNN>] [-n <key name>] [-v] [-s <X509 subject>]
          -h  print this help text
          -k  keysize (default: $keysize)
          -n  file name of key and certificate (default: $keyname)
          -v  print command
          -s  x509 subject DN (default: $x509subject)
EOF
}


mount_ramdisk() {
    mkdir /ramdisk
    mount -t tmpfs -o size=10M tmpfs /ramdisk
    cd /ramdisk
}


set_openssl_config() {
    cat > /tmp/openssl.cfg <<EOT
[req]
distinguished_name=dn
[ dn ]
[ ext ]
basicConstraints=CA:FALSE
EOT

}


create_keypair_and_certificate() {
    cmd1="openssl req
        -config /tmp/openssl.cfg
        -x509 -newkey rsa:${keysize}
        -keyout /ramdisk/${keyname}_key_pkcs8.pem
        -out /ramdisk/${keyname}_crt.pem
        -sha256 -days 3650 -nodes
        -batch -subj \"$x509subject\"
    "
    cmd2="openssl rsa -in /ramdisk/${keyname}_key_pkcs8.pem -out /ramdisk/${keyname}_key_pkcs1.pem"

    if [ "$verbose" == "True" ]; then
        echo $cmd1
        echo $cmd2
    fi

    echo $cmd1 > $0.tmp   # indirect execution as workaround against "invalid subject not beginning with '/'"
    bash ./$0.tmp
    $cmd2
    # provide the old pkcs1 private key format in addition to pkcs8
    chmod 600 /ramdisk/${keyname}_key_pkcs?.pem
}


main $@
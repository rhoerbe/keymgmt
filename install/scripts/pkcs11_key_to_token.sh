#!/usr/bin/env bash
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

main() {
    get_commandline_args $@
    check_mandatory_args
    if [[ $INIT == "True" ]]; then
        initialize_token
    fi
    write_key_to_token
}


get_commandline_args() {
    while getopts ":c:dik:l:n:p:s:t:v" opt; do
      case $opt in
        c) CERT=$OPTARG;;
        d) DRYRUN='True'; verbose="True";;
        i) INIT='True';;
        k) PRIVKEY=$OPTARG;;
        l) CERTLABELOPT="--label $OPTARG";;
        n) TOKENLABEL=$OPTARG;;
        p) PYKCS11LIB=$OPTARG;;
        s) SOPIN=$OPTARG;;
        t) PYKCS11PIN=$OPTARG;;
        v) verbose="True";;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 0;;
      esac
    done
    shift $((OPTIND-1))
}


check_mandatory_args() {
    [[ -z "$CERT" ]] && usage && echakto "missing option -c" && exit 1
    echo 'testing x509 certificate'
    openssl x509 -inform DER -in $CERT -noout
    (( $? > 0 )) && echo 'certificate file must be a valid X.509 cert in DER format' && exit 2
    [[ -z "$PRIVKEY" ]] && usage && echo "missing option -k" && exit 3
    echo 'testing RSA private key'
    openssl rsa -inform DER -in $PRIVKEY -check  -noout
    (( $? > 0 )) && echo 'private key must be a valid RSA key in DER format' && exit 4
    [[ -z "$TOKENLABEL" ]] && usage && echo "missing option -n" && exit 5
    [[ -z "$SOPIN" ]]  && ! $INIT  && usage && echo "option -s required with -i" && exit 6
    [[ -z "$PYKCS11PIN" ]] && usage && echo "missing option -t" && exit 7
}


usage() {
    cat << EOF
        Transfer certificate + private key to PKCS#11 Token
        usage: $0 -c Cert File [-d ] [-i] [-l Object Label ] -k Key File -n Token Name [-p PKCS#11 driver] -s SO PIN -t User PIN [-v]
          -c  Certifiate file (DER)
          -d  Dry run: print commands but do not execute
          -h  print this help text
          -i  initialize token before writing key
          -k  Private key file (DER)
          -l  Certificate/private key label
          -n  Token Name
          -s  Security Officer PIN
          -p  Path to library of PKCS#11 driver (default: $PYKCS11LIB)
          -t  User PIN
          -v  verbose
EOF
}


initialize_token() {
    echo 'Initializing Token'
    cmd="pkcs11-tool --module $PYKCS11LIB --init-token --label $TOKENLABEL --pin $PYKCS11PIN --so-pin $SOPIN"
    run_command
    echo 'Initializing User PIN'
    cmd="pkcs11-tool --module $PYKCS11LIB --login --init-pin --pin $PYKCS11PIN --so-pin $SOPIN"
    run_command
}


write_key_to_token() {
    echo 'writing certificate'
    # hint: --id is required for sun PKCS#11 provider to retrieve keys from the token (see http://docs.oracle.com/javase/7/docs/technotes/guides/security/p11guide.html#KeyStoreRestrictions)
    cmd="pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --write-object $CERT --type cert --id 1 $CERTLABELOPT"
    run_command
    echo 'writing private key'
    cmd="pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --write-object $PRIVKEY --type privkey --id 1 $CERTLABELOPT"
    run_command
    echo 'Checking objects on card'
    cmd="pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --list-objects"
    run_command
}


run_command() {
    if [[ $verbose ]]; then
        echo $cmd; echo
    fi
    if [[ ! $DRYRUN ]]; then
        $cmd
    fi
}

main $@
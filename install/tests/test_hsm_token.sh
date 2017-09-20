#!/usr/bin/env bash


SCRIPT=$(basename $0)
SCRIPT=${SCRIPT%.*}
LOGDIR="/tmp/${SCRIPT%.*}"
mkdir -p $LOGDIR
echo "    Logfiles in $LOGDIR"
set +e

echo 'Test 30: HSM USB device'
if [[ $SOFTHSM ]]; then
    echo 'Soft HSM configured'
else
    lsusb | grep "$HSMUSBDEVICE" > $LOGDIR/test30.log
    if (( $? != 0 )); then
        echo 'HSM USB device not found - failed HSM test'
        exit 1
    fi
fi


echo 'Test 31: PKCS11 driver lib'
if [[ -z ${PYKCS11LIB+x} ]]; then
    echo 'PYKCS11LIB not set - failed HSM test'
    exit 1
fi


if [[ ! -e ${PYKCS11LIB} ]]; then
    echo 'PYKCS11LIB not found'
    exit 1
fi


if [[ -z ${PYKCS11PIN+x} ]]; then
    echo 'PYKCS11PIN not set - failed HSM test'
    exit 1
fi


echo 'Test 32: PCSCD'
pid=$(pidof /usr/sbin/pcscd) > /dev/null
if (( $? == 1 )); then
    echo 'pcscd process not running'
    exit 1
fi


echo 'Test 33: HSM PKCS#11 device'
pkcs11-tool --module $PYKCS11LIB --list-token-slots | grep "$HSMP11DEVICE"  > $LOGDIR/test33.log
if (( $? > 0 )); then
    echo 'HSM Token not connected'
    exit 1
fi


echo 'Test 34: Initializing HSM Token'
pkcs11-tool --module $PYKCS11LIB --init-token --label test --pin $PYKCS11PIN --so-pin $SOPIN
if (( $? > 0 )); then
    echo "HSM Token not initailized, failed with code $?"
    exit 1
fi


echo 'Test 35: Initializing User PIN'
pkcs11-tool --module $PYKCS11LIB --login --init-pin --pin $PYKCS11PIN --so-pin $SOPIN
if (( $? > 0 )); then
    echo "User PIN not initailized, failed with code $?"
    exit 1
fi


echo 'Test 36: Login to HSM'
pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --show-info 2>&1 \
    | grep 'present token' > $LOGDIR/test34.log
if (( $? > 0 )); then
    pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --show-info
    echo 'Login failed'
    exit 1
fi


echo 'Test 37: List certificate(s)'
pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --list-objects  --type cert 2>&1 \
    | grep 'Certificate Object' > $LOGDIR/test35.log
if (( $? > 0 )); then
    echo 'No certificate found'
    exit 1
fi


echo 'Test 38: List private key(s)'
pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --list-objects  --type privkey 2>&1 \
    | grep 'Private Key Object' > $LOGDIR/test36.log
if (( $? > 0 )); then
    echo 'No private key found'
    exit 1
fi


echo 'Test 39: Sign test data'
echo "foo" > /tmp/bar
pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN  \
    --sign --input /tmp/bar --output /tmp/bar.sig > $LOGDIR/test38.log 2>&1
if (( $? > 0 )); then
    echo 'Signature failed'
    exit 1
fi


echo 'Test 40: Count objects using PyKCS11'

/tests/pykcs11_getkey.py --pin=$PYKCS11PIN --slot=0 --lib=$PYKCS11LIB 2>&1 \
    | grep -a -c '=== Object ' > $LOGDIR/test38.log 2>&1
if (( $? > 0 )); then
    echo 'Listing HSM token object with PyKCS11 lib failed'
    exit 1
fi

echo 'Test 41: List objects and PKCS11-URIs with p11tool'

export GNUTLS_PIN=$PYKCS11PIN
p11tool --provider $PYKCS11LIB --list-all --login pkcs11:token=testtoken;id=%01
if (( $? > 0 )); then
    echo 'Listing HSM objects with p11tool failed'
    exit 1
fi

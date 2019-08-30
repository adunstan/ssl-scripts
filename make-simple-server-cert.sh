#!/bin/sh

# The simple server cert is different in that
# . it only uses one host name (IN THE CN) instead of SANs
# . it is signed by the root CA cert

. ./common.sh

if [ ! -e cadir/private/capw.dat ]
then
	echo Need the root CA
	exit 1
fi

rm -f simple-server.crt simple-server.key

arg=$1

if [ "X$arg" = "X-k" ]
then
	spass=`openssl rand -hex 10`
	reqarg="-passout pass:$spass"
	echo Using password $spass
else
	reqarg="-nodes"
fi

# get the root CA certificate
cp cadir/cacert.pem root.crt

# we'll sign this with the root CA
capw=`cat cadir/private/capw.dat`

# this will be the host in the certificate
host="host1.foo.bar"

# generate the CSR
openssl req -new -days 365 -config cadir/openssl.conf \
        $reqarg -out simple-server.csr \
        -keyout simple-server.key -subj "$SUBJ/CN=$host" > /dev/null 2>&1
# protect the key
chmod og-rwx simple-server.key
# sign the CSR, generating the certificate
openssl ca -in simple-server.csr  \
  -config cadir/openssl.cnf \
  -cert cadir/cacert.pem -keyfile cadir/private/cakey.pem  \
  -passin pass:$capw -out simple-server.crt -batch >/dev/null 2>&1
# remove the CSR
rm simple-server.csr

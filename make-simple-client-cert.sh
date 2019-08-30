#!/bin/sh


# the simple-client cert is different in that
# . it is signed with the root CA cert
# . no PKCS#8 key is generated


. ./common.sh

if [ ! -e cadir/private/capw.dat ]
then
	echo Need the root CA
	exit 1
fi

rm -f simple-client.crt simple-client.key

arg=$1

if [ "X$arg" = "X-k" ]
then
	cpass=`openssl rand -hex 10`
	reqarg="-passout pass:$cpass"
	echo Using password $cpass
else
	reqarg="-nodes"
fi

# get the root CA certificate
cp cadir/cacert.pem root.crt

# we'll sign this with the root CA
capw=`cat cadir/private/capw.dat`

# this will be the CN of the certificate
user=my_user

# generate the CSR
openssl req -new $reqarg -text -days 365 -out simple-client.csr \
		-keyout simple-client.key -subj "$SUBJ/CN=$user" >/dev/null 2>&1
# protect the key
chmod og-rwx client.key
# sign the CSR, generating the certificate
openssl ca -in simple-client.csr  \
  -config cadir/openssl.cnf \
  -cert cadir/cacert.pem -keyfile cadir/private/cakey.pem  \
  -passin pass:$capw -out simple-client.crt -batch >/dev/null 2>&1
# remove the CSR
rm simple-client.csr


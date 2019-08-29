#!/bin/sh

arg=$1

. ./common.sh

rm -f client.crt client.key

if [ "X$arg" = "X-k" ]
then
	cpass=`openssl rand -hex 10`
	reqarg="-passout pass:$cpass"
	pkcs8arg="-passin pass:$cpass -passout pass:$cpass"
	echo Using password $cpass
else
	reqarg="-nodes"
	pkcs8arg="-passout pass:"
fi

# get the root CA certificate
cp cadir/cacert.pem root.crt

# we'll sign this with the leaf CA
capw=`cat cadir/private/icapw2.dat`

# this will be the CN of the certificate
user=my_user

# generate the CSR
openssl req -new $reqarg -text -days 365 -out client.csr \
		-keyout client.key -subj "$SUBJ/CN=$user" >/dev/null 2>&1
# protect the key
chmod og-rwx client.key
# sign the CSR, generating the certificate
openssl ca -in client.csr  \
  -config cadir/openssl.cnf \
  -cert cadir/intermediate2.pem -keyfile cadir/private/intermediate2.key  \
  -passin pass:$capw -out client.crt -batch >/dev/null 2>&1
# remove the CSR
rm client.csr

# add the intermediate and leaf CA certificates to the cert, so it can be
# validated with the root.crt.
cat cadir/intermediate2.pem cadir/intermediate1.pem >> client.crt

# generate the PKCS#8 version of the client key for jdbc use
openssl pkcs8 -topk8 $pkcs8arg -inform PEM -in client.key \
		-outform DER  -out client.pk8


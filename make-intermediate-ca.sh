#!/bin/sh

. ./common.sh

cd cadir

# we'll sign with the root CA
capw=`cat private/capw.dat`

# make and record a new password for this CA
icapw=`openssl rand -hex 30`
echo $icapw > private/icapw1.dat

# generate the CSR
openssl req -new -passout pass:$icapw -text -out intermediate.csr \
		-keyout private/intermediate1.key \
		-subj "$SUBJ/CN=Intermediate CA 1" >/dev/null 2>&1
# protect the key
chmod og-rwx private/intermediate1.key
# sign the CRS, generating the certificate for the new CA
openssl x509 -req -in intermediate.csr -days 1825 \
  -extfile openssl.cnf -extensions v3_ca \
  -CA cacert.pem -CAkey private/cakey.pem  -passin pass:$capw \
  -CAcreateserial -out intermediate1.pem >/dev/null 2>&1
# drop the CSR
rm intermediate.csr

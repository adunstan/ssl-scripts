#!/bin/sh

. ./common.sh

cd cadir

# we'll sign with intermediate CA 1
capw=`cat private/icapw1.dat`

# make and record a new password for this CA
icapw=`openssl rand -hex 30`
echo $icapw > private/icapw2.dat

# generate the CRS
openssl req -new -passout pass:$icapw -text -out intermediate.csr \
		-keyout private/intermediate2.key \
		-subj "$SUBJ/CN=Intermediate CA 2" >/dev/null 2>&1
# make sure the key is restricted
chmod og-rwx private/intermediate2.key
# sign the CSR to get the certificate
openssl x509 -req -in intermediate.csr -days 910 \
  -extfile openssl.cnf -extensions v3_ca \
  -CA intermediate1.pem -CAkey private/intermediate1.key  -passin pass:$capw \
  -CAcreateserial -out intermediate2.pem >/dev/null 2>&1
# remove the CSR
rm intermediate.csr



#!/bin/sh

. ./common.sh

rm -f root.crt

# make the CA dir and its config file and subdirectories
rm -rf cadir
mkdir cadir
dd cadir
DIR=`pwd`
cp /etc/pki/tls/openssl.cnf .
sed -i -e "s,^dir.*,dir = $DIR," -e 's/#unique_subject/unique_subject/' \
       openssl.cnf
# this is required for SANs
sed -i -e 's/# copy_extensions/copy_extensions/' openssl.cnf
mkdir certs private newcerts
chmod 700 .; echo 1000 > serial; touch index.txt; echo 01 > crlnumber
cd ..

# switch to the CA dir
cd cadir

#generate and record a password for the root CA
capw=`openssl rand -hex 30`
echo $capw > private/capw.dat

# generate the Root CA cert and key
openssl req -passout pass:$capw -new -x509 -days 3650 -extensions v3_ca \
        -config openssl.cnf -subj "$SUBJ/CN=My Root CA" \
        -keyout private/cakey.pem \
        -out cacert.pem >/dev/null 2>&1


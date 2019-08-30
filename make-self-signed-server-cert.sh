#!/bin/sh

# the self-signed server cert
# . doesn't have a password on the key
# . has one host in the CN field

. ./common.sh


rm -f self-signed-server.crt self-signed-server.key

# this will be the host in the certificate
host="host1.foo.bar"

# generate the certificate
openssl req -new -days 365 -x509 \
        -nodes -out self-signed-server.crt \
        -keyout self-signed-server.key -subj "$SUBJ/CN=$host" > /dev/null 2>&1
# protect the key
chmod og-rwx self-signed-server.key

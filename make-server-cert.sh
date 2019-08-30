#!/bin/sh

. ./common.sh

if [ ! -e cadir/private/icapw2.dat ]
then
	echo Need the leaf CA
	exit 1
fi

rm -f server.crt server.key

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

# we'll sign this with the leaf CA
capw=`cat cadir/private/icapw2.dat`

# these will be the hosts in the certificate
hosts="host1.foo.bar.com host2.foo.bar.com host3.foo.bar.com"


# generate a temporary config file that will be used to generate the CSR
cat > /tmp/san.cnf <<-EOF
	[ req ]
	default_bits       = 2048
	distinguished_name = req_distinguished_name
	req_extensions     = req_ext
	[ req_distinguished_name ]
	countryName                 = Country Name (2 letter code)
	stateOrProvinceName         = State or Province Name (full name)
	localityName               = Locality Name (eg, city)
	organizationName           = Organization Name (eg, company)
	commonName                 = Common Name (e.g. server FQDN or YOUR name)
	[ req_ext ]
	subjectAltName = @alt_names
	[alt_names]
	EOF

count=0
for f in $hosts
do
    count=`expr $count + 1`
    test $count = 1 && firsthost=$f
    echo "DNS.$count = $f" >> /tmp/san.cnf
done

# generate the CSR
openssl req -new -days 365 -config /tmp/san.cnf \
        $reqarg -out server.csr \
        -keyout server.key -subj "$SUBJ/CN=multiple hosts" > /dev/null 2>&1
# protect the key
chmod og-rwx server.key
# sign the CSR, generating the certificate
openssl ca -in server.csr  \
  -config cadir/openssl.cnf \
  -cert cadir/intermediate2.pem -keyfile cadir/private/intermediate2.key  \
  -passin pass:$capw -out server.crt -batch >/dev/null 2>&1
# remove the CSR
rm server.csr

# add the intermediate and leaf CA certificates to the cert, so it can be
# validated with the root.crt.
cat cadir/intermediate2.pem cadir/intermediate1.pem >> server.crt


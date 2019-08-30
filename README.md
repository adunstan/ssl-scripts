Sample SSL scripts for use with generating PostgreSQL SSL certs
===============================================================

These scripts demonstrate setting up a root CA, and intermediate CA, a leaf CA,
and server and client certificates signed by the leaf CA.

The CA passwords are stored in cadir/private. Of course, you shouldn't do
that in a production setting.

The script to generate client and server certificates can take a `-k` argument.
If this is done they will generate a password for the key and tell you what it
is.

The client key is generated in both standard PEM format and in PKCS#8 format.
The latter is what's required for use with the PostgreSQL JDBC driver.

There are also scripts for simple server and client keys , signed by the
root CA and with a single host name (server) and no PKCS#8 key (client), as
well as a script to generate a self-signed server certificate with a single
host name.

The scripts were written to validate some commands shown in a 2019 Conference
presentation.

#!/bin/sh

comment=<<EOF

expected output (twice, one for pgbouncer):

 ssl_is_used 
-------------
 t
(1 row)

EOF

# clean up from previous runs

rm -rf testdb logfile
rm -rf cadir
rm -f *.crt *.key *.pk8
rm -f users.txt pgbouncer.log bouncer.ini authfunc.sql

# adjust as necessary
PATH=/usr/pgsql-11/bin:$PATH
export PATH


./make-root-ca.sh
./make-intermediate-ca.sh
./make-leaf-ca.sh

CERTHOSTS=localhost ./make-server-cert.sh
CERTUSER=testuser ./make-client-cert.sh

initdb -A trust testdb > /dev/null

cat >> testdb/postgresql.conf <<-EOF
	unix_socket_directories = '/tmp'
	port = 5678
	ssl = on
	ssl_ca_file = 'root.crt'
	log_connections = on
	log_statement = 'all'
EOF

cat > testdb/pg_hba.conf <<-EOF
	local				 all	all						peer
	hostssl				 all	all		127.0.0.1/32	cert
	hostssl				 all	all		::1/128			cert
EOF

cp server.crt server.key root.crt testdb

pg_ctl -s -D testdb -l logfile start

createuser -h /tmp -p 5678 testuser
psql -q -h /tmp -p 5678 -c 'create extension sslinfo' postgres


# the money shot. If this works it's all working

echo 'Direct connection to Postgres using client cert'
psql "host=localhost port=5678 dbname=postgres user=testuser sslmode=verify-full sslcert=client.crt sslkey=client.key sslrootcert=root.crt" -c "select ssl_is_used()"

# now set up for pgbouncer

for f in curly larry mo
do
	createuser -h /tmp -p 5678 $f
	CERTUSER=$f ./make-client-cert.sh
	mv client.crt $f.crt
	mv client.key $f.key
	mv client.pk8  $f.pk8
	echo "bouncer pgbouncer $f" >> testdb/pg_ident.conf
	echo "\"$f\" \"\"" >> users.txt
done
	
CERTUSER=pgbouncer ./make-client-cert.sh
mv client.crt pgbouncer.crt
mv client.key pgbouncer.key
mv client.pk8  pgbouncer.pk8
echo '"pgbouncer" ""' >> users.txt

sed -i '/hostssl/ s/$/ map=bouncer/' testdb/pg_hba.conf
	
pg_ctl -s -D testdb -l logfile reload

cat > bouncer.ini <<-EOF
	[databases]
	* = host=localhost port=5678
	[pgbouncer]
	listen_port = 6543
	listen_addr = *
	auth_type = cert
	auth_file = users.txt
	logfile = pgbouncer.log
	pidfile = pgbouncer.pid
	admin_users = pgbouncer
	client_tls_sslmode = verify-full
	client_tls_cert_file = server.crt
	client_tls_key_file = server.key
	client_tls_ca_file = root.crt
	client_tls_protocols = secure
	server_tls_sslmode = verify-full
	server_tls_cert_file = pgbouncer.crt
	server_tls_key_file = pgbouncer.key
	server_tls_ca_file = root.crt
	server_tls_protocols = secure
	
EOF

pgbouncer -d bouncer.ini

# the money shot (again) . If this works it's all working
echo 'pgbouncer connection to Postgres using client cert and named users'
psql "host=localhost port=6543 dbname=postgres user=larry sslmode=verify-full sslcert=larry.crt sslkey=larry.key sslrootcert=root.crt" -c "select ssl_is_used()"


# now set up the auth_user query
# this means pgbouncer doesn't need to know about the
# users at all, it gets them from the database.

echo "bouncer pgbouncer pgbouncer" >> testdb/pg_ident.conf

# note that this wipes out the list of users, no more curly
# larry and mo. But they will still be able to connect 
echo '"pgbouncer" ""' > users.txt
createuser -h /tmp -p 5678 pgbouncer

cat > authfunc.sql <<-'EOF'

create or replace function auth_user_info
	   (username in out name, password out text)
returns record
language sql
security definer
as
$func$
 SELECT usename, passwd FROM pg_shadow WHERE usename=$1
$func$;
grant execute on function auth_user_info to pgbouncer;
EOF

psql -q -h /tmp -p 5678 -f authfunc.sql postgres

echo "auth_user = pgbouncer" >> bouncer.ini
echo "auth_query = select * from auth_user_info(\$1)" >> bouncer.ini

pg_ctl -s -D testdb -l logfile reload
kill `cat pgbouncer.pid`
pgbouncer -d bouncer.ini

echo 'pgbouncer connection to Postgres using client cert and auth_query'
psql "host=localhost port=6543 dbname=postgres user=larry sslmode=verify-full sslcert=larry.crt sslkey=larry.key sslrootcert=root.crt" -c "select ssl_is_used()"

kill `cat pgbouncer.pid`

pg_ctl -s -D testdb -l logfile stop

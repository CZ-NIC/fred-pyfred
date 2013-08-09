#!/bin/sh
# export FRED_CLIENT='fred-client -f /var/opt/fred2013-06-03/root/etc/fred/fred-client.conf'
# export FREDDB='psql -p 26100 -h /var/opt/fred2013-06-03/root/nofred/pg_sockets -U fred fred'
# pyfred$ pyfred/unittests/domainbrowser/create-db-objects.sh

SCRIPTPATH=$(dirname $(readlink -f $0))
UNITTEST_PATH=$(realpath $SCRIPTPATH/..)

#FREDDB_PORT= - this variable will be set by setup.py
#FREDDB_HOST= - this variable will be set by setup.py to: FREDDB_HOST=/var/opt/fred/root/nofred/pg_sockets
#FREDDB= - this variable will be set by setup.py to: FREDDB="psql -p $FREDDB_PORT -h $FREDDB_HOST -U fred fred"
#FRED_CLIENT= - this variable will be set by setup.py to: FRED_CLIENT="fred-client -f /var/opt/fred/root/etc/fred/fred-client.conf"

if [ -z "$FREDDB" -o -z "$FREDDB_PORT" -o -z "$FREDDB_HOST" ]; then
    echo "Error: Some of environment variables missing: FREDDB, FREDDB_PORT, FREDDB_HOST."
    echo "Example:"
    echo "export FREDDB_PORT=26100"
    echo "export FREDDB_HOST=/var/opt/fred/root/nofred/pg_sockets"
    echo 'export FREDDB="psql -p $FREDDB_PORT -h $FREDDB_HOST -U fred fred"'
    echo "export FRED_CLIENT='/var/opt/fred/root/bin/fred-client -f /var/opt/fred/root/etc/fred/fred-client.conf'"
    exit 1
fi
echo "FREDDB: $FREDDB"

if [ -z "$FRED_CLIENT" ]; then
    FRED_CLIENT='fred_client'
fi
echo "FRED_CLIENT: $FRED_CLIENT"

# contacts:
$FRED_CLIENT -xd "create_contact CONTACT 'Freddy First' freddy.first@nic.czcz 'Wallstreet 16/3' 'New York' 12601 CZ NULL 'Company Fred s.p.z.o.' NULL +420.726123455 +420.726123456 (y (email, voice)) CZ1234567889 (84956250 op) freddy+notify@nic.czcz"
$FRED_CLIENT -xd "create_contact CIHAK 'Řehoř Čihák' rehor.cihak@nic.czcz 'Přípotoční 16/3' 'Říčany u Prahy' 12601 CZ NULL 'Firma Čihák a spol.' NULL +420.726123456 +420.726123455 (y (email, voice)) CZ1234567890 (84956251 op) cihak+notify@nic.czcz"
$FRED_CLIENT -xd "create_contact PEPA 'Pepa Zdepa' pepa.zdepa@nic.czcz 'U práce 453' 'Praha' 12300 CZ NULL 'Firma Pepa s.r.o.' NULL +420.726123457 +420.726123454 (y (email, voice)) CZ1234567891 (84956252 op) pepa+notify@nic.czcz"
$FRED_CLIENT -xd "create_contact ANNA 'Anna Procházková' anna.prochazkova@nic.czcz 'Za želvami 32' 'Louňovice' 12808 CZ NULL NULL NULL +420.726123458 +420.726123453 (y (email, voice)) CZ1234567892 (84956253 op) anna+notify@nic.czcz"
$FRED_CLIENT -xd "create_contact FRANTA 'František Kocourek' franta.kocourek@nic.czcz 'Žabovřesky 4567' 'Brno' 18000 CZ NULL NULL NULL +420.726123459 +420.726123452 (y (email, voice)) CZ1234567893 (84956254 op) franta+notify@nic.czcz"
$FRED_CLIENT -xd "create_contact TESTER 'Tomáš Tester' tomas.tester@nic.czcz 'Testovní 35' 'Plzeň' 16200 CZ NULL NULL NULL +420.726123460 +420.726123451 (y (email, voice)) CZ1234567894 (84956253 op) tester+notify@nic.czcz"
$FRED_CLIENT -xd "create_contact BOB 'Bobeš Šuflík' bobes.suflik@nic.czcz 'Báňská 35' 'Domažlice' 18200 CZ NULL NULL NULL +420.726123461 +420.726123450 (y (email, voice)) CZ1234567895 (84956252 op) bob+notify@nic.czcz"

CONTACT=TESTER

tmpfile=`mktemp`

# Set validatedContact to $CONTACT
# identifiedContact=22, validatedContact=23
STATE_ID=23
echo "SELECT id FROM object_registry WHERE name = '$CONTACT' \g $tmpfile" | $FREDDB -A -t
REG_ID=`cat $tmpfile`
echo "Registry ID for handle '$CONTACT' is $REG_ID. Set status ID $STATE_ID."
# Run insert in the separate transaction:
echo "INSERT INTO object_state_request_lock (state_id, object_id) VALUES ($STATE_ID, $REG_ID);" | $FREDDB
echo "
SELECT lock_object_state_request_lock($STATE_ID, $REG_ID);
INSERT INTO object_state_request (object_id, state_id, valid_from) VALUES ($REG_ID, $STATE_ID, CURRENT_TIMESTAMP);
SELECT update_object_states($REG_ID);
" | $FREDDB

# nssets:
for pos in `seq 10`; do
    $FRED_CLIENT -xd "create_nsset nssid$(printf '%02d' $pos) ((ns1.domain.cz (217.31.207.130, 217.31.207.129)), (ns2.domain.cz (217.31.206.130, 217.31.206.129))) ($CONTACT, anna)"
done

# keysets:
for pos in `seq 10`; do
    $FRED_CLIENT -xd "create_keyset keyid$(printf '%02d' $pos) ((257 3 5 AwEAAddt2AkLfYGKgiEZB5SmIF8EvrjxNMH6HtxWEA4RJ9Ao6LCWheg8)) () ($CONTACT, anna)"
done

# domains:
for pos in `seq 10`; do
    $FRED_CLIENT -xd "create_domain nic$(printf '%02d' $pos).cz $CONTACT heslo nssid01 keyid01 (3 y) (anna $CONTACT)"
done

for pos in `seq 10`; do
    $FRED_CLIENT -xd "create_domain ginger$(printf '%02d' $pos).cz anna heslo nssid01 keyid01 (3 y) ($CONTACT)"
done

for enum in `seq 420222548111 $((420222548111 + 10))`; do
    $FRED_CLIENT -xd "create_domain $(echo $enum | rev | fold -w1 | tr '\n' '.')e164.arpa $CONTACT NULL nssid01 keyid01 () (anna, bob) $(date -d '5 month' +'%Y-%m-%d')"
done

# Set serverBlocked to the handles: FRANTA, NSSID05, KEYID05, nic05.cz
# serverBlocked=7
STATE_ID=7
for HANDLE in FRANTA NSSID05 KEYID05 nic05.cz
do
    echo "SELECT id FROM object_registry WHERE name = '$HANDLE' \g $tmpfile" | $FREDDB -A -t
    REG_ID=`cat $tmpfile`
    echo "Registry ID for handle '$HANDLE' is $REG_ID. Set status ID $STATE_ID."
    # Run insert in the separate transaction:
    echo "INSERT INTO object_state_request_lock (state_id, object_id) VALUES ($STATE_ID, $REG_ID);" | $FREDDB
    echo "
        SELECT lock_object_state_request_lock($STATE_ID, $REG_ID);
        INSERT INTO object_state_request (object_id, state_id, valid_from) VALUES ($REG_ID, $STATE_ID, CURRENT_TIMESTAMP);
        SELECT update_object_states($REG_ID);
    " | $FREDDB
done

rm $tmpfile

pg_dump -p $FREDDB_PORT -h $FREDDB_HOST -U fred fred > $UNITTEST_PATH/dbdata/fred.dump.sql
echo "New database dump saved at $UNITTEST_PATH/dbdata/fred.dump.sql"
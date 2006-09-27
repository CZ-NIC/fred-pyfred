#!/bin/sh
#
# Script creating zone files for zones:
#	cz
#	0.2.4.e164.arpa
#	0.2.4.c.e164.arpa
#
LOG=/var/log/genzone.log
CMD="python /usr/local/ccRegUtils/genzone_client.py"
ZONES="cz 0.2.4.e164.arpa 0.2.4.c.e164.arpa"
RESTART_CMD="/etc/init.d/bind restart"
TESTNAME="kolibrik"


# generate new zone files
echo "Starting zones generation (`date`)" >>$LOG
ERROR_SEEN=0
for zone in $ZONES
do
	echo -n "Zone $zone ... (" >>$LOG
	$CMD --ns localhost --output /etc/bind/db.${zone}.$$ ${zone} 2>&1 >>$LOG
	RC=$?
	if [ $RC -eq 0 ]
	then
		echo ") ok" >>$LOG
		if test x`hostname` == x"$TESTNAME"
		then
			echo ";" > /etc/bind/db.${zone}
			echo "; ---------------------------------------------" >> /etc/bind/db.${zone}
			echo "; All data contained in the zone are test data." >> /etc/bind/db.${zone}
			echo "; Vsechna data obsazena v zone jsou testovaci."  >> /etc/bind/db.${zone}
			echo "; ---------------------------------------------" >> /etc/bind/db.${zone}
			echo ";" >> /etc/bind/db.${zone}
			cp /etc/bind/db.${zone}.$$ /etc/bind/backup/db.${zone}.`date +%s`
			cat /etc/bind/db.${zone}.$$ >>/etc/bind/db.${zone}
			rm /etc/bind/db.${zone}.$$
		fi
		cp /etc/bind/db.${zone}.$$ /etc/bind/backup/db.${zone}.`date +%s`
		mv /etc/bind/db.${zone}.$$ /etc/bind/db.${zone}
	else
		echo ") failed ($RC)" >>$LOG
		ERROR_SEEN=1
	fi
done
echo "finished generation (`date`)" >>$LOG
if [ $ERROR_SEEN -eq 1 ]
then
	exit 1
fi
# restart bind if generation was ok
echo -n "Restarting BIND ..." >>$LOG
${RESTART_CMD}
if [ $? -eq 0 ]
then
	echo " ok" >>$LOG
else
	echo " failed" >>$LOG
fi

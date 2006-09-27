#/bin/sh

PROGNAME=pyccReg.py
ARGS=""
PIDFILE="/tmp/pyccReg.pid"

function usage
{
	echo "$0 [start | stop | status]"
}

function is_running
{
	if [ -f $PIDFILE ]
	then
		PID=`cat $PIDFILE` 
		if [ `ps h -p $PID | wc -l` -gt 0 ]
		then
			return 1
		fi
		echo "Pid file out of date. Unclean shutdown?"
		rm -f $PIDFILE
	fi
	return 0
}

if [ $# -ne 1 ]
then
	usage
	exit 1
fi

echo "Tento skript neni zatim v pouzitelnem tvaru. Misto neho pouzij "
echo "prikaz 'python pyccReg.py' pro start a pro zastaveni vylistuj "
echo "pid (ps axu | grep python) a killni ten python co ma parameter "
echo "pyccReg.py."
exit 0

case $1 in
	start)
		is_running
		if [ $? -eq 1 ]
		then
			echo "$PROGNAME is already running"
			exit 1
		fi
		echo "Starting $PROGNAME"
		python $PROGNAME $ARGS &
		ps ax | grep "python $PROGNAME $ARGS" | awk '{print $1}' >$PIDFILE
		;;
	stop)
		is_running
		if [ $? -eq 1 ]
		then
			echo "Stoping $PROGNAME"
			if [ ps h -p `cat $PIDFILE` | awk '{print $1}' | xargs kill ]
			then
				rm -f $PIDFILE
			fi
		else
			echo "$PROGNAME is not running"
			exit 1
		fi
		;;
	status)
		is_running
		if [ $? -eq 1 ]
		then
			echo "$PROGNAME is running"
		else
			echo "$PROGNAME is not running"
		fi
		;;
	*)
		usage
		exit 1
		;;
esac

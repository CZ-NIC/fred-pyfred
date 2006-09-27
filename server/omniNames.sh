#/bin/sh

function usage
{
	echo "$0 [start | stop | status]"
}

function is_running
{
	if [ `ps axc | grep omniNames | wc -l` -gt 0 ]
	then
		return 1
	fi
	return 0
}

if [ $# -ne 1 ]
then
	usage
	exit 1
fi

case $1 in
	start)
		is_running
		if [ $? -eq 1 ]
		then
			echo "omniNames is already running"
			exit 1
		fi
		echo "Starting omniNames"
		rm -f omninames*
		omniNames -start -logdir `pwd` -errlog omniNames.log &
		;;
	stop)
		is_running
		if [ $? -eq 1 ]
		then
			echo "Stoping omniNames"
			killall omniNames
			rm -f omninames*
		else
			echo "omniNames is not running"
			exit 1
		fi
		;;
	status)
		is_running
		if [ $? -eq 1 ]
		then
			echo "omniNames is running"
		else
			echo "omniNames is not running"
		fi
		;;
	*)
		usage
		exit 1
		;;
esac

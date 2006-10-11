#!/bin/sh
#####
##### Script for creating zone files for zones ${ZONES}
#####


LOG_FILE="/var/log/genzone.log";
DEBUG_FILE="/var/log/genzone.dbg"

BIND_DIR="/etc/bind";
BACKUP_DIR="${BIND_DIR}/backup";
TEMP_DIR="${BIND_DIR}/tmp";

ERROR=0


PREFIX="`date "+%Y-%m-%d %k:%M:%S"` `hostname`";
if basename ${0} &> /dev/null;
  then PREFIX="${PREFIX} `basename ${0}`";
  else PREFIX="${PREFIX} ${0##*/}";
fi
PREFIX="${PREFIX}[${GPID}]:"


##### Include configuration
. /etc/default/genzones


##### Generation of zones
MESSAGE="${PREFIX} Starting zones generation.";
for ZONE in ${ZONES};
do {
  ZONE_FILE_TMP="${TEMP_DIR}/db.${ZONE}.$$";
  ZONE_FILE_BACKUP="${BACKUP_DIR}/db.${ZONE}.$$.`date +%s`";
  ZONE_FILE_REAL="${BIND_DIR}/db.${ZONE}";

  ZONE_FILE_PREFIX=`echo ZONE_${ZONE}_PREFIX | tr '.-' '__' `;
  ZONE_FILE_PREFIX="${!ZONE_FILE_PREFIX}";

  ZONE_FILE_POSTFIX=`echo ZONE_${ZONE}_POSTFIX | tr '.-' '__' `;
  ZONE_FILE_POSTFIX="${!ZONE_FILE_POSTFIX}";


  ##### Insert zone's file prefix if it have exist
  if [ -n "${ZONE_FILE_PREFIX}" ]
    then
    {
      MESSAGE="${MESSAGE}\n${PREFIX} Prepending zone's '${ZONE}' temporary file by some prefix:";
      DEBUG_TMP=`cat ${ZONE_FILE_PREFIX} 2>&1 > ${ZONE_FILE_TMP}`;
      STATUS=$?;

      if [ ${STATUS} -ne 0 ];
	then
	{
	  MESSAGE="${MESSAGE} FAILED (with returned status ${STATUS})";
	  DEBUG="${DEBUG}\n${PREFIX}\n${DEBUG_TMP}";
	  ERROR=1;
	  continue;
	}
      fi
      MESSAGE="${MESSAGE} OK";
    }
  elif [ -e "${ZONE_FILE_TMP}" ];
    then
    {
      #### Remove existing zone's temporary file
      MESSAGE="${MESSAGE}\n${PREFIX} Removing old zone's '${ZONE}' temporary file:";
      DEBUG_TMP=`rm ${ZONE_FILE_TMP} 2>&1`;
      STATUS=$?;

      if [ ${STATUS} -ne 0 ];
        then
        {
          MESSAGE="${MESSAGE} FAILED (with returned status ${STATUS})";
          DEBUG="${DEBUG}\n${PREFIX}\n${DEBUG_TMP}";
          ERROR=1;
          continue;
        }
      fi
      MESSAGE="${MESSAGE} OK";
    }
  fi


  #### Generate a zone
  MESSAGE="${MESSAGE}\n${PREFIX} Generating zone '${ZONE}':";
  DEBUG_TMP=`${GENZONE_COMMAND} ${ZONE} 2>&1 >> ${ZONE_FILE_TMP}`;
  STATUS=$?;

  if [ ${STATUS} -ne 0 ];
    then
    {
      MESSAGE="${MESSAGE} FAILED (with returned status ${STATUS})";
      DEBUG="${DEBUG}\n${PREFIX}\n${DEBUG_TMP}";
      ERROR=1;
      continue;
    }
  fi
  MESSAGE="${MESSAGE} OK";


  ##### Append zone's file ppostfix if it have exist
  if [ -n "${ZONE_FILE_POSTFIX}" ]
    then
    {
      MESSAGE="${MESSAGE}\n${POSTFIX} Appending zone's '${ZONE}' temporary file by some postfix:";
      DEBUG_TMP=`cat ${ZONE_FILE_POSTFIX} 2>&1 >> ${ZONE_FILE_TMP}`;
      STATUS=$?;

      if [ ${STATUS} -ne 0 ];
	then
	{
	  MESSAGE="${MESSAGE} FAILED (with returned status ${STATUS})";
	  DEBUG="${DEBUG}\n${PREFIX}\n${DEBUG_TMP}";
	  ERROR=1;
	  continue;
	}
      fi
      MESSAGE="${MESSAGE} OK";
    }
  fi


  ##### Copy output file to the backup directory
  MESSAGE="${MESSAGE}\n${PREFIX} Copying zone's '${ZONE}' temporary file to the backup directory:";
  DEBUG_TMP=`cp ${ZONE_FILE_TMP} ${ZONE_FILE_BACKUP} 2>&1`;
  STATUS=$?;

  if [ ${STATUS} -ne 0 ];
    then
    {
      MESSAGE="${MESSAGE} FAILED (with returned status ${STATUS})";
      DEBUG="${DEBUG}\n${PREFIX}\n${DEBUG_TMP}";
      ERROR=1;
      continue;
    }
  fi
  MESSAGE="${MESSAGE} OK";


  ##### check validity of the generated zone file
  MESSAGE="${MESSAGE}\n${PREFIX} Checking validity of '${ZONE}' file:";
  DEBUG_TMP=`/usr/sbin/named-checkzone ${ZONE} ${ZONE_FILE_TMP}`
  STATUS=$?;

  if [ ${STATUS} -ne 0 ];
    then
    {
      MESSAGE="${MESSAGE} FAILED (with returned status ${STATUS})";
      DEBUG="${DEBUG}\n${PREFIX}\n${DEBUG_TMP}";
      ERROR=1;
      continue;
    }
  fi
  MESSAGE="${MESSAGE} OK";


  ##### Move output file to the real path
  MESSAGE="${MESSAGE}\n${PREFIX} Moving zone's '${ZONE}' temporary file to the real path:";
  DEBUG_TMP=`mv ${ZONE_FILE_TMP} ${ZONE_FILE_REAL} 2>&1`;
  STATUS=$?;

  if [ ${STATUS} -ne 0 ];
    then
    {
      MESSAGE="${MESSAGE} FAILED (with returned status ${STATUS})";
      DEBUG="${DEBUG}\n${PREFIX}\n${DEBUG_TMP}";
      ERROR=1;
      continue;
    }
  fi
  MESSAGE="${MESSAGE} OK";

} done;


if [ ${ERROR} -eq 1 ]
  then
  {
    MESSAGE="${MESSAGE}\n${PREFIX} Finished all zones generation with FAILURE.";
    echo -e "${MESSAGE}" >> ${LOG_FILE};
    echo -e "\n${DEBUG}" >> ${DEBUG_FILE};
    echo -e "${MESSAGE}\n${DEBUG}";
    exit 1;
  }
fi
MESSAGE="${MESSAGE}\n${PREFIX} Successfully finished all zones generation.";


##### Reload nameserver
MESSAGE="${MESSAGE}\n${PREFIX} Restarting name server:";
DEBUG_TMP=`${NAMESERVER_RESTART_COMMAND} 2>&1`;
STATUS=$?;

if [ ${STATUS} -eq 0 ];
  then MESSAGE="${MESSAGE} OK";
  else
  {
    MESSAGE="${MESSAGE} FAILED (command '${RESTART_CMD}' returned status '${STATUS}')";
    DEBUG="${DEBUG}\n${PREFIX}\n${DEBUG_TMP}";
    ERROR=1;
  }
fi


##### Print logging and debug messages
echo -e "${MESSAGE}" >> ${LOG_FILE};
if [ ${ERROR} -eq 1 ];
  then
  {
    echo -e "\n${DEBUG}" >> ${DEBUG_FILE};
    echo -e "${MESSAGE}\n${DEBUG}";
  }
fi
exit 0;

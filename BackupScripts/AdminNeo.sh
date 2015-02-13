#!/bin/bash
######################################################################################################################################
# FILE: AdminNeo.sh
# Created by Zachary Krakov on 4/24/2014.
######################################################################################################################################
# SCRIPT VARIABLES
######################################################################################################################################
alias noco='sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"'
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin
export THIS_NAME="NEO_ADMIN"
export SERVICE_NAME="Neo4j"

#NEO4J SPECIFIC
export NEO_ROOT="/usr/local/neo4j/neo4j-enterprise-1.9.7"
export BACKUP_PREFIX="Prod-Neo4j"
export BACKUP_ROOT_DIR="/root/Daily"
export REMOTE_ADMIN_SUCCCESS=0

export ANALYTICS_ADMIN="true"
export ANALYTICS_DELIVERY="true"
export ANALYTICS_SERVER="$YOUR_SERVERS_FQDN"

# export GRAPH4_ADMIN="true"
# export GRAPH4_DELIVERY="true"
# export GRAPH4_SERVER="$YOUR_SERVERS_FQDN"

. MainFunctions.sh

REMOTEADMIN1=0

######################################################################################################################################
# NEO4J ADMINISTRATION
######################################################################################################################################
TOTALSTARTADMIN=$(date +"%s")
cd $BACKUP_ROOT_DIR
echo "$(logdate) Beginning $ENVIRONMENT $SERVICE_NAME Administration Operations" | tee -a $SESSION_LOG
#-------------------------------------------------------------------------------------------------------------------------------------
if [ "$ANALYTICS_ADMIN" == 'true' ]; then
	START1ADMIN=$(date +"%s")
	remote_admin "root" "$ANALYTICS_SERVER" "$NEO_ROOT/data"
	STOP1ADMIN=$(date +"%s")
	echo "$(logdate) $ENVIRONMENT $SERVICE_NAME Administration to $ANALYTICS_SERVER completed in $(calc_time $STOP1ADMIN $START1ADMIN)" | tee -a $SESSION_LOG
	DURATION1="$ANALYTICS_SERVER elapsed administration time: $(calc_time $STOP1ADMIN $START1ADMIN)"
	REMOTEADMIN1=$REMOTE_ADMIN_SUCCCESS
	if [ $REMOTEADMIN1 -eq 0 ]; then
		echo "$(logdate) Sending Remote Admin Status message for $ANALYTICS_SERVER" | tee -a $SESSION_LOG
		subject="$ENVIRONMENT $SERVICE_NAME Administration Error on $ANALYTICS_SERVER"
		highlightoutput "$SSH_SESSION"
		simple_msg "$subject" "<h3>$ORG_NAME $subject</h3><p>$DURATION1</p><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre>" "[$THIS_NAME]"
		rm -f $SSH_SESSION
	fi
fi
######################################################################################################################################
# SUMMARY
######################################################################################################################################
TOTALSTOPADMIN=$(date +"%s")
DURATION="Neo4j Database Administration successfully completed in $(calc_time $TOTALSTOPADMIN $TOTALSTARTADMIN)"
echo "$(logdate) Completed $ENVIRONMENT $SERVICE_NAME Administration Operations in $(calc_time $TOTALSTOPADMIN $TOTALSTARTADMIN)" | tee -a $SESSION_LOG

if [ $REMOTEADMIN1 -eq 1 ]; then
	highlightoutput "$SESSION_LOG"
	simple_msg "$ENVIRONMENT $SERVICE_NAME Administration completed successfully" "<h3>$ORG_NAME $ENVIRONMENT $SERVICE_NAME Administration completed successfully</h3><p>$DURATION</p><ul><li>$DURATION1</li></ul><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre>" "[$THIS_NAME]"
# else
# 	simple_msg "$ENVIRONMENT $SERVICE_NAME Administration Error" "<h3>$ORG_NAME $ENVIRONMENT $SERVICE_NAME Administration encountered an error</h3><p>$DURATION</p><h3>PROCESS LOG:</h3><pre>$sessionlog_contents</pre>" "[$THIS_NAME]"
fi

cat $SESSION_LOG >> $PERSIST_LOG

# FINISHING OPTIONS AND COMMANDS
finishing_options

exit 0

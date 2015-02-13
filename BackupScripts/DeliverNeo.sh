#!/bin/bash
######################################################################################################################################
# FILE: DeliverNeo.sh
# Created by Zachary Krakov on 4/24/2014.
######################################################################################################################################
# SCRIPT VARIABLES
######################################################################################################################################
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin
export THIS_NAME="NEO_DELIVERY"
export SERVICE_NAME="Neo4j"

#NEO4J SPECIFIC
export NEO_ROOT='/usr/local/neo4j/neo4j-enterprise-1.9.7'
export BACKUP_PREFIX="Prod-Neo4j"
export BACKUP_ROOT_DIR="/root/Daily"
export ANALYTICS_SERVER="$YOUR_SERVERS_FQDN"
export ANALYTICS_DELIVERY="true"
# export GRAPH4_SERVER="$YOUR_SERVERS_FQDN"
# export GRAPH4_DELIVERY="true"

. MainFunctions.sh

transferstats1=""
transferstats2=""
DELIVERY1=0
# DELIVERY2=0
######################################################################################################################################
# NEO4J DELIVERY
######################################################################################################################################
TOTALSTART=$(date +"%s")
cd $BACKUP_ROOT_DIR
#-------------------------------------------------------------------------------------------------------------------------------------
if [ "$ANALYTICS_DELIVERY" == 'true' ]; then
	
	START1=$(date +"%s")
	deliver_db "root" "$ANALYTICS_SERVER"
	STOP1=$(date +"%s")
	
	echo "$(logdate) Neo4j database upload to $ANALYTICS_SERVER completed in $(calc_time $STOP1 $START1)" | tee -a $SESSION_LOG
	duration1="$ANALYTICS_SERVER elapsed upload time: $(calc_time $STOP1 $START1)"
	transfer1="$(cat $SCP_FILE | grep 'Transferred: ' --color=never | awk '{print $3}' | sed 's/,//g')"
	perftime1="$(cat $SCP_FILE | grep 'Transferred: ' --color=never | awk '{print $8}')"
	netspeed1="$(cat $SCP_FILE | grep 'Bytes per second: ' --color=never | awk '{print $5}' | sed 's/,//g')"
	summary_1="Transferred $(human_filesize $transfer1) in $perftime1 seconds at $(human_filesize $netspeed1)/sec"
	echo "$(logdate) Transferred $(human_filesize $transfer1) in $perftime1 seconds at $(human_filesize $netspeed1)/sec" | tee -a $SESSION_LOG
	
	transferstats1="<li>$duration1</li><ul><li>$summary_1</li><li>Bytes Transferred: $transfer1</li></ul>"
	if [ $SCP_SUCCESS -eq 1 ]; then
		highlightoutput "$SCP_FILE"
		simple_msg "$ENVIRONMENT $SERVICE_NAME database successfully uploaded to $ANALYTICS_SERVER" "<h3>Crunch<span style='color: #3C8C9D'>Base</span> $ENVIRONMENT $SERVICE_NAME database successfully uploaded to $ANALYTICS_SERVER</h3><p>$duration</p><ul>$transferstats1</ul><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre>" "[$THIS_NAME]"
		DELIVERY1=$SCP_SUCCESS
	fi
fi
#-------------------------------------------------------------------------------------------------------------------------------------
# if [ "$GRAPH4_DELIVERY" == 'true' ]; then
# 	
# 	START2=$(date +"%s")
# 	deliver_db "root" "$GRAPH4_SERVER"
# 	STOP2=$(date +"%s")
# 	
# 	echo "$(logdate) Neo4j database upload to $GRAPH4_SERVER completed in $(calc_time $STOP2 $START2)" | tee -a $SESSION_LOG
# 	duration2="$GRAPH4_SERVER elapsed upload time: $(calc_time $STOP2 $START2)"
# 	transfer2="$(cat $SCP_FILE | grep 'Transferred: ' --color=never | awk '{print $3}' | sed 's/,//g')"
# 	perftime2="$(cat $SCP_FILE | grep 'Transferred: ' --color=never | awk '{print $8}')"
# 	netspeed2="$(cat $SCP_FILE | grep 'Bytes per second: ' --color=never | awk '{print $5}' | sed 's/,//g')"
# 	summary_2="Transferred $(human_filesize $transfer2) in $perftime2 seconds at $(human_filesize $netspeed2)/sec"
# 	echo "$(logdate) Transferred $(human_filesize $transfer2) in $perftime2 seconds at $(human_filesize $netspeed2)/sec" | tee -a $SESSION_LOG
# 	
# 	transferstats2="<li>$duration2</li><ul style='font-size: 0.9em;'><li>$summary_2</li><li>Bytes Transferred: $transfer2</li></ul>"
# 	if [ $SCP_SUCCESS -eq 1 ]; then
# 		simple_msg "$ENVIRONMENT $SERVICE_NAME database successfully uploaded to $GRAPH4_SERVER" "<h3>Crunch<span style='color: #3C8C9D'>Base</span> $ENVIRONMENT $SERVICE_NAME database successfully uploaded to $GRAPH4_SERVER</h3><p>$duration</p><ul>$transferstats2</ul><h3>PROCESS LOG:</h3><pre>$(cat $SCP_FILE)</pre>" "[$THIS_NAME]"
# 		DELIVERY2=$SCP_SUCCESS
# 	fi
# fi

######################################################################################################################################
# SUMMARY
######################################################################################################################################
TOTALSTOP=$(date +"%s")
TOTALDURATION="$SERVICE_NAME database delivery successfully completed in $(calc_time $TOTALSTOP $TOTALSTART)"
echo "$(logdate) $SERVICE_NAME database delivery successfully completed in $(calc_time $TOTALSTOP $TOTALSTART)" | tee -a $SESSION_LOG


if [ $DELIVERY1 -ne 1 ]	; then
# 	echo "$(logdate) $SERVICE_NAME delivery successfully completed on all downstream servers" | tee -a $SESSION_LOG
# 	highlightoutput "$SESSION_LOG"
# 	simple_msg "$ENVIRONMENT $SERVICE_NAME successfully delivered to all servers" "<h3>Crunch<span style='color: #3C8C9D'>Base</span> $ENVIRONMENT $SERVICE_NAME database delivery successful</h3><p>$duration</p><ul>$transferstats1</ul><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre>" "[$THIS_NAME]"
# else
	highlightoutput "$SESSION_LOG"
	simple_msg "$ENVIRONMENT $SERVICE_NAME couldn't be delivered to all servers" "<h3>Crunch<span style='color: #3C8C9D'>Base</span> $ENVIRONMENT $SERVICE_NAME couldn't be delivered to all servers</h3><p>$duration</p><ul>$transferstats1</ul><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre>" "[$THIS_NAME]"
fi

cat $SESSION_LOG >> $PERSIST_LOG

# FINISHING OPTIONS AND COMMANDS
finishing_options

exit 0
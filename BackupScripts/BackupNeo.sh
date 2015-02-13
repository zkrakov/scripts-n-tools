#!/bin/bash
######################################################################################################################################
# FILE: BackupNeo.sh
# Created by Zachary Krakov on 4/24/2014.
######################################################################################################################################
# SCRIPT VARIABLES
######################################################################################################################################
alias noco='sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"'
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin
export THIS_NAME="NEO_BACKUPS"
export SERVICE_NAME="Neo4j"
export BACKUP_SUCCESS=0
export S3_SUCCESS=0

#NEO4J SPECIFIC
export NEO_ROOT="/usr/local/neo4j/neo4j-enterprise-1.9.8"
export NEO_CONSISTENCY_LOG="/tmp/neo4j-backup-consistency-report.txt"
export BACKUP_PREFIX="Prod-Neo4j"
export BACKUP_ROOT_DIR="/root/Daily"

# AWS S3 BUCKET
export S3_BUCKET="s3://DEFINE_S3_BUCKET/"

# Source function library
. MainFunctions.sh

######################################################################################################################################
# NEO4J BACKUP
######################################################################################################################################
START=$(date +"%s")
cd $BACKUP_ROOT_DIR
echo "$(logdate) Beginning $ENVIRONMENT $SERVICE_NAME Backup Operations" | tee -a $SESSION_LOG
#echo "$(logdate) Directory Size of $NEO_ROOT/data/graph.db: $(du -hs $NEO_ROOT/data/graph.db | awk '{print $1'})"
neodata_4_jenkins
if [ -d $CURRENT_BACKUP ]; then
	echo "$(logdate) Directory Size of existing $CURRENT_BACKUP: $(du -hs $CURRENT_BACKUP | awk '{print $1'})"
	echo "$(logdate) Removing existing Backup $CURRENT_BACKUP" | tee -a $SESSION_LOG
	if ! /usr/bin/time -v rm -rf $CURRENT_BACKUP 2>&1 | tee -a $SESSION_LOG; then
		status="ERROR: Removing $CURRENT_BACKUP from $BACKUP_ROOT_DIR"
	else
		status="SUCCESS: Removed $CURRENT_BACKUP from $BACKUP_ROOT_DIR"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
fi
mkdir -p $CURRENT_BACKUP
echo "$(logdate) Performing full $ENVIRONMENT $SERVICE_NAME backup on $(hostname -f) into directory $CURRENT_BACKUP" | tee -a $SESSION_LOG
# ------------------------------------------------------------------------------------------------------------------------------------
ssh root@rundeck1 "(echo '$(logdate) De-Register Graph5 from ELB'; aws elb deregister-instances-from-load-balancer --load-balancer-name Production-Neo4j-Read --instance i-a8b194f6)" | tee -a $SESSION_LOG
echo "$(logdate) Beginning $ENVIRONMENT $SERVICE_NAME Backup Operations" | tee -a $SESSION_LOG
if ! $NEO_ROOT/bin/neo4j-backup -from single://127.0.0.1 -to $CURRENT_BACKUP 2>&1 | tee -a $SESSION_LOG; then
	BACKUP_SUCCESS=0
	echo "$(logdate) $ENVIRONMENT $SERVICE_NAME Backup process may have experienced an error" | tee -a $SESSION_LOG
else
	BACKUP_SUCCESS=1
	echo "$(logdate) $ENVIRONMENT $SERVICE_NAME Backup Successfully completed on $(hostname -f)" | tee -a $SESSION_LOG
fi
ssh root@rundeck1 "(echo '$(logdate) Registering Graph5 with ELB'; aws elb register-instances-with-load-balancer --load-balancer-name Production-Neo4j-Read --instance i-a8b194f6)" | tee -a $SESSION_LOG
# ------------------------------------------------------------------------------------------------------------------------------------
tar_current_db
# ------------------------------------------------------------------------------------------------------------------------------------
s3operations
# ------------------------------------------------------------------------------------------------------------------------------------

if [ -d "$OBSOLETE_BACKUP" ]; then
	remove_obsolete
fi
######################################################################################################################################
# DELIVERY AND NOTIFICATION
######################################################################################################################################
STOP=$(date +"%s")
DURATION="The $ENVIRONMENT $SERVICE_NAME Backup Process took $(calc_time $STOP $START) to complete"
echo "$(logdate) Completed $ENVIRONMENT $SERVICE_NAME Backup in $(calc_time $STOP $START)" | tee -a $SESSION_LOG

if [ $NOTIFYLIST -eq 1 ]; then
	if [ $S3_SUCCESS -eq 1 ] && [ $BACKUP_SUCCESS -eq 1 ]; then
		notifysuccessmsg "$DURATION" "[$THIS_NAME] $ENVIRONMENT $SERVICE_NAME Database Successfully uploaded to S3"
	elif [ $S3_SUCCESS -eq 0 ] && [ $BACKUP_SUCCESS -eq 1 ]; then
		highlightoutput "$SESSION_LOG"
		simple_msg "[$THIS_NAME] $ENVIRONMENT $SERVICE_NAME Backup Completed on $(hostname -f) " "<h3>$ORG_NAME $ENVIRONMENT $SERVICE_NAME Database Backup Successfully Completed</h3><p>$DURATION</p><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre><br/>"
	else
		highlightoutput "$SESSION_LOG"
		simple_msg "[$THIS_NAME] $ENVIRONMENT $SERVICE_NAME Backup Error on $(hostname -f)" "<h3>$ORG_NAME $ENVIRONMENT $SERVICE_NAME Database Backup Error</h3><p>Please verify: ssh://$(hostname -f)</p><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre><br/>"
	fi
fi

cat $SESSION_LOG >> $PERSIST_LOG

# FINISHING OPTIONS AND COMMANDS
finishing_options

s3opslog "remove"
exit 0


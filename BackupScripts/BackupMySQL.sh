#!/bin/bash
######################################################################################################################################
# FILE: BackupMySQL.sh
# Created by Zachary Krakov on 4/24/2014.
######################################################################################################################################
# SCRIPT VARIABLES
######################################################################################################################################
alias noco='sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"'
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin
export THIS_NAME="MYSQL_BACKUPS"
export SERVICE_NAME="MySQL"
export BACKUP_SUCCESS=0
export S3_SUCCESS=0

# MySQL SPEIFIC
export BACKUP_PREFIX="Prod-MySQL"
export BACKUP_ROOT_DIR="/root/Daily"

# AWS S3 BUCKET
export S3_BUCKET="s3://DEFINE_S3_BUCKET/"

. MainFunctions.sh

export MYSQLDUMP_FILENAME="$THEHOUR"-"db_production.sql"
######################################################################################################################################
# MYSQL BACKUP
######################################################################################################################################
START=$(date +"%s")
cd $BACKUP_ROOT_DIR
echo "$(logdate) Beginning $ENVIRONMENT $SERVICE_NAME Backup Operations" | tee -a $SESSION_LOG
if [ ! 	-d "$CURRENT_BACKUP" ]; then
	echo "$(logdate) Creating Directory $CURRENT_BACKUP" | tee -a $SESSION_LOG
	mkdir -p $CURRENT_BACKUP
fi
#-------------------------------------------------------------------------------------------------------------------------------------
echo "$(logdate) Connecting to $ENVIRONMENT $SERVICE_NAME database" | tee -a $SESSION_LOG
if ! /usr/bin/time -v mysqldump --max_allowed_packet=1G --default-character-set=utf8 --single-transaction=TRUE --routines --events $1 > $MYSQLDUMP_FILENAME 2>&1 | tee -a $SESSION_LOG; then
	status="ERROR: $ENVIRONMENT $SERVICE_NAME Backup completed on $(hostname -f)"
	BACKUP_SUCCESS=0
else
	status="SUCCESS: $ENVIRONMENT $SERVICE_NAME Backup completed on $(hostname -f)"
	BACKUP_SUCCESS=1
fi
echo "$(logdate) $status" | tee -a $SESSION_LOG
#-------------------------------------------------------------------------------------------------------------------------------------
tar_current_mysql
#-------------------------------------------------------------------------------------------------------------------------------------
remove_currentmysql
#-------------------------------------------------------------------------------------------------------------------------------------
s3_mysqlput
#-------------------------------------------------------------------------------------------------------------------------------------
if [ -d "$OBSOLETE_BACKUP" ]; then
	remove_obsolete
fi
######################################################################################################################################
# NOTIFICATION
######################################################################################################################################
STOP=$(date +"%s")
DURATION="The $ENVIRONMENT $SERVICE_NAME Backup Process took $(calc_time $STOP $START) to complete"
echo "$(logdate) Completed $ENVIRONMENT $SERVICE_NAME Backup in $(calc_time $STOP $START)" | tee -a $SESSION_LOG

if [ $NOTIFYLIST -eq 1 ]; then
	if [ $S3_SUCCESS -eq 1 ] && [ $BACKUP_SUCCESS -eq 1 ]; then
		nicetobe=1
		notifysuccessmsg "$DURATION" "[$THIS_NAME] $ENVIRONMENT $SERVICE_NAME Database Successfully uploaded to S3"
	elif [ $BACKUP_SUCCESS -eq 1 ]; then
		nicetobe=1
		highlightoutput "$SESSION_LOG"
		simple_msg "$ENVIRONMENT $SERVICE_NAME Backup Successfully Completed on $(hostname -f) " "<h3>Crunch<span style='color: #3C8C9D'>Base</span> $ENVIRONMENT $SERVICE_NAME Database Backup Successfully Completed</h3><p>$DURATION</p><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre>" "[$THIS_NAME]"
	else
		nicetobe=1
		highlightoutput "$SESSION_LOG"
		simple_msg "$ENVIRONMENT $SERVICE_NAME Backup Error on $(hostname -f)" "<h3>Crunch<span style='color: #3C8C9D'>Base</span> $ENVIRONMENT $SERVICE_NAME Database Backup Error</h3><p>Please verify: ssh://$(hostname -f)</p><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre>" "[$THIS_NAME]"
	fi
fi
cat $SESSION_LOG >> $PERSIST_LOG

# FINISHING OPTIONS AND COMMANDS
finishing_options

s3opslog "remove"
exit 0
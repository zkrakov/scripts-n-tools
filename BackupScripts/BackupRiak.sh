#!/bin/bash
######################################################################################################################################
# FILE: BackupRiak.sh
# Created by Zachary Krakov on 4/24/2014.
# Copyright 2014 CrunchBase. All rights reserved.
######################################################################################################################################
# SCRIPT VARIABLES
######################################################################################################################################
alias noco='sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"'
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin
export THIS_NAME="RIAK_BACKUPS"
export SERVICE_NAME="Riak"
export BACKUP_SUCCESS=0
export S3_SUCCESS=0
export RIAK_LEVELDB="/var/lib/riak/leveldb"
export RIAK_RINGDIR="/var/lib/riak/ring"

# RISK SPECIFIC
export BACKUP_PREFIX="Prod-Riak"
export BACKUP_ROOT_DIR="/root/Daily"

# AWS S3 BUCKET
export S3_BUCKET="s3://DEFINE_S3_BUCKET/"

# Source function library
. MainFunctions.sh


######################################################################################################################################
# BACKUP RIAK
######################################################################################################################################
START=$(date +"%s")
cd $CURRENT_BACKUP
echo "$(logdate) Beginning $ENVIRONMENT $SERVICE_NAME backup operations on $(hostname -f)" | tee -a $SESSION_LOG
if [ ! -d "$CURRENT_BACKUP" ]; then
	mkdir -p $CURRENT_BACKUP
	echo "$(logdate) Creating directory $CURRENT_BACKUP on $(hostname -f)" | tee -a $SESSION_LOG
fi
# -------------------------------------------------------------------------------------------------------------------------------------
echo "$(logdate) Stopping $ENVIRONMENT $SERVICE_NAME Server on $(hostname -f)" | tee -a $SESSION_LOG
/etc/init.d/riak stop
# -------------------------------------------------------------------------------------------------------------------------------------
echo "$(logdate) Directory Size of $RIAK_LEVELDB: $(du -hs $RIAK_LEVELDB | awk '{print $1'})" | tee -a $SESSION_LOG
echo "$(logdate) Copying leveldb into $CURRENT_BACKUP" | tee -a $SESSION_LOG
echo -n "" > $CMD_OUTFILE
if ! /usr/bin/time -v cp -Rv $RIAK_LEVELDB $CURRENT_BACKUP/ >> $CMD_OUTFILE 2>&1; then
	leveldbcopy=0
	status="ERROR: Copying $RIAK_LEVELDB into $CURRENT_BACKUP"
else
	leveldbcopy=1
	status="SUCCESS: Copied $(cat $CMD_OUTFILE | wc -l) files from $RIAK_LEVELDB into $CURRENT_BACKUP"
fi
rm $CMD_OUTFILE
echo "$(logdate) Directory Size of $CURRENT_BACKUP: $(du -hs $CURRENT_BACKUP | awk '{print $1'})"
# -------------------------------------------------------------------------------------------------------------------------------------
echo "$(logdate) Directory Size of $RIAK_RINGDIR: $(du -hs $RIAK_RINGDIR | awk '{print $1'})" | tee -a $SESSION_LOG
echo "$(logdate) Copying ring into $CURRENT_BACKUP" | tee -a $SESSION_LOG
echo -n "" > $CMD_OUTFILE
if ! /usr/bin/time -v cp -Rv $RIAK_RINGDIR $CURRENT_BACKUP/ >> $CMD_OUTFILE 2>&1; then
	ringcopy=0
	status="ERROR: Copying $RIAK_RINGDIR into $CURRENT_BACKUP"
else
	ringcopy=1
	status="SUCCESS: Copied $(cat $CMD_OUTFILE | wc -l) files from $RIAK_RINGDIR into $CURRENT_BACKUP"
fi
rm $CMD_OUTFILE
echo "$(logdate) Directory Size of $CURRENT_BACKUP: $(du -hs $CURRENT_BACKUP | awk '{print $1'})" | tee -a $SESSION_LOG
# -------------------------------------------------------------------------------------------------------------------------------------
if [ $ringcopy -eq 1 ] && [ $leveldbcopy -eq 1 ]; then
	BACKUP_SUCCESS=1
else
	BACKUP_SUCCESS=0
fi
# -------------------------------------------------------------------------------------------------------------------------------------
tar_current_db
# -------------------------------------------------------------------------------------------------------------------------------------
echo "$(logdate) Starting $ENVIRONMENT $SERVICE_NAME Server on $(hostname -f)" | tee -a $SESSION_LOG
/etc/init.d/riak start
# -------------------------------------------------------------------------------------------------------------------------------------
s3operations
# -------------------------------------------------------------------------------------------------------------------------------------
if [ -d "$OBSOLETEBACKUP" ]; then
	remove_obsolete
	echo "$(logdate) Removed $OBSOLETE_DIRECTORY_NAME from directory $BACKUP_ROOT_DIR on $(hostname -f)" | tee -a $SESSION_LOG
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
	elif [ $BACKUP_SUCCESS -eq 1  ]; then
		subject="$ENVIRONMENT $SERVICE_NAME Backup Completed on $(hostname -f)"
		highlightoutput "$SESSION_LOG"
		simple_msg "$subject" "<h3>$ORG_NAME $subject</h3><p>$DURATION</p><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre>" "[$THIS_NAME]"
	else
		subject="$ENVIRONMENT $SERVICE_NAME Backup Error on $(hostname -f)"
		highlightoutput "$SESSION_LOG"
		simple_msg "$subject" "<h3>$ORG_NAME $subject</h3><p>Please verify: ssh://$MYHOST_FQDN </p><h3>PROCESS LOG:</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre>" "[$THIS_NAME]"
	fi
fi
cat $SESSION_LOG >> $PERSIST_LOG

# FINISHING OPTIONS AND COMMANDS
finishing_options

s3opslog "remove"
exit 0
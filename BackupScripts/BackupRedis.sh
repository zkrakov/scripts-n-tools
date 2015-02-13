#!/bin/bash
######################################################################################################################################
# FILE: BackupRedis.sh
# Created by Zachary Krakov on 4/24/2014.
######################################################################################################################################
# SCRIPT VARIABLES
######################################################################################################################################
export PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin
export THIS_NAME='REDIS_BACKUPS'
export SERVICE_NAME="Redis"

# REDIS SPECIFIC
export BACKUP_PREFIX="Prod-Redis"
export BACKUP_ROOT_DIR="/root/Daily"

# AWS S3 BUCKET
export S3_BUCKET="s3://DEFINE_S3_BUCKET/"

# Source function library
. MainFunctions.sh

export S3_SUCCESS=0
export BACKUP_FAILED=0
export BACKUP_SUCCESS=0
######################################################################################################################################
# BACKUP REDIS
######################################################################################################################################
START=$(date +"%s")
removeallfiles
if [ ! -d "$CURRENT_BACKUP" ]; then
	mkdir -p $CURRENT_BACKUP
	echo -e "$(logdate) Beginning Redis Backup Operations" | tee -a $SESSION_LOG
	echo -e "$(logdate) Performing full backup on $(hostname -f)" | tee -a $SESSION_LOG
fi
echo -e "$(logdate) Copying Redis dump file" | tee -a $SESSION_LOG
cp /var/lib/redis/dump.rdb $CURRENT_BACKUP/

echo -e "$(logdate) Compressing database for transfer and archival on S3" | tee -a $SESSION_LOG
tar_current_db

cd $BACKUP_ROOT_DIR
echo -e "$(logdate) Attempting to transfer Redis dump to S3" | tee -a $SESSION_LOG
s3operations

if [ -d "$OBSOLETE_BACKUP" ]; then
	remove_obsolete
	echo -e "$(logdate) Removed $OBSOLETE_DIRECTORY_NAME from Daily Backup" | tee -a $SESSION_LOG
fi
######################################################################################################################################
# DELIVERY AND NOTIFICATION
######################################################################################################################################
STOP=$(date +"%s")
DIFF=$(($STOP-$START))
DURATION="Completed Redis Backup in $(calc_time $STOP $START)"
echo -e "$(logdate) Completed Redis Backup in $(calc_time $STOP $START)" | tee -a $SESSION_LOG
cat $SESSION_LOG >> $PERSIST_LOG
sessionlog_contents=$(<$SESSION_LOG)

if [ $BACKUP_SUCCESS -eq 1 ]; then
	success_email "$DURATION" "[$THIS_NAME] $ENVIRONMENT $SERVICE_NAME Database Successfully uploaded to S3"
	export S3_SUCCESS=0
	export BACKUP_SUCCESS=0
fi
if [ $BACKUP_FAILED -eq 1 ]; then
	sendsimplemail "$(hostname -f) Redis S3 Upload failed" "<h3>On $(date) the backup process may have experienced an error.</h3><p>Please verify: ssh://`hostname -f`</p><h3>Process Log:</h3><pre>$sessionlog_contents</pre>" "[$THIS_NAME]"
	export S3_SUCCESS=0
	export BACKUP_FAILED=0
	export BACKUP_SUCCESS=0
	exit 1
fi

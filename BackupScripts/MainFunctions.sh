#!/bin/bash
######################################################################################################################################
# FILE: MainFunctions.sh
# Created by Zachary Krakov on 6/24/2014.
# REMOVE ESCAPED FROM OUTPUT: s/\x1B\[[0-9;]*[JKmsu]//g
######################################################################################################################################
# GLOBAL VARIABLES
######################################################################################################################################
$ORG_NAME=""
# ENVIRONMENT
export DOMAIN_NAME="$(hostname -d)"
export MYHOST_FQDN="$(hostname -f)"
export MYHOST_NAME="$(hostname)"
if [ "$(hostname -d)" == "prod.example.com" ]; then
	export ENVIRONMENT="Production"
elif [ "$(hostname -d)" == "stage.example.com" ]; then
	export ENVIRONMENT="Staging"
fi

# BACKUP DIRECTORY PATHS
export THEHOUR=$(date +"%H")
export HUMAN_TIME_STAMP=$(echo Today-$(date +"%l%p") | tr -d ' ')
export CURRENT_DIRECTORY_NAME=$(date +"%Y_%m_%d")-$BACKUP_PREFIX
export PREVIOUS_DIRECTORY_NAME=$(date +"%Y_%m_%d" -d "yesterday")-$BACKUP_PREFIX
export OBSOLETE_DIRECTORY_NAME=$(date +"%Y_%m_%d" -d "4 days ago")-$BACKUP_PREFIX
export CURRENT_BACKUP="$BACKUP_ROOT_DIR/$CURRENT_DIRECTORY_NAME"
export PREVIOUS_BACKUP="$BACKUP_ROOT_DIR/$PREVIOUS_DIRECTORY_NAME"
export OBSOLETE_BACKUP="$BACKUP_ROOT_DIR/$OBSOLETE_DIRECTORY_NAME"

# EMAIL Control and RECIPIENTs
export NOTIFYLIST=1

case "$THIS_NAME" in
	"NEO_BACKUPS")
		export RECIPIENT="$ORG_NAME Backups <backups@example.com>"
		export THESENDER="$ORG_NAME Operations <ops@example.com>"
		export CCRECIPIENT=""
		export SESSION_LOG="$BACKUP_ROOT_DIR/Backup.log"
		export PERSIST_LOG="$BACKUP_ROOT_DIR/HistoricalBackup.log"
		;;
	"NEO_ADMIN")
		export RECIPIENT="$ORG_NAME Backups <backups@example.com>"
		export THESENDER="$ORG_NAME Operations <ops@example.com>"
		export CCRECIPIENT=""
		export SESSION_LOG="$BACKUP_ROOT_DIR/Administration.log"
		export PERSIST_LOG="$BACKUP_ROOT_DIR/HistoricalAdministration.log"
		;;
	"NEO_DELIVERY")
		export RECIPIENT="$ORG_NAME Backups <backups@example.com>"
		export THESENDER="$ORG_NAME Operations <ops@example.com>"
		export CCRECIPIENT=""
		export SESSION_LOG="$BACKUP_ROOT_DIR/Delivery.log"
		export PERSIST_LOG="$BACKUP_ROOT_DIR/HistoricalDelivery.log"
		;;
	"VARNISH")
		export RECIPIENT="$ORG_NAME Backups <backups@example.com>"
		export THESENDER="$ORG_NAME Operations <ops@example.com>"
		export CCRECIPIENT=""
		export SESSION_LOG="$BACKUP_ROOT_DIR/Varnishstats.log"
		export PERSIST_LOG="$BACKUP_ROOT_DIR/HistoricalVarnishstats.log"
		;;
	"ALGOLIA_INDEX")
		export RECIPIENT="$ORG_NAME Backups <backups@example.com>"
		export THESENDER="$ORG_NAME Operations <ops@example.com>"
		export CCRECIPIENT=""
		export SESSION_LOG="$BACKUP_ROOT_DIR/AlgoliaIndex.log"
		export PERSIST_LOG="$BACKUP_ROOT_DIR/HistoricalAlgoliaIndex.log"
		;;
	*)
		export RECIPIENT="$ORG_NAME Backups <backups@example.com>"
		export THESENDER="$ORG_NAME Operations <ops@example.com>"
		export CCRECIPIENT=""
		export SESSION_LOG="$BACKUP_ROOT_DIR/Backup.log"
		export PERSIST_LOG="$BACKUP_ROOT_DIR/HistoricalBackup.log"
		;;
esac

# LOG FILES
export DEBUG_LOG="/tmp/debuglog.txt"
export SIMPLEMAIL="/tmp/simple_mail.txt"
export MAILFILE="/tmp/mail_file.txt"
export CURL_SESSION="/tmp/curlsession.txt"
export SSH_SESSION="/tmp/sshsession.txt"
export ADM_SESSION="/tmp/admsession.txt"
export SCP_FILE="/tmp/delivery_scpinfo.txt"
export S3_FILELIST="/tmp/s3list.txt"
export S3_CMD_LOG="/tmp/s3_cmd_log.txt"
export CMD_OUTFILE="/tmp/cmdoutfile.txt"
export MSG_TRANS_LOG="/tmp/sendmailoutput.txt"
export FANCYLOG="/tmp/fancylog.txt"
export TEMPFANCYLOG="/tmp/tempfancylog.txt"

# OUTPUT COLOR
export BRED=$(echo -e "\033[1;31m")
export BGRN=$(echo -e "\033[1;32m")
export BYLW=$(echo -e "\033[1;33m")
export BBLU=$(echo -e "\033[1;34m")
export RED=$(echo -e "\033[31m")
export GRN=$(echo -e "\033[32m")
export YLW=$(echo -e "\033[33m")
export YLW=$(echo -e "\033[34m")
export NRM=$(echo -e "\033[0m")

if [ "$THEHOUR" == "00" ] || [ "$THEHOUR" == "01" ] || [ "$THEHOUR" == "02" ] || [ "$THEHOUR" == "03" ]; then
	export NEWDAY=1
else
	export NEWDAY=0
fi

touch $SESSION_LOG
touch $PERSIST_LOG

######################################################################################################################################
# GLOBAL FUNCTIONS
######################################################################################################################################

#-------------------------------------------------------------------------------------------------------------------------------------
# REMOVE PREVIOUS JOB FILES
#-------------------------------------------------------------------------------------------------------------------------------------
removeallfiles(){
	if [ -f $DEBUG_LOG ]; 		then rm $DEBUG_LOG; fi
	if [ -f $SIMPLEMAIL ]; 		then rm $SIMPLEMAIL; fi
	if [ -f $MAILFILE ]; 		then rm $MAILFILE; fi
	if [ -f $SSH_SESSION ]; 	then rm $SSH_SESSION; fi
	if [ -f $SCP_FILE ]; 		then rm $SCP_FILE; fi
	if [ -f $S3_FILELIST ]; 	then rm $S3_FILELIST; fi
	if [ -f $S3_CMD_LOG ]; 		then rm $S3_CMD_LOG; fi
	if [ -f $CMD_OUTFILE ]; 	then rm $CMD_OUTFILE; fi
	if [ -f $MSG_TRANS_LOG ];	then rm $MSG_TRANS_LOG; fi
# 	if [ -f $FANCYLOG ];		then rm $FANCYLOG; fi
# 	if [ -f $TEMPFANCYLOG ];	then rm $TEMPFANCYLOG; fi
}

#-------------------------------------------------------------------------------------------------------------------------------------
# CALCULATE HUMAN READABLE FILE SIZES
#-------------------------------------------------------------------------------------------------------------------------------------

human_filesize(){
	awk -v sum="$1" ' BEGIN {hum[1024^3]="GB"; hum[1024^2]="MB"; hum[1024]="KB"; for (x=1024^3; x>=1024; x/=1024) { if (sum>=x) { printf "%.3f %s\n",sum/x,hum[x]; break; } } if (sum<1024) print "1kb"; } '
}

#-------------------------------------------------------------------------------------------------------------------------------------
# CREATE A LOG TIMESTAMP
#-------------------------------------------------------------------------------------------------------------------------------------

logdate(){
	echo $(date +"%Y-%m-%d %H:%M:%S")
	#echo "${BBLU}"$(date +"%Y-%m-%d %H:%M:%S")"${NRM}"
}

#-------------------------------------------------------------------------------------------------------------------------------------
# CALCULATE EXECUTION TIME
#-------------------------------------------------------------------------------------------------------------------------------------

calc_time(){
	local stoptime=$1
	local starttime=$2
	local DIFF=$(($stoptime-$starttime))
	local spacer=0
	if [ -z "$3" ]; then
		local dur_min=""; if [ $((DIFF / 60)) -eq 1 ]; then local dur_min="$((DIFF / 60)) minute"; elif [ $((DIFF / 60)) -gt 1 ]; then local dur_min="$((DIFF / 60)) minutes"; fi
		local dur_sec=""; if [ $((DIFF % 60)) -eq 1 ]; then local dur_sec="$((DIFF % 60)) second"; elif [ $((DIFF % 60)) -gt 1 ]; then local dur_sec="$((DIFF % 60)) seconds"; fi
		echo "$dur_min $dur_sec"
	else
		printf -v dur_min '%02d' $((DIFF / 60))
		printf -v dur_sec '%02d' $((DIFF % 60))
		echo "$dur_min:$dur_sec"
	fi
}

#-------------------------------------------------------------------------------------------------------------------------------------
# DEPRECATED
#-------------------------------------------------------------------------------------------------------------------------------------

verifyexecution(){
    "$@"
    local status=$?
    if [ $status -ne 0 ]; then
        echo "error with $1" >&2
    fi
    return $status
}

#-------------------------------------------------------------------------------------------------------------------------------------
# REMOVE COMMAND OUTPUT FILES
#-------------------------------------------------------------------------------------------------------------------------------------

s3opslog(){
	if [ "$1" == "remove" ]; then
		if [ -f $S3_CMD_LOG ]; then
			rm $S3_CMD_LOG
		fi
	elif [ "$1" == "output" ]; then
		s3opslogcontents=$(<$S3_CMD_LOG)
		s3opslogoutput="<h3>S3 LOG</h3><pre>$s3opslogcontents</pre>"
		export s3opslogcontents
		export s3opslogoutput
	elif [ -z "$1" ]; then
		echo -n "" > $S3_CMD_LOG
	fi
}

#-------------------------------------------------------------------------------------------------------------------------------------
# WIP
#-------------------------------------------------------------------------------------------------------------------------------------

improved_removal(){
	cd $BACKUP_ROOT_DIR
	echo "$(logdate) Starting $ENVIRONMENT $SERVICE_NAME housecleaning operations" | tee -a $SESSION_LOG
	echo "$(logdate) Scanning $BACKUP_ROOT_DIR on $(hostname -f) for old backup data" | tee -a $SESSION_LOG

	find $(pwd) -type f -name '*.gz' -ctime +3 -printf "%h/%f\n" | sort

	echo -n "$(logdate) Directory Size of $OBSOLETE_DIRECTORY_NAME: " | tee -a $SESSION_LOG
	echo $(du -hs $MYSQLDUMP_FILENAME | awk '{print $1}') | tee -a $SESSION_LOG
	if ! /usr/bin/time -v rm -rvf $OBSOLETE_DIRECTORY_NAME* 2>&1 | tee -a $SESSION_LOG; then
		status="ERROR: Failed to remove $OBSOLETE_DIRECTORY_NAME from $BACKUP_ROOT_DIR on $(hostname -f)"
	else
		status="SUCCESS: Removed files/directories matching the name $OBSOLETE_DIRECTORY_NAME from $BACKUP_ROOT_DIR"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
	echo "$(logdate) Ending $ENVIRONMENT $SERVICE_NAME housecleaning operations" | tee -a $SESSION_LOG
}

#-------------------------------------------------------------------------------------------------------------------------------------
# REMOVE FILES AND DIRECTORIES OLDER THAN $OBSOLETE_DIRECTORY_NAME
#-------------------------------------------------------------------------------------------------------------------------------------

remove_obsolete(){
	cd $BACKUP_ROOT_DIR
	echo "$(logdate) Starting $ENVIRONMENT $SERVICE_NAME housecleaning operations" | tee -a $SESSION_LOG
	echo "$(logdate) Removing $OBSOLETE_DIRECTORY_NAME in $BACKUP_ROOT_DIR on $(hostname -f)" | tee -a $SESSION_LOG
	echo -n "$(logdate) Directory Size of $OBSOLETE_DIRECTORY_NAME: " | tee -a $SESSION_LOG
	echo $(du -hs $MYSQLDUMP_FILENAME | awk '{print $1}') | tee -a $SESSION_LOG
	if ! /usr/bin/time -v rm -rvf $OBSOLETE_DIRECTORY_NAME* 2>&1 | tee -a $SESSION_LOG; then
		status="ERROR: Failed to remove $OBSOLETE_DIRECTORY_NAME from $BACKUP_ROOT_DIR on $(hostname -f)"
	else
		status="SUCCESS: Removed files/directories matching the name $OBSOLETE_DIRECTORY_NAME from $BACKUP_ROOT_DIR"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
	echo "$(logdate) Ending $ENVIRONMENT $SERVICE_NAME housecleaning operations" | tee -a $SESSION_LOG
}

#-------------------------------------------------------------------------------------------------------------------------------------
# JENKINS DATA CREATION
#-------------------------------------------------------------------------------------------------------------------------------------

neodata_4_jenkins(){
	local dailygraphdb="/DailyNeo/graph.db"
	echo "$(logdate) Starting $ENVIRONMENT $SERVICE_NAME data operations for Jenkins" | tee -a $SESSION_LOG
	if [ $NEWDAY -eq 1 ]; then
		if [ ! -d $dailygraphdb ]; then
			echo "$(logdate) Step 1 of 4 - Creating $dailygraphdb directory" | tee -a $SESSION_LOG
			mkdir -p $dailygraphdb
			chmod -R 777 $dailygraphdb
		else
			echo "$(logdate) Step 1 of 4 - Removing the previously-existing file structure in $dailygraphdb" | tee -a $SESSION_LOG
			rm -rf $dailygraphdb
		fi
		echo "$(logdate) Step 2 of 4 - Moving backup data into $dailygraphdb" | tee -a $SESSION_LOG
		mv $PREVIOUS_BACKUP/ $dailygraphdb
		echo "$(logdate) Step 3 of 4 - Setting permissions for $dailygraphdb" | tee -a $SESSION_LOG
		chmod -R 777 $dailygraphdb
	else
		echo "$(logdate) $ENVIRONMENT $SERVICE_NAME data for Jenkins update is unnecessary" | tee -a $SESSION_LOG
	fi
	echo "$(logdate) Ending $ENVIRONMENT $SERVICE_NAME data operations for Jenkins" | tee -a $SESSION_LOG
}

#-------------------------------------------------------------------------------------------------------------------------------------
# COMPRESS CURRENT
#-------------------------------------------------------------------------------------------------------------------------------------

tar_current_db(){
	cd $BACKUP_ROOT_DIR
	echo "$(logdate) Starting $ENVIRONMENT $SERVICE_NAME archive operations" | tee -a $SESSION_LOG
	echo -n "$(logdate) Directory Size of $CURRENT_DIRECTORY_NAME: " | tee -a $SESSION_LOG
	echo $(du -hs $CURRENT_DIRECTORY_NAME | awk '{print $1}') | tee -a $SESSION_LOG
	echo "$(logdate) Compress $CURRENT_DIRECTORY_NAME in $BACKUP_ROOT_DIR into $CURRENT_DIRECTORY_NAME.tar.gz" | tee -a $SESSION_LOG
	if ! /usr/bin/time -v tar -czvf $CURRENT_DIRECTORY_NAME.tar.gz $CURRENT_DIRECTORY_NAME/ 2>&1 | tee -a $SESSION_LOG; then
		status="ERROR: Failed to create $CURRENT_DIRECTORY_NAME.tar.gz from $CURRENT_DIRECTORY_NAME in $BACKUP_ROOT_DIR"
	else
		status="SUCCESS: Created $CURRENT_DIRECTORY_NAME.tar.gz from $CURRENT_DIRECTORY_NAME in $BACKUP_ROOT_DIR"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
	echo "$(gzip -l $CURRENT_DIRECTORY_NAME.tar.gz)" | tee -a $SESSION_LOG
	echo "$(logdate) Ending $ENVIRONMENT $SERVICE_NAME archive operations" | tee -a $SESSION_LOG
}

#-------------------------------------------------------------------------------------------------------------------------------------
# COMPRESS PREVIOUS
#-------------------------------------------------------------------------------------------------------------------------------------

tar_previous_db(){
	cd $BACKUP_ROOT_DIR
	echo "$(logdate) Starting $ENVIRONMENT $SERVICE_NAME archive operations" | tee -a $SESSION_LOG
	echo -n "$(logdate) Directory Size of $PREVIOUS_DIRECTORY_NAME: " | tee -a $SESSION_LOG
	echo $(du -hs $PREVIOUS_DIRECTORY_NAME | awk '{print $1}') | tee -a $SESSION_LOG
	echo "$(logdate) Compressing (previous) $PREVIOUS_DIRECTORY_NAME in $BACKUP_ROOT_DIR into $PREVIOUS_DIRECTORY_NAME.tar.gz" | tee -a $SESSION_LOG
	if ! /usr/bin/time -v tar -czvf $PREVIOUS_DIRECTORY_NAME.tar.gz $PREVIOUS_DIRECTORY_NAME/ 2>&1 | tee -a $SESSION_LOG; then
		status="ERROR: Failed to create $PREVIOUS_DIRECTORY_NAME.tar.gz from $PREVIOUS_DIRECTORY_NAME in $BACKUP_ROOT_DIR"
	else
		status="SUCCESS: Created $PREVIOUS_DIRECTORY_NAME.tar.gz from $PREVIOUS_DIRECTORY_NAME in $BACKUP_ROOT_DIR"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
	echo "$(gzip -l $PREVIOUS_DIRECTORY_NAME.tar.gz)" | tee -a $SESSION_LOG
	echo "$(logdate) Ending $ENVIRONMENT $SERVICE_NAME archive operations" | tee -a $SESSION_LOG
}

#-------------------------------------------------------------------------------------------------------------------------------------
# COMPRESS CURRENT MYSQL DUMP
#-------------------------------------------------------------------------------------------------------------------------------------

tar_current_mysql(){
	cd $BACKUP_ROOT_DIR
	echo "$(logdate) Compress $MYSQLDUMP_FILENAME into $MYSQLDUMP_FILENAME.tar.gz" | tee -a $SESSION_LOG
	echo -n "$(logdate) File Size of $MYSQLDUMP_FILENAME: " | tee -a $SESSION_LOG
	echo $(du -hs $MYSQLDUMP_FILENAME | awk '{print $1}') | tee -a $SESSION_LOG
	if ! /usr/bin/time -v tar -czf $MYSQLDUMP_FILENAME.tar.gz $MYSQLDUMP_FILENAME | tee -a $SESSION_LOG; then
		status="ERROR: Creating $MYSQLDUMP_FILENAME.tar.gz from $MYSQLDUMP_FILENAME in $BACKUP_ROOT_DIR"
	else
		status="SUCCESS: Created $MYSQLDUMP_FILENAME.tar.gz from $MYSQLDUMP_FILENAME in $BACKUP_ROOT_DIR"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
	echo "$(gzip -l $MYSQLDUMP_FILENAME.tar.gz)" | tee -a $SESSION_LOG
	echo -n "$(logdate) File Size of $MYSQLDUMP_FILENAME.tar.gz: " | tee -a $SESSION_LOG
	echo $(du -h $MYSQLDUMP_FILENAME.tar.gz | awk '{print $1}') | tee -a $SESSION_LOG
	echo "$(logdate) Moving $MYSQLDUMP_FILENAME.tar.gz into $CURRENT_DIRECTORY_NAME in $BACKUP_ROOT_DIR" | tee -a $SESSION_LOG
	if ! /usr/bin/time -v mv $MYSQLDUMP_FILENAME.tar.gz $CURRENT_DIRECTORY_NAME/ 2>&1 | tee -a $SESSION_LOG; then
		status="ERROR: Unable to move $MYSQLDUMP_FILENAME.tar.gz to $CURRENT_DIRECTORY_NAME"
	else
		status="SUCCESS: $MYSQLDUMP_FILENAME.tar.gz placed into $CURRENT_DIRECTORY_NAME in $BACKUP_ROOT_DIR"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
}

#-------------------------------------------------------------------------------------------------------------------------------------
# REMOVE CURRENT MYSQL SQL FILE
#-------------------------------------------------------------------------------------------------------------------------------------

load_mysql_file(){
	cd $BACKUP_ROOT_DIR
	echo "$(logdate) Attempting to load $1 into MySQL" | tee -a $SESSION_LOG
	echo -n "$(logdate) File Size of $1: " | tee -a $SESSION_LOG
	echo $(du -h $MYSQLDUMP_FILENAME | awk '{print $1}') | tee -a $SESSION_LOG
	if ! /usr/bin/time -v mysql < "$1" 2>&1 | tee -a $SESSION_LOG; then
		status="ERROR: Unable to load $1"
	else
		status="SUCCESS: Loaded $1"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
}

#-------------------------------------------------------------------------------------------------------------------------------------
# REMOVE CURRENT MYSQL SQL FILE
#-------------------------------------------------------------------------------------------------------------------------------------

remove_currentmysql(){
	cd $BACKUP_ROOT_DIR
 	echo "$(logdate) Removing $MYSQLDUMP_FILENAME from $BACKUP_ROOT_DIR" | tee -a $SESSION_LOG
	echo -n "$(logdate) File Size of $MYSQLDUMP_FILENAME: " | tee -a $SESSION_LOG
	echo $(du -h $MYSQLDUMP_FILENAME | awk '{print $1}') | tee -a $SESSION_LOG
	if ! /usr/bin/time -v rm $MYSQLDUMP_FILENAME 2>&1 | tee -a $SESSION_LOG; then
		status="ERROR: Removing $MYSQLDUMP_FILENAME from $BACKUP_ROOT_DIR"
	else
		status="SUCCESS: Removed $MYSQLDUMP_FILENAME from $BACKUP_ROOT_DIR"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
}
#-------------------------------------------------------------------------------------------------------------------------------------
# SCP Operations
# nohup scp file_to_copy user@server:/path/to/copy/the/file > nohup.out 2>&1
# 3 Arguments :: SSH_USER  SSH_SERVER  REMOTE_DESTINATION
#-------------------------------------------------------------------------------------------------------------------------------------

deliver_db(){
	export SCP_SUCCESS=0
	echo "$(logdate) Beginning $ENVIRONMENT $SERVICE_NAME delivery operations" | tee -a $SESSION_LOG
	echo -n "$(logdate) File Size of $CURRENT_DIRECTORY_NAME.tar.gz: " | tee -a $SESSION_LOG
	echo $(du -h $CURRENT_DIRECTORY_NAME.tar.gz | awk '{print $1}') | tee -a $SESSION_LOG
	echo "$(logdate) Uploading $CURRENT_DIRECTORY_NAME.tar.gz to $2" | tee -a $SESSION_LOG
	if ! scp -v $CURRENT_DIRECTORY_NAME.tar.gz $1@$2:~/ 2>&1 | tee -a $SCP_FILE; then
		status="ERROR: Failed to deliver $CURRENT_DIRECTORY_NAME.tar.gz to $2"
	else
		export SCP_SUCCESS=1
		status="SUCCESS: Delivered $CURRENT_DIRECTORY_NAME.tar.gz to $2"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
	echo "$(cat $SCP_FILE)" | tee -a $SESSION_LOG
	echo "$(logdate) Completed $ENVIRONMENT $SERVICE_NAME delivery operations" | tee -a $SESSION_LOG
}

#-------------------------------------------------------------------------------------------------------------------------------------
# UPLOAD MYSQLTO S3
#-------------------------------------------------------------------------------------------------------------------------------------

s3_mysqlput(){
	s3opslog
	echo "$(logdate) Starting $ENVIRONMENT $SERVICE_NAME S3 Operations on $S3_BUCKET" | tee -a $SESSION_LOG
	# MAKE LATEST FILE AND PUT IT ON S3
	s3object="$(s3cmd ls $S3_BUCKET | grep Latest --color=never | awk '{print $4}' | sed 's/s3:\/\/prod\-mysqldumps\///g')"
	if [ "$s3object" != "" ]; then
		echo "$(logdate) Removing Latest.tar.gz from S3" | tee -a $SESSION_LOG
		s3cmd del $S3_BUCKET$s3object >> $S3_CMD_LOG 2>&1 | tee -a $SESSION_LOG
	fi

	# CREATE A LATEST ARCHIVE ON S3
	cd $CURRENT_DIRECTORY_NAME
	echo "$(logdate) Renaming $(mv -v $MYSQLDUMP_FILENAME.tar.gz Latest.tar.gz)" | tee -a $SESSION_LOG
	echo -n "$(logdate) File Size of Latest.tar.gz: " | tee -a $SESSION_LOG
	echo $(du -h Latest.tar.gz | awk '{print $1}') | tee -a $SESSION_LOG
	echo "$(logdate) Uploading Latest.tar.gz to S3" | tee -a $SESSION_LOG
	if ! s3cmd put Latest.tar.gz $S3_BUCKET >> $S3_CMD_LOG 2>&1 | tee -a $SESSION_LOG; then
		status="ERROR: Unable to upload Latest.tar.gz to $S3_BUCKET"
	else
		export S3_SUCCESS=1
		status="SUCCESS: Uploaded Latest.tar.gz to $S3_BUCKET"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
	echo "$(logdate) Renaming $(mv -v Latest.tar.gz $MYSQLDUMP_FILENAME.tar.gz )" | tee -a $SESSION_LOG

	# CREATE THE LAST DAY'S ARCHIVE ON S3
	if [ $NEWDAY -eq 1 ]; then
		cd $BACKUP_ROOT_DIR
		tar_previous_db
		echo "$(logdate) Uploading $PREVIOUS_DIRECTORY_NAME.tar.gz to S3" | tee -a $SESSION_LOG
		echo -n "$(logdate) File Size of $PREVIOUS_DIRECTORY_NAME.tar.gz: " | tee -a $SESSION_LOG
		echo $(du -h $PREVIOUS_DIRECTORY_NAME.tar.gz | awk '{print $1}') | tee -a $SESSION_LOG
		if ! s3cmd put $PREVIOUS_DIRECTORY_NAME.tar.gz $S3_BUCKET >> $S3_CMD_LOG 2>&1 | tee -a $SESSION_LOG; then
			status="ERROR: Failed to upload $PREVIOUS_DIRECTORY_NAME.tar.gz to $S3_BUCKET located in $BACKUP_ROOT_DIR"
		else
			export S3_SUCCESS=1
			status="SUCCESS: Uploaded $PREVIOUS_DIRECTORY_NAME.tar.gz to $S3_BUCKET located in $BACKUP_ROOT_DIR"
		fi
		echo "$(logdate) $status" | tee -a $SESSION_LOG
	fi
	echo "$(logdate) Ending $ENVIRONMENT $SERVICE_NAME S3 Operations on $S3_BUCKET" | tee -a $SESSION_LOG
	s3opslog "output"
}

#-------------------------------------------------------------------------------------------------------------------------------------
# UPLOAD TO S3
#-------------------------------------------------------------------------------------------------------------------------------------

s3operations(){
	s3opslog
	echo "$(logdate) Starting $ENVIRONMENT $SERVICE_NAME S3 Operations on $S3_BUCKET" | tee -a $SESSION_LOG
	cd $BACKUP_ROOT_DIR
	if [ $NEWDAY -eq 1 ]; then
		################## REMOVE PREVIOUS DAY FILESET FROM S3 ###########################
		if [ "$THIS_NAME" == "NEO_BACKUPS" ]; then
			s3objects=("$(s3cmd ls $S3_BUCKET | grep 'Today\|Latest' --color=never | awk '{print $4}' | sed 's/s3:\/\/prod\-graph\-dumps\///g' > $S3_FILELIST)")
		elif [ "$THIS_NAME" == "REDIS_BACKUPS" ]; then
			s3objects=("$(s3cmd ls $S3_BUCKET | grep 'Today\|Latest' --color=never | awk '{print $4}' | sed 's/s3:\/\/prod\-redis\-dumps\///g' > $S3_FILELIST)")
		elif [ "$THIS_NAME" == "RIAK_BACKUPS" ]; then
			s3objects=("$(s3cmd ls $S3_BUCKET | grep 'Today\|Latest' --color=never | awk '{print $4}' | sed 's/s3:\/\/prod\-riak\-backups\///g' > $S3_FILELIST)")
		fi
		s3_remove_files=($(cat $S3_FILELIST))
		for i in "${s3_remove_files[@]}"; do
			echo "$(logdate) Removing $i from S3" | tee -a $SESSION_LOG
			s3cmd del $S3_BUCKET$i >> $S3_CMD_LOG 2>&1 | tee -a $SESSION_LOG
		done
		rm $S3_FILELIST
		################## COMPRESS THE PREVIOUS DAY BACKUPS AND UPLOAD TO S3 ############
		echo "$(logdate) Uploading $PREVIOUS_DIRECTORY_NAME.tar.gz to S3" | tee -a $SESSION_LOG
		echo -n "$(logdate) File Size of $PREVIOUS_DIRECTORY_NAME.tar.gz: " | tee -a $SESSION_LOG
		echo $(du -h $PREVIOUS_DIRECTORY_NAME.tar.gz | awk '{print $1}') | tee -a $SESSION_LOG
		if ! s3cmd put $PREVIOUS_DIRECTORY_NAME.tar.gz $S3_BUCKET >> $S3_CMD_LOG 2>&1 | tee -a $SESSION_LOG; then
			export S3_SUCCESS=0
			status="ERROR: Uploading $PREVIOUS_DIRECTORY_NAME.tar.gz to $S3_BUCKET"
		else
			export S3_SUCCESS=1
			status="SUCCESS: Uploaded $PREVIOUS_DIRECTORY_NAME.tar.gz to $S3_BUCKET"
		fi
		echo "$(logdate) $status" | tee -a $SESSION_LOG
	else
		if [ "$THIS_NAME" == "NEO_BACKUPS" ]; then
			s3object="$(s3cmd ls $S3_BUCKET | grep Latest --color=never | awk '{print $4}' | sed 's/s3:\/\/prod\-graph\-dumps\///g')"
		elif [ "$THIS_NAME" == "REDIS_BACKUPS" ]; then
			s3object="$(s3cmd ls $S3_BUCKET | grep Latest --color=never | awk '{print $4}' | sed 's/s3:\/\/prod\-redis\-dumps\///g')"
		elif [ "$THIS_NAME" == "RIAK_BACKUPS" ]; then
			s3object="$(s3cmd ls $S3_BUCKET | grep Latest --color=never | awk '{print $4}' | sed 's/s3:\/\/prod\-riak\-backups\///g')"
		fi
		if [ "$s3object" != "" ]; then
			echo "$(logdate) Removing latest.tar.gz from S3" | tee -a $SESSION_LOG
			s3cmd del $S3_BUCKET$s3object >> $S3_CMD_LOG 2>&1 | tee -a $SESSION_LOG
		fi
	fi
	################## MAKE LATEST FILE AND PUT IT ON S3 #################################
	echo "$(logdate) Renaming $(mv -v $CURRENT_DIRECTORY_NAME.tar.gz Latest.tar.gz)" | tee -a $SESSION_LOG
	echo "$(logdate) Uploading Latest.tar.gz to S3" | tee -a $SESSION_LOG
	echo -n "$(logdate) File Size of Latest.tar.gz: " | tee -a $SESSION_LOG
	echo $(du -h Latest.tar.gz | awk '{print $1}') | tee -a $SESSION_LOG
	if ! s3cmd put Latest.tar.gz $S3_BUCKET >> $S3_CMD_LOG 2>&1 | tee -a $SESSION_LOG; then
		export S3_SUCCESS=0
		status="ERROR: Uploading Latest.tar.gz to $S3_BUCKET"
	else
		export S3_SUCCESS=1
		status="SUCCESS: Uploaded Latest.tar.gz to $S3_BUCKET"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
	echo "$(logdate) Renaming $(mv -v Latest.tar.gz $CURRENT_DIRECTORY_NAME.tar.gz)" | tee -a $SESSION_LOG

	################## NEO4J ONLY ACTIONS ################################################
	if [ "$THIS_NAME" == "NEO_BACKUPS" ]; then
		# MAKE HOURLY FILE AND PUT IT ON S3
		echo "$(logdate) Renaming $(mv -v $CURRENT_DIRECTORY_NAME.tar.gz $HUMAN_TIME_STAMP.tar.gz)" | tee -a $SESSION_LOG
		echo "$(logdate) Uploading $HUMAN_TIME_STAMP.tar.gz to S3" | tee -a $SESSION_LOG
		echo -n "$(logdate) File Size of $HUMAN_TIME_STAMP.tar.gz: " | tee -a $SESSION_LOG
		echo $(du -h $HUMAN_TIME_STAMP.tar.gz | awk '{print $1}') | tee -a $SESSION_LOG
		if ! s3cmd put $HUMAN_TIME_STAMP.tar.gz $S3_BUCKET >> $S3_CMD_LOG 2>&1 | tee -a $SESSION_LOG; then
			export S3_SUCCESS=0
			status="ERROR: Uploading $HUMAN_TIME_STAMP.tar.gz to $S3_BUCKET"
		else
			export S3_SUCCESS=1
			status="SUCCESS: Uploaded $HUMAN_TIME_STAMP.tar.gz to $S3_BUCKET"
		fi
		echo "$(logdate) $status" | tee -a $SESSION_LOG
		echo "$(logdate) Renaming $(mv -v $HUMAN_TIME_STAMP.tar.gz $CURRENT_DIRECTORY_NAME.tar.gz)" | tee -a $SESSION_LOG
	fi
	echo "$(logdate) Ending $ENVIRONMENT $SERVICE_NAME S3 Operations on $S3_BUCKET" | tee -a $SESSION_LOG
	s3opslog "output"
}

#-------------------------------------------------------------------------------------------------------------------------------------
# SEND NOTIFICATIONS
#-------------------------------------------------------------------------------------------------------------------------------------

msgtheadmin(){
	# CREATE MESSAGE HEADERS
	echo "To: Admin <admin@example.com>" > $SIMPLEMAIL
	echo "From: Admin <admin@example.com>" >> $SIMPLEMAIL
	echo "Subject: [ADMIN_$THIS_NAME] $1" >> $SIMPLEMAIL
	echo 'Content-Type: text/html; charset="utf-8"' >> $SIMPLEMAIL
	echo "<html><style>html, body {min-height: 100%; font-family: helvetica;} pre {text-align: left; margin: 2px 1px; padding: 10px; background-color: #ededed; border: solid 1px #aaa; white-space: pre-wrap; white-space: -moz-pre-wrap; white-space: -pre-wrap; white-space: -o-pre-wrap; word-wrap: break-word; -webkit-border-radius: 7px; -moz-border-radius: 7px; border-radius: 7px;} </style><body>" >> $SIMPLEMAIL
	echo "$2" >> $SIMPLEMAIL
	echo "<br/><h3>- $ORG_NAME DevOps</h3></body></html>" >> $SIMPLEMAIL

	# Email the backup report
	if ! cat $SIMPLEMAIL | sendmail -t -oi; then
		status="Notification email failed to be sent"
	else
		status="Notification email successfully sent"
	fi
	#echo "$(logdate) $status" | tee -a $SESSION_LOG
}

simple_msg(){
	# CREATE MESSAGE HEADERS
	echo "To: $RECIPIENT" > $SIMPLEMAIL
	echo "From: $THESENDER" >> $SIMPLEMAIL
	if [ ! -z "$CCRECIPIENT" ]; then echo "Cc: $CCRECIPIENT" >> $SIMPLEMAIL; fi
	echo "Subject: [$THIS_NAME] $1" >> $SIMPLEMAIL
	echo 'Content-Type: text/html; charset="utf-8"' >> $SIMPLEMAIL
	echo "<html><style>html, body {min-height: 100%; font-family: helvetica;} pre {text-align: left; margin: 2px 1px; padding: 10px; background-color: #ededed; border: solid 1px #aaa; white-space: pre-wrap; white-space: -moz-pre-wrap; white-space: -pre-wrap; white-space: -o-pre-wrap; word-wrap: break-word; -webkit-border-radius: 7px; -moz-border-radius: 7px; border-radius: 7px;} </style><body>" >> $SIMPLEMAIL
	echo "$2" >> $SIMPLEMAIL
	echo "<br/><h3>- $ORG_NAME DevOps</h3></body></html>" >> $SIMPLEMAIL

	# Email the backup report
	if ! cat $SIMPLEMAIL | sendmail -t -oi; then
		status="Notification email failed to be sent"
	else
		status="Notification email successfully sent"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
}

notifysuccessmsg(){
	# GENERATE REPORT / FORMAT FILES / GENERATE HUMAN READABLE OUTPUT
	cd $BACKUP_ROOT_DIR
	if [ $NEWDAY -eq 1 ]; then
		cd $BACKUP_ROOT_DIR
		FILESIZE="$(du -hs $PREVIOUS_DIRECTORY_NAME.tar.gz | awk '{print $1}')"
		FILENAME="$(du -hs $PREVIOUS_DIRECTORY_NAME.tar.gz | awk '{print $2}')"
		yesterday=$(date +"%x" -d "yesterday")
	else
		if [ "$THIS_NAME" == "MYSQL_BACKUPS" ]; then
			cd $CURRENT_DIRECTORY_NAME
			FILESIZE="$(du -hs $MYSQLDUMP_FILENAME.tar.gz | awk '{print $1}')"
			FILENAME="$(du -hs $MYSQLDUMP_FILENAME.tar.gz | awk '{print $2}')"
		else
			cd $BACKUP_ROOT_DIR
			FILESIZE="$(du -hs $CURRENT_DIRECTORY_NAME.tar.gz | awk '{print $1}')"
			FILENAME="$(du -hs $CURRENT_DIRECTORY_NAME.tar.gz | awk '{print $2}')"
		fi
	fi
	#perl -pi -e 's/\t/&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; /g' $FILESIZE; echo "\n" >> $FILEINFO
	# CREATE MESSAGE HEADERS
	echo "To: $RECIPIENT" > $MAILFILE
	echo "From: $THESENDER" >> $MAILFILE
	if [ ! -z "$CCRECIPIENT" ]; then echo "Cc: $CCRECIPIENT" >> $MAILFILE; fi
	echo "Subject: $2" >> $MAILFILE
	echo 'Content-Type: text/html; charset="utf-8"' >> $MAILFILE

	highlightoutput

	# CREATE MESSAGE BODY
	echo "<html style='min-height: 100%; font-family: helvetica;'><body style='min-height: 100%; font-family: helvetica;'>" >> $MAILFILE
	echo "<h3>$ORG_NAME $ENVIRONMENT $SERVICE_NAME Database Successfully uploaded to S3</h3>" >> $MAILFILE
	if [ $NEWDAY -eq 1 ]; then
		echo "<p>The $yesterday $SERVICE_NAME Database is available at: $S3_BUCKET$PREVIOUS_DIRECTORY_NAME.tar.gz<br/><p><strong>FILE:</strong> $FILENAME<br/><strong>SIZE:</strong> $FILESIZE<br/></p><p>$1</p>" >> $MAILFILE
	else
		echo "<p>The latest $SERVICE_NAME Database is available at: $S3_BUCKET""Latest.tar.gz<br/><p><strong>FILE:</strong> Latest.tar.gz<br/><strong>SIZE:</strong> $FILESIZE<br/></p><p>$1</p>" >> $MAILFILE
	fi

	if [ -f $S3_CMD_LOG ]; then
		echo "<h3>S3 LOG:</h3>" >> $MAILFILE
		echo "<div style='margin: 2px 1px; padding: 10px; background-color: #ededed; border: solid 1px #aaa; -webkit-border-radius: 7px; -moz-border-radius: 7px; border-radius: 7px;'>" >> $MAILFILE
		echo "<pre style='margin: 0px; padding: 0px; text-align: left; white-space: pre-wrap; white-space: -moz-pre-wrap; white-space: -pre-wrap; white-space: -o-pre-wrap; word-wrap: break-word;'>" >> $MAILFILE
		echo "$s3opslogcontents" >> $MAILFILE
		echo "</pre></div><br/>" >> $MAILFILE
	fi
	echo "<h3>PROCESS LOG:</h3>" >> $MAILFILE
	echo "<div style='margin: 2px 1px; padding: 5px 10px; background-color: #ededed; border: solid 1px #aaa; -webkit-border-radius: 7px; -moz-border-radius: 7px; border-radius: 7px;'>" >> $MAILFILE
	echo "<pre style='text-align: left; white-space: pre-wrap; white-space: -moz-pre-wrap; white-space: -pre-wrap; white-space: -o-pre-wrap; word-wrap: break-word;'>" >> $MAILFILE
 	echo "$SESSIONLOG_FANCYOUTPUT" >> $MAILFILE
	echo "</pre></div><br/>" >> $MAILFILE
	echo "<h3>- $ORG_NAME DevOps</h3></body></html>" >> $MAILFILE

	# Email the backup report
	if ! cat $MAILFILE | sendmail -t -oi; then
		status="Notification email failed to be sent"
	else
		status="Notification email successfully sent"
	fi
	echo "$(logdate) $status" | tee -a $SESSION_LOG
}

#-------------------------------------------------------------------------------------------------------------------------------------
# REMOTE ADMIN FUNCTION :: 3 Arguments :: SSH_USER  SSH_SERVER  REMOTE_DESTINATION
#-------------------------------------------------------------------------------------------------------------------------------------

remote_admin(){
	ra1=0
	ra2=0
	ra3=0
	ra4=0
	ra5=0
	ra6=0
	ra7=0

	if ! ssh $1@$2 "(echo '$(logdate) Step 1 of 7 - Stop the Neo4j service on $2'; service neo4j stop)" | tee -a $SESSION_LOG; then
		status="ERROR: Step 1 of 7 - Unable to stop Neo4j on $2"
		echo "$(logdate) $status" | tee -a $SSH_SESSION
		ra1=1
	fi
	if ! ssh $1@$2 "(echo '$(logdate) Step 2 of 7 - Remove $3/graph.db on $2'; rm -rf $3/graph.db)" | tee -a $SESSION_LOG; then
		status="ERROR: Step 2 of 7 - Removing the active graph located at $3/graph.db on $2"
		echo "$(logdate) $status" | tee -a $SSH_SESSION
		ra2=1
	fi
	if ! ssh $1@$2 "(echo '$(logdate) Step 3 of 7 - Uncompress $CURRENT_DIRECTORY_NAME.tar.gz into $3 on $2'; tar -xzvf $CURRENT_DIRECTORY_NAME.tar.gz -C $3)" | tee -a $SESSION_LOG; then
		status="ERROR: Step 3 of 7 - Uncompressing $CURRENT_DIRECTORY_NAME.tar.gz into $3 on $2"
		echo "$(logdate) $status" | tee -a $SSH_SESSION
		ra3=1
	fi
	if ! ssh $1@$2 "(echo '$(logdate) Step 4 of 7 - Remove $CURRENT_DIRECTORY_NAME.tar.gz on $2'; rm $CURRENT_DIRECTORY_NAME.tar.gz)" | tee -a $SESSION_LOG; then
		status="ERROR: Step 4 of 7 - Removing transferred file: $CURRENT_DIRECTORY_NAME.tar.gz on $2"
		echo "$(logdate) $status" | tee -a $SSH_SESSION
		ra4=1
	fi
	if ! ssh $1@$2 "(echo '$(logdate) Step 5 of 7 - Rename $CURRENT_DIRECTORY_NAME to graph.db in $3 on $2'; cd $3; mv $CURRENT_DIRECTORY_NAME graph.db)" | tee -a $SESSION_LOG; then
		status="ERROR: Step 5 of 7 - Renaming $CURRENT_DIRECTORY_NAME to graph.db in $3 on $2"
		echo "$(logdate) $status" | tee -a $SSH_SESSION
		ra5=1
	fi
	if ! ssh $1@$2 "(echo '$(logdate) Step 6 of 7 - Set permissions on $3/graph.db on $2'; chown -R neo4j:neo4j $3/graph.db)" | tee -a $SESSION_LOG; then
		status="ERROR: Step 6 of 7 - Setting the appropriate permissions on $3/graph.db on $2"
		echo "$(logdate) $status" | tee -a $SSH_SESSION
		ra6=1
	fi
	if ! ssh $1@$2 "(echo '$(logdate) Step 7 of 7 - Start the Neo4j service on $2'; service neo4j start)" | tee -a $SESSION_LOG; then
		status="ERROR: Step 7 of 7 - Starting the Neo4j service on $2"
		echo "$(logdate) $status" | tee -a $SSH_SESSION
		ra7=1
	fi
	if [ $ra3 -eq 1 ] || [ $ra4 -eq 1 ] || [ $ra5 -eq 1 ] || [ $ra6 -eq 1 ]; then
		echo "$(logdate) ERROR: Remote Administration may have failed on $2" | tee -a $SESSION_LOG
	else
		export REMOTE_ADMIN_SUCCCESS=1
	fi
}

#-------------------------------------------------------------------------------------------------------------------------------------
# FINISHING OPTIONS AND CLEANUP
#-------------------------------------------------------------------------------------------------------------------------------------

insert_linenumbers(){
 	sed = $SESSION_LOG | sed 'N;s/\n/\t/' > $TEMPFANCYLOG
 	export SESSIONLOG_FANCYLINENUMBERS="$(cat $TEMPFANCYLOG)"
}

#  	-e 's/\(\/\(\w\+\?\)\{1,9\}\)\( \|$\)/<span style=color:#009;font-weight:bold;>\1<\/span>/g' \
#  	-e 's/\(\([0-9]\w\|`\)\(\w\|\d\)\+\?\.\(sql\|tar\.gz\|zip\)\)/<span style=color:#009;font-weight:bold;>\1<\/span>/g' \

highlightoutput(){
	if [ -z "$1" ]; then
		thelogfiletobeprocessed="$SESSION_LOG"
	else
		thelogfiletobeprocessed="$1"
	fi
	export SESSIONLOG_FANCYOUTPUT="$(cat $thelogfiletobeprocessed | tr -d '\r' | tr -d '\t' | sed \
	-e 's/\([A-Za-z0-9_\.\-]\+\?\)\.\(tar\.gz\|gz\|tar\|zip\|sql\)/<span style=color:#008;font-weight:bold;>\0<\/span>/' \
	-e 's/^\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}\:[0-9]\{2\}\:[0-9]\{2\}\)/<span style=color:#333;font-weight:bold;>\0<\/span>/' \
	-e 's/^\( \+\|[A-Za-z0-9]\|\.\|\[\|{\|}\|`\).*/<span style=color:grey;margin-left:30px;>\0<\/span>/' \
	-e 's/\(Step [0-9] of [0-9]\)\(.*\)/<span style=color:#080;font-weight:bold;>\1<\/span>\2/' \
	-e 's/\(Starting\|Ending\)\(.*\)/<span style=color:#050;font-weight:bold;>\0<\/span>/' \
	-e 's/\(Beginning\|Completed\)\(.*\)/<span style=color:#000;font-weight:bold;>\0<\/span>/' \
	-e 's/\(File\|Directory\) Size/<span style=color:#00b;font-weight:bold;>\0<\/span>/' \
	-e 's/\(SUCCESS:\)/<span style=color:#080;font-weight:bold;>\0<\/span>/' \
	-e 's/\(WARNING\|ERROR:\)/<span style=color:#E00;font-weight:bold;>\0<\/span>/' \
	-e 's/\(Creating\|Uploading\|Uploaded\|Set\|Start\|Stop\|Removing\|Remove\|Rename\|Renaming\|Move\|Moving\|Compressing\|Compress\|Attempt\|Attempting\|Connecting\|Uncompress\) /<span style=color:#E68A2E;font-weight:bold;>\0<\/span>/' \
	-e 's/\(\/root\/Daily\|\/var\/lib\|\/usr\/local\)\(\([A-Za-z0-9\/_\.\-]\+\?\)\| \|\)/<span style=color:#008;font-weight:bold;>\0<\/span>/' \
	-e 's/\([0-9]\{1,4\}\.[0-9]\{1,4\}\|[0-9]\{1,4\}\)\(K\|M\|G\)/<span style=color:#A00;font-weight:bold;>\0<\/span>/')"
}


finishing_options(){
	insert_linenumbers
	#msgtheadmin "$ENVIRONMENT $SERVICE_NAME Highlighted output" "<h3>$ORG_NAME Administration Logs</h3><h3>Highlighted Log File</h3><pre>$SESSIONLOG_FANCYOUTPUT</pre><h3>Log with Numbers</h3><pre>$SESSIONLOG_FANCYLINENUMBERS</pre>"
}

#-------------------------------------------------------------------------------------------------------------------------------------
# EXPORT FUNCTIONS SO THEY'RE AVAILABLE EVERYWHERE
#-------------------------------------------------------------------------------------------------------------------------------------

export -f calc_time
export -f deliver_db
export -f finishing_options
export -f highlightoutput
export -f human_filesize
export -f insert_linenumbers
export -f logdate
export -f msgtheadmin
export -f neodata_4_jenkins
export -f notifysuccessmsg
export -f remote_admin
export -f remove_currentmysql
export -f remove_obsolete
export -f removeallfiles
export -f s3_mysqlput
export -f s3operations
export -f s3opslog
export -f simple_msg
export -f tar_current_db
export -f tar_current_mysql
export -f tar_previous_db
export -f verifyexecution

#-------------------------------------------------------------------------------------------------------------------------------------
# PREPARE ACTIVE SESSION LOG FOR NEW CONTENT
#-------------------------------------------------------------------------------------------------------------------------------------
removeallfiles
echo -n "" > $SESSION_LOG
# echo "$(logdate) Working Backup Directory: $CURRENT_BACKUP" > $SESSION_LOG



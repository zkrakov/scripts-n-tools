#!/bin/bash
#----------------------------------------------------------------------------------------
# FILE: servicecheck.sh :: Created by Zachary Krakov 9/13/2018.
#----------------------------------------------------------------------------------------
# VARIABLES :: Service definition and logging 
#----------------------------------------------------------------------------------------

servicelist=(
	'rakejob'
	'nginx'
	'unicorn'
	# 'puma'
)

SESSION_LOG="/tmp/servicecheck.log"
touch $SESSION_LOG

#----------------------------------------------------------------------------------------
# FUNCTION :: CREATE A LOG TIMESTAMP
#----------------------------------------------------------------------------------------

function logdate(){
    /bin/echo $(date +"%Y-%m-%d %H:%M:%S")
}

#----------------------------------------------------------------------------------------
# FUNCTION :: Check for service operation
#----------------------------------------------------------------------------------------

function process_results(){
	CUSTOMER_CODE="$(hostname | awk -F '[-]' '{print $1}')"
	ENVIRONMENT="$(hostname | awk -F '[-]' '{print $2}')"
	STATUS=$(/bin/echo "$1" | /bin/grep "Active: active (running)" | /usr/bin/wc -l)
	if [[ "$STATUS" != "1" ]]; then
		START=$(/usr/bin/sudo /usr/sbin/service $2 restart)
		/bin/echo "$(logdate) :: Restarting $2 :: $STATUS" | /usr/bin/tee -a $SESSION_LOG
		/usr/bin/logger "DEVOPS_SERVICE_RESTART - Host: $(/bin/hostname) - Service: $2 - Customer: $CUSTOMER_CODE - Environment: $ENVIRONMENT"
	else 
		/bin/echo "$(logdate) :: $2 is running :: $STATUS" | /usr/bin/tee -a $SESSION_LOG
	fi
}

#----------------------------------------------------------------------------------------
# EXECUTABLE :: Loop through the service list defined above and test them for activity
#----------------------------------------------------------------------------------------

count=0
while [ "x${servicelist[count]}" != "x" ]
do
	SERVICESTATE="$(/usr/sbin/service ${servicelist[count]} status)"
	process_results "$SERVICESTATE" "${servicelist[count]}"
	count=$(( $count + 1 ))
done
exit 0

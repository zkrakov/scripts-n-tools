#!/bin/bash 
JAVA_PROC=$(ps -ef | grep java | wc -l) 
LOGDATE=$(date +"%Y-%m-%d %H:%M:%S") 
graph_server="$YOUR_SERVERS_FQDN"

if [ "$JAVA_PROC" == "2" ]; then 
	echo "$LOGDATE Beginning Backup processes for Neo4j" 
	echo "$LOGDATE Only 1 Java process appears to be active, the Neo4j process is ready for backup." 
	sleep 1 
	echo "$LOGDATE Testing the state of $graph_server for backup data integrity...." 
	sleep 1 
	if ! wget -qO - -T 5 -t 0 --retry-connrefused http://$graph_server:7474; then 
		echo "" echo "$LOGDATE Graph3 failed to respond" status=1 
	else 
		echo "" echo "$LOGDATE Excellent! $graph_server is online and ready to Rock... Let's Roll!" 
		status=0 
	fi 
else 
	echo "Something strange may be occurring with $graph_server..." 
	echo "Please verify before attempting any more backups" 
	status=1 
fi 

exit $status
#!/bin/bash

## cis 341 system health monitor and security auditing daemon
## main bash script 
## author hamza

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" ##this makes sure the script can always find necessary files
CONFIG_FILE="$SCRIPT_DIR/sysaudit.cfg"   


source "$SCRIPT_DIR/sysaudit_logger.sh" ##sysadut_logger contains the config file parser function load_config()
source "$SCRIPT_DIR/validator.sh" ## validator contains some validator functions for checking config variables
source "$SCRIPT_DIR/sysaudit_scanner.sh" ## contains basic script to run audit

############################################################################################################################


## daemon function to run in daemon mode 

run_daemon(){
while true; do
	generate_audit
	sleep "$SCAN_INTERVAL_SECONDS"
done
}

## function just prints the usage file
show_help(){
	cat "$SCRIPT_DIR/usage.txt"
}

if [ $# -eq 0 ]; then ##checks args if none prints the help file with options etc
	show_help
	exit 0
fi

## case statement for argument handling 

case "$1" in 

	-h| --help)
	show_help
	;;
	--run)
	load_config "$CONFIG_FILE"
	response=$?

	validate_config 

	response=$?

	if [ "$response" -ne 0 ];then

	exit "$response"

	else

	echo "CONFIGURATION LOADED SUCCESSFULLY! RUNNING ONE AUDIT CYCLE"

	fi
	generate_audit
	;;
	--daemon)
	load_config "$CONFIG_FILE"

	response=$?

	validate_config

	response=$?

	if [ $response -ne 0 ];then

	exit "$response"

	else 

	echo "CONFIGURATION LOADED SUCCESSFULLY! RUNNING IN DAEMON MODE"

	fi

	run_daemon
	;;
	*)
	echo "INVALID ARGUMENT" >&2
	show_help
	exit 1
	;;
esac












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


usercheck() {
    local current_user #variable current user
    local authorized_users #variable for authorized users

    current_user=$(id -un) # get current user
    authorized_users=${AUTHORIZED_USERS//\"/} # retrieve authorized user list

    if [[ " $authorized_users " == *" $current_user "* ]]; then # if current user is in the authorized list, print verified user
        echo "Verified user: $current_user"
    else
        echo "ERROR: Unable to verify: $current_user" >&2 # otherwhise print error
        exit 2
    fi
}


delegate_user() {

        if [[ "$(id -un)" != "auditmanager" ]]; then #if current user is not auditmanager, print error 
                echo "Unauthorized Access"
                exit 2
        fi

        read -p "Enter username: " add_user # enter username to add to delegate

        if ! id "$add_user" &>/dev/null; then #if user does not exist
                echo "User not found"
                return 1
        fi

		 AUTHORIZED_USERS=${AUTHORIZED_USERS//\"/} # remove quotes from authorized users list

        if [[ " $AUTHORIZED_USERS " == *" $add_user "* ]]; then # if user is already in the authorized list, print error
                echo "User is already authorized"
                return 1
        fi

		AUTHORIZED_USERS="$AUTHORIZED_USERS $add_user" # add new user to authorized users list

		sed -i.bak "s|^AUTHORIZED_USERS=.*|AUTHORIZED_USERS=\"$AUTHORIZED_USERS\"|" "$CONFIG_FILE" # create backup of config file

		echo "User $add_user has been added to the authorized users list."
}


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

	--delegate)
	load_config "$CONFIG_FILE"
	delegate_user
	;;

	-h| --help)
	show_help
	;;
	--run)
	
	load_config "$CONFIG_FILE"
	usercheck
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
	usercheck

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












#!/bin/bash

# File		:sysaudit_archive.sh
#Project	:CIS341 Fall 2026
#Task		:archive old *.audit reports, then prune old archives. 
#Author		:Parvinder Singh
#Date		:2026-10-31
#
#run by sysaudit-archive.timer avery night at midnight.
#the script will decide if the work is due: it only run when CLEAN_INTERVAL_DAYS 
#have passed.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/sysaudit.cfg"
FORCE=0
RC=0

# reading the options provided the the user

for arg; do
    case "$arg" in 			#compares arg against all the patterns
        -f|--force)
            FORCE=1			# if option is -f or --force then FORCE = 1
            ;;
        --config=*)			#if the word starts with config then we are replacing the config file
            CONFIG_FILE=$(echo "$arg" | sed 's/^--config=//')	# sed deletes the config= perfix and only files name reains 
            ;;
        *)
            echo "...unknown argument '$arg'" 1>&2	# if any other argument show error and exit with code 1
            exit 1
            ;;
    esac
done

#	Loading the codes required by the the script to function 

for part in sysaudit_logger.sh sysaudit_summary.sh sysaudit_ceiling.sh; do
    if [ ! -f "$SCRIPT_DIR/$part" ]; then
        echo "...required file $part not found ..." 1>&2    #loop over files and if any files are not available
	exit 1						    # exit with code 1
    fi
    source "$SCRIPT_DIR/$part"  			   # if there load those functions into script
done

if [ ! -r "$CONFIG_FILE" ]; then
    echo "...config file not found or not readable..." 1>&2	# look or config file and try to read it 
    exit 3							# if can't exit with error 3
fi

load_config "$CONFIG_FILE"
rc=$?								#using load function which reads kwy value pair
if [ "$rc" -ne 0 ]; then					#savinf the result of last command in rc	
    exit "$rc"							# if rc not equal to 0 then quit with code in rc
fi

init_log
rc=$?
if [ "$rc" -ne 0 ]; then					# preparing the log file to write the logs  
    exit "$rc";							# if rc not equal to 0 then return with the error
fi

# function that logs the error, then ends the script with the given code.

die(){
    log_exception "$1" "$2" 					#calls the log_exception function and prints 
    exit "$1"							# it to the screen and write to the log
}

# going through the setting

require_setting(){
    if [ -z "$2" ]; then					#if then field is empty in config file call die 
        die 7 "setting $1 is missing or empty in $CONFIG_FILE"	# function with error code 7
    fi
}

require_number(){
    case "$2" in						#reject all the values except whole value in  
        ''|*[!0-9]*) die 7 "$1 must be a whole number, got '$2'" ;;   # fields and call die function
    esac
    if [ "$2" -lt 1 ]; then 					# if number is less than 1, again call die function 
        die 7 "$1 must be 1 or more, got '$2'"			#and end the script	
    fi
}
#checking if all the fields are present in config file

require_setting AUDIT_DIR "$AUDIT_DIR"
require_setting ARCHIVE_EXTENSIONS "$ARCHIVE_EXTENSIONS"
require_setting ARCHIVE_PREFIX "$ARCHIVE_PREFIX"
require_setting LAST_RUN_FILENAME "$LAST_RUN_FILENAME"
require_number CLEANUP_INTERVAL_DAYS "$CLEANUP_INTERVAL_DAYS"
require_number RETENTION_DAYS "$RETENTION_DAYS"

if [ ! -d "$AUDIT_DIR" ]; then					#checking if AUDIT_DIR is an actual directory
    die 4 "worksapce is missing or not a  directory" 
fi
if [ ! -w "$AUDIT_DIR" ]; then					#if we can work in that directory
    die 4 "workspace is not writeable" 
fi

#  moving inside the actual workspace 

cd "$AUDIT_DIR"
rc=$?							#rc store the error code of  cd command 
if [ "$rc" -ne 0 ]; then				#if cd failed, exit with code 4
    die 4 "cannot enter the workspace"
fi

#Normalize AUDIT_DIR to the full absolute path  

AUDIT_DIR=$(pwd)

#record the log message regarding the  archive job  along with current config values
log_msg INFO "Archieve job started (interval=${CLEANUP_INTERVAL_DAYS}d retention=${RETENTION_DAYS}d force=$FORCE)"

#set the path to the hidden timestaamp that records the  last archive date
STAMP="$AUDIT_DIR/$LAST_RUN_FILENAME"
today_n=$(( $(date +%s) / 86400 ))			#Calculate the todays date 

if [ "$FORCE" -eq 0 ] && [ -f "$STAMP" ]; then    	# we check if  force was used or not and last run
							#file exits
    read -r last < "$STAMP"				#read the stamp value into last variable
    case "$last" in
        ''|*[!0-9]*)
            log_msg WARN "Last-run file is corrupt" 	# if it is empty or contain non digit
            ;;
        *)
            since=$(( today_n - last ))			#subtract last run  day from today date  
            if [ "$since" -ge 0 ] && [ "$since" -lt "$CLEANUP_INTERVAL_DAYS" ]; then
                log_msg INFO "Not due yet: last run was $since days ago."
                exit 0
            fi 						#if since is negative then time stamp was set in future 
            if [ "$since" -lt 0 ]; then			# show error and exit.
                log_msg WARN "Last-run date is in the future."
            fi
            ;;
    esac
fi

#Function: This will compress all *.audit files  into .tar.gz file and delete the raw files

archive_audit_files(){
    if [ ! -f "$1" ]; then				#if no audit files exit then log it and return with code 0
        log_msg INFO "No .audit files to archive"
        return 0
    fi

    count=$# 						#store number of .audit files passed into this function
    ARCHIVE_NAME="${ARCHIVE_PREFIX}_$(date +%Y%m%d_%H%M%S).tar.gz" #Building the archive filename  
    ARCHIVE="$AUDIT_DIR/$ARCHIVE_NAME"
    PARTIAL="$ARCHIVE.partial" 				# temmporary name used while tar is compressing
    if [ -e  "$ARCHIVE" ]; then				# check if archieve with exact name exit
        die 8 "archive already exits: $ARCHIVE"
    fi
#compress all .audit files into the temporary .partial files using gzip 
    out=$(tar czf "$PARTIAL" "$@" 2>&1)
    rc=$?
    if [ "$rc" -ne 0 ]; then
        rm -f "$PARTIAL"
        die 8 "tar failed with code $rc"
    fi
#Check  that the created .partial file is not 0 bytes(empty)
    if [ ! -s "$PARTIAL" ]; then 
        rm -f "$PARTIAL"				#remove the  empty .partial files with exit code 8 
        die 8 "archive is empty"
    fi

# rename the verified .partial file to the final .tar.gz file
    mv "$PARTIAL" "$ARCHIVE"
    rc=$?
    if [ "$rc" -ne 0 ]; then 				#if moving failed then clean up with exit code 8
        rm -f "$PARTIAL"
        die 8 "could not move the finished archive into the place"
    fi

#Count the exact size of the finished archive
    size=$(wc -c < "$ARCHIVE")
    log_msg INFO "Archive created: $ARCHIVE_NAME (${size} bytes)"	#log the information

#now we remove the raw file as archive is created successfully
    deleted=0
    for f; do
        rm -f "./$f"
        rc=$?
        if [ "$rc" -eq 0 ]; then
            deleted=$(( deleted + 1))
        else
            log_msg WARN "Could not delete orginal files"
            RC=8
        fi
    done
#log the information related to number of raw files deleted
    log_msg INFO "Deleted $deleted of $count original .audit files"
}

#calling the function with all .audit files
archive_audit_files *.audit

#Now we prune the archieve files older than RETENTION_DAYS

pruned=0
#replacing the commas with spaces in archive extensions
for ext in `echo "$ARCHIVE_EXTENSIONS" | sed 's/,/ /g'`; do
    for f in *."$ext"; do				#loop over all  files with extension .tar.gz
       if [ -f "$f" ]; then
           old=$(find "./$f" -mtime +"RETENTION_DAYS") 	#find the files that are older the 14 days
           if [ -n "$old" ]; then
               rm -f "./$f"				#remove that file
               rc=$?
               if [ "$rc" -eq 0 ]; then 
                   pruned=$(( pruned + 1 ))
                   log_msg INFO "Pruned old archives: $f"
               else
                   log_msg WARN "Could not delete old archives: $f"
                   RC=9
               fi
           fi  
       fi
    done
done

#log the information related to pruning
 
log_msg INFO "Pruning done: $pruned archives older than $RETENTION_DAYS days removed"

# As the archive has been created we now records tadays date into the stamp 

if [ "$RC" -eq 0 ]; then 
    if echo "$today_n" > "$STAMP"; then
        log_msg INFO "last-run day saved: $today_n ($(date +%Y-%m-%d))"
    else
        log_msg WARN "Could not write the last-run file $STAMP"
    fi
fi

#checking the disk usage to check if the workspace disk usage is exceeding the MAX_DISK_USAGE

check_disk_ceiling
crc=$?
if [ "$crc" -ne 0 ] && [ "$crc" -ne 5 ] && [ "$RC" -eq 0 ]; then 
    RC="$crc"
fi

#calling the archive summary function to log archive summary statistics

archive_summary
src=$?
if [ "$src" -ne 0 ] && [ "$RC" -eq 0 ]; then 
    RC="$src"
fi

#log the completetion of the job and exit with the final stats code.

log_msg INFO "Archive job finished (exit code $RC)"
exit "$RC"


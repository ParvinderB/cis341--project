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




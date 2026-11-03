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

SCRIPT_DIR=$(dirname "$0")
CONFIG_FILE="$SCRIPT_DIR/sysaudit.cfg"
FORCE=0

# 2. Check command-line flags (-f / --force or --config=...)
for arg in "$@"; do
    case "$arg" in
        -f|--force)
            FORCE=1
            ;;
        --config=*)
            CONFIG_FILE="${arg#--config=}"
            ;;
        *)
            echo "Error: Unknown argument '$arg'" >&2
            exit 1
            ;;
    esac
done

# 3. Load teammate helper scripts (logging, summary, disk ceiling)
for part in sysaudit_logger.sh sysaudit_summary.sh sysaudit_celing.sh; do
    if [ ! -f "$SCRIPT_DIR/$part" ]; then
        echo "Error: Required file $part not found" >&2
        exit 1
    fi
    source "$SCRIPT_DIR/$part"
done

# 4. Check if config file exists and load it (Exit Code 3 if missing)
if [ ! -r "$CONFIG_FILE" ]; then
    echo "Error: Config file $CONFIG_FILE not found or not readable" >&2
    exit 3
fi

load_config "$CONFIG_FILE" || exit $?
init_log || exit $?

# Set default values if any setting is missing in sysaudit.cfg
CLEANUP_INTERVAL_DAYS="${CLEANUP_INTERVAL_DAYS:-3}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
ARCHIVE_PREFIX="${ARCHIVE_PREFIX:-audit_archive}"
LAST_RUN_FILENAME="${LAST_RUN_FILENAME:-.last_archive_run}"
ARCHIVE_EXTENSIONS="${ARCHIVE_EXTENSIONS:-tar.gz,zip}"

# 5. Check that workspace directory exists and is writable (Exit Code 4)
if [ ! -d "$AUDIT_DIR" ] || [ ! -w "$AUDIT_DIR" ]; then
    log_exception 4 "Workspace $AUDIT_DIR is missing or not writable"
    exit 4
fi

cd "$AUDIT_DIR" || exit 4
log_msg INFO "Archive job started (interval=${CLEANUP_INTERVAL_DAYS}d, retention=${RETENTION_DAYS}d)"

# 6. Spec #3: Check if 3 days have passed since the last run
STAMP="$AUDIT_DIR/$LAST_RUN_FILENAME"
today_days=$(( $(date +%s) / 86400 ))

if [ "$FORCE" -eq 0 ] && [ -f "$STAMP" ]; then
    last_days=$(cat "$STAMP")
    days_passed=$(( today_days - last_days ))

    if [ "$days_passed" -lt "$CLEANUP_INTERVAL_DAYS" ]; then
        log_msg INFO "Not due yet: only $days_passed day(s) passed since last run."
        exit 0
    fi
fi

# 7. Spec #3: Compress all *.audit files into .tar.gz and delete raw files
if ls *.audit >/dev/null 2>&1; then
    ARCHIVE_NAME="${ARCHIVE_PREFIX}_$(date +%Y%m%d_%H%M%S).tar.gz"

    if tar -czf "$AUDIT_DIR/$ARCHIVE_NAME" *.audit; then
        log_msg INFO "Created archive: $ARCHIVE_NAME"
        rm -f *.audit
        log_msg INFO "Deleted original raw .audit files"
    else
        log_exception 8 "tar failed to compress .audit files"
        exit 8
    fi
else
    log_msg INFO "No raw .audit files found to archive"
fi

# 8. Spec #6: Delete archives older than RETENTION_DAYS (14 days)
pruned=0
for ext in $(echo "$ARCHIVE_EXTENSIONS" | tr ',' ' '); do
    for file in *."$ext"; do
        if [ -f "$file" ]; then
            # Check if the archive file is older than RETENTION_DAYS
            if [ -n "$(find "./$file" -mtime +"$RETENTION_DAYS")" ]; then
                rm -f "./$file"
                pruned=$(( pruned + 1 ))
                log_msg INFO "Deleted expired archive: $file"
            fi
        fi
    done
done
log_msg INFO "Pruning finished: removed $pruned old archive(s)"

# 9. Save today's day number into .last_archive_run
echo "$today_days" > "$STAMP"
log_msg INFO "Updated last-run file ($STAMP) with day $today_days"

# 10. Run Person B's disk ceiling check (Spec #8) and archive summary (Spec #7)
check_disk_celing
archive_summary

log_msg INFO "Archive job finished successfully"
exit 0

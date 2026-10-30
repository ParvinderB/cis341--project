#!/usr/bin/env bash
#===============================================================================
# File    : sysaudit_summary.sh
# Project : CIS 341 Fall 2026 - System Health Monitor & Security Auditing Daemon
# Task    : #7 Core Metadata Audit Summary Logging
# Author  : Felix Tu
# Date    : 2026-10-30
#
# What it does:
#   Looks at the compressed archives in the audit folder and writes one
#   summary line to the log with:
#     - how many archives there are
#     - the name of the largest archive
#     - its size in bytes
#     - its modification time
#   Example log line:
#     2026-10-30 00:00:05 [INFO] sysaudit[2211]: Archive summary: 3 archives
#     in /course_project/audit, largest is audit_2026-10-27.tar.gz
#     (10240 bytes, modified 2026-10-27 00:00:04.512345678 -0500)
#
# Function:
#   archive_summary            returns 0 ok, 4 if the folder is missing
#
# Config keys used:
#   AUDIT_DIR            the audit folder (shared key)
#   ARCHIVE_DIR          optional; set it only if task 3 stores archives
#                        somewhere else than AUDIT_DIR
#   ARCHIVE_EXTENSIONS   archive types to count, comma separated: tar.gz,zip
#
# How to use it in the main script (sysaudit.sh):
#   source "$SCRIPT_DIR/sysaudit_logger.sh"     # must be loaded first (log_msg)
#   source "$SCRIPT_DIR/sysaudit_summary.sh"
#   ... after the archive step (task 3) and the cleanup step (task 6):
#   archive_summary
#
# Requires: sysaudit_logger.sh, GNU stat (standard on Linux)
#===============================================================================

archive_summary() {
    local dir="${ARCHIVE_DIR:-$AUDIT_DIR}"
    local count=0
    local largest_name="" largest_size=0 largest_time=""
    local ext file size

    if [ ! -d "$dir" ]; then
        log_exception 4 "Archive folder $dir does not exist"
        return 4
    fi

    # Loop over every archive type, like the for...in loop on p.207.
    # ${ARCHIVE_EXTENSIONS//,/ } turns "tar.gz,zip" into "tar.gz zip".
    for ext in ${ARCHIVE_EXTENSIONS//,/ }; do
        for file in "$dir"/*."$ext"; do
            [ -f "$file" ] || continue          # no match: skip the pattern itself
            size=$(stat -c %s "$file" 2>/dev/null) || continue
            count=$((count + 1))

            if [ -z "$largest_name" ] || [ "$size" -gt "$largest_size" ]; then
                largest_name=$(basename "$file")
                largest_size=$size
                # %y = modification time (ctime is not creation time, p.134)
                largest_time=$(stat -c %y "$file")
            fi
        done
    done

    if [ "$count" -eq 0 ]; then
        log_msg INFO "Archive summary: 0 archives in $dir"
    else
        log_msg INFO "Archive summary: $count archives in $dir, largest is $largest_name ($largest_size bytes, modified $largest_time)"
    fi
    return 0
}

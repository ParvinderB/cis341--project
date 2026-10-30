#!/usr/bin/env bash
#===============================================================================
# File    : sysaudit_ceiling.sh
# Project : CIS 341 Fall 2026 - System Health Monitor & Security Auditing Daemon
# Task    : #8 Configurable Resource Ceiling Warning Interrupts
# Author  : Felix Tu
# Date    : 2026-10-30
#
# What it does:
#   Measures the total size of AUDIT_DIR with du. If it is equal to or
#   bigger than MAX_DISK_USAGE (in MB), it writes a [WARNING] line to the
#   log (and to STDERR) and returns 5. Otherwise it writes an [INFO] line.
#   Example log line:
#     2026-10-30 00:00:06 [WARNING] sysaudit[2211]: Disk ceiling reached:
#     /course_project/audit uses 110100480 bytes, limit is 104857600 bytes (100 MB)
#
# Function:
#   check_disk_ceiling   returns 0 ok, 1 du failed, 4 audit folder missing,
#                        5 ceiling reached, 7 MAX_DISK_USAGE is not a number
#
# Config keys used (shared keys in sysaudit.cfg):
#   AUDIT_DIR         folder to measure
#   MAX_DISK_USAGE    limit in MB, 1 MB = 1024 x 1024 bytes (e.g. 100)
#
# How to use it in the main script (sysaudit.sh):
#   source "$SCRIPT_DIR/sysaudit_logger.sh"     # must be loaded first (log_msg)
#   source "$SCRIPT_DIR/sysaudit_ceiling.sh"
#   ... in every scan loop:
#   check_disk_ceiling
#   (return code 5 means the warning was logged; the daemon keeps running)
#
# Requires: sysaudit_logger.sh, GNU du (standard on Linux), cut
#===============================================================================

check_disk_ceiling() {
    local dir="$AUDIT_DIR"
    local limit_mb="$MAX_DISK_USAGE"
    local limit_bytes used_bytes

    if [ ! -d "$dir" ]; then
        log_exception 4 "Audit folder $dir does not exist"
        return 4
    fi

    # The limit must be a whole number (case pattern, p.206)
    case "$limit_mb" in
        ''|*[!0-9]*)
            log_exception 7 "MAX_DISK_USAGE must be a whole number, not '$limit_mb'"
            return 7 ;;
    esac

    limit_bytes=$((limit_mb * 1024 * 1024))

    # du -s = one total, -b = size in bytes (du is explained on p.108)
    used_bytes=$(du -sb "$dir" 2>/dev/null | cut -f1)
    if [ -z "$used_bytes" ]; then
        log_exception 1 "du could not measure $dir"
        return 1
    fi

    # -ge = greater than or equal (Table 7.3, p.205)
    if [ "$used_bytes" -ge "$limit_bytes" ]; then
        log_msg WARNING "Disk ceiling reached: $dir uses $used_bytes bytes, limit is $limit_bytes bytes ($limit_mb MB)"
        return 5
    fi

    log_msg INFO "Disk usage OK: $dir uses $used_bytes of $limit_bytes bytes ($limit_mb MB)"
    return 0
}

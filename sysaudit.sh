#!/bin/bash

## cis 341 system health monitor and security auditing daemon
## main bash script 

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

show_help(){
	cat "$SCRIPT_DIR/usage.txt"
}

if [ $# -eq 0 ]; then
	show_help
	exit 0
fi

case "$1" in 

	-h)
	show_help
	;;
	--help)
	show_help
	;;
	*)
	echo "invalid argument" >&2
	show_help
	exit 1
	;;
esac

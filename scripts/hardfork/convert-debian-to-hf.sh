#!/bin/bash

set -e

usage() {
	echo "Usage: $0 -d <deb_file> -c <runtime_config_json> -l <ledger_tarballs>"
	echo "  -d <deb_file>            Path to mina-daemon.deb file"
	echo "  -c <runtime_config_json> Path to runtime config JSON file"
	echo "  -l <ledger_tarballs>     Path to ledger tarballs"
	exit 1
}

while getopts "d:c:l:" opt; do
	case $opt in
		d) DEB_FILE="$OPTARG" ;;
		c) RUNTIME_CONFIG_JSON="$OPTARG" ;;
		l) LEDGER_TARBALLS="$OPTARG" ;;
		*) usage ;;
	esac
done

if [[ -z "$DEB_FILE" || -z "$RUNTIME_CONFIG_JSON" || -z "$LEDGER_TARBALLS" ]]; then
	usage
fi

./scripts/debian/replace-entry.sh "$DEB_FILE" /var/lib/coda/config_*.json "$RUNTIME_CONFIG_JSON"
./scripts/debian/insert-entries.sh "$DEB_FILE" /var/lib/coda/ "$LEDGER_TARBALLS"
./scripts/debian/rename.sh "$DEB_FILE" "mina-daemon-hardfork"
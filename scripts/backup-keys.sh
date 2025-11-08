#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME}
BACKUP_DIR=${BACKUP_DIR:-$DAEMON_HOME/backup}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Files to backup
CRITICAL_FILES=(
    "$DAEMON_HOME/config/priv_validator_key.json"
    "$DAEMON_HOME/data/priv_validator_state.json"
    "$DAEMON_HOME/config/node_key.json"
)

BACKUP_ARCHIVE="$BACKUP_DIR/validator_backup_$TIMESTAMP.tar.gz"

# Collect files that exist
FILES_TO_BACKUP=""
for FILE in "${CRITICAL_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        FILES_TO_BACKUP="$FILES_TO_BACKUP $FILE"
    fi
done

if [ -z "$FILES_TO_BACKUP" ]; then
    echo "Error: No files found to backup" >&2
    exit 1
fi

# Create tar archive
tar -czf "$BACKUP_ARCHIVE" $FILES_TO_BACKUP

# Output backup path for CLI
echo "{\"backup_path\": \"$BACKUP_ARCHIVE\", \"timestamp\": \"$TIMESTAMP\"}"

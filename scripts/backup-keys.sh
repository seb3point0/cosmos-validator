#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME:-/root/.gaia}
BACKUP_DIR=${BACKUP_DIR:-/root/.gaia/backup}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Cosmos Validator Key Backup Utility"
echo "===================================="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Creating backup at: $BACKUP_DIR/validator_backup_$TIMESTAMP"
echo ""

# Files to backup
CRITICAL_FILES=(
    "$DAEMON_HOME/config/priv_validator_key.json"
    "$DAEMON_HOME/data/priv_validator_state.json"
    "$DAEMON_HOME/config/node_key.json"
)

BACKUP_ARCHIVE="$BACKUP_DIR/validator_backup_$TIMESTAMP.tar.gz"

echo "📦 Backing up critical files..."
echo "-------------------------------"

# Check which files exist
FILES_TO_BACKUP=""
for FILE in "${CRITICAL_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        echo "✓ Found: $FILE"
        FILES_TO_BACKUP="$FILES_TO_BACKUP $FILE"
    else
        echo "⚠️  Missing: $FILE"
    fi
done

if [ -z "$FILES_TO_BACKUP" ]; then
    echo ""
    echo "❌ Error: No files found to backup!"
    exit 1
fi

# Create tar archive
echo ""
echo "Creating archive..."
tar -czf "$BACKUP_ARCHIVE" $FILES_TO_BACKUP

echo "✓ Backup created: $BACKUP_ARCHIVE"
echo ""

# Display file size
BACKUP_SIZE=$(du -h "$BACKUP_ARCHIVE" | cut -f1)
echo "Backup size: $BACKUP_SIZE"
echo ""

# Prompt for encryption (optional)
read -p "Would you like to encrypt the backup with GPG? (yes/no): " ENCRYPT

if [ "$ENCRYPT" = "yes" ]; then
    read -s -p "Enter encryption password: " PASSWORD
    echo ""
    read -s -p "Confirm password: " PASSWORD_CONFIRM
    echo ""
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo "❌ Passwords do not match!"
        exit 1
    fi
    
    echo "Encrypting backup..."
    echo "$PASSWORD" | gpg --batch --yes --passphrase-fd 0 -c "$BACKUP_ARCHIVE"
    
    if [ -f "$BACKUP_ARCHIVE.gpg" ]; then
        rm "$BACKUP_ARCHIVE"
        echo "✓ Encrypted backup created: $BACKUP_ARCHIVE.gpg"
        BACKUP_ARCHIVE="$BACKUP_ARCHIVE.gpg"
    fi
fi

echo ""
echo "========================================="
echo "⚠️  CRITICAL BACKUP INSTRUCTIONS"
echo "========================================="
echo ""
echo "1. Copy this backup to a secure location:"
echo "   docker cp cosmos-validator:$BACKUP_ARCHIVE ./"
echo ""
echo "2. Store multiple copies in different secure locations"
echo "3. NEVER commit these files to version control"
echo "4. Keep backups encrypted and password-protected"
echo ""
echo "To restore from backup:"
echo "   tar -xzf $BACKUP_ARCHIVE -C /"
echo ""
echo "========================================="
echo ""

# List all backups
echo "Existing backups in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"

echo ""
echo "Backup complete!"


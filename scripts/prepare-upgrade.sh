#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
UPGRADE_NAME=${1:-}
BINARY_URL=${2:-}
UPGRADE_HEIGHT=${3:-}
BINARY_HASH=${4:-}

if [ -z "$UPGRADE_NAME" ] || [ -z "$BINARY_URL" ]; then
    echo "Error: UPGRADE_NAME and BINARY_URL are required" >&2
    exit 1
fi

# Create upgrade directory
UPGRADE_DIR="$DAEMON_HOME/cosmovisor/upgrades/$UPGRADE_NAME/bin"
mkdir -p "$UPGRADE_DIR"

# Download binary
TEMP_BINARY="/tmp/${DAEMON_NAME}_${UPGRADE_NAME}"
wget -O "$TEMP_BINARY" "$BINARY_URL" --quiet --show-progress

if [ $? -ne 0 ]; then
    echo "Error: Failed to download binary from $BINARY_URL" >&2
    exit 1
fi

# Verify hash if provided
if [ ! -z "$BINARY_HASH" ]; then
    DOWNLOADED_HASH=$(sha256sum "$TEMP_BINARY" | cut -d' ' -f1)
    if [ "$DOWNLOADED_HASH" != "$BINARY_HASH" ]; then
        echo "Error: Hash mismatch. Expected: $BINARY_HASH, Got: $DOWNLOADED_HASH" >&2
        rm -f "$TEMP_BINARY"
        exit 1
    fi
fi

# Make binary executable and install
chmod +x "$TEMP_BINARY"
mv "$TEMP_BINARY" "$UPGRADE_DIR/$DAEMON_NAME"

# Create upgrade-info.json if upgrade height is provided
if [ ! -z "$UPGRADE_HEIGHT" ]; then
    UPGRADE_INFO_FILE="$DAEMON_HOME/data/upgrade-info.json"
    cat > "$UPGRADE_INFO_FILE" <<EOF
{
  "name": "$UPGRADE_NAME",
  "height": $UPGRADE_HEIGHT,
  "info": "Binary prepared by prepare-upgrade.sh"
}
EOF
fi

# Verify installation
if [ ! -f "$UPGRADE_DIR/$DAEMON_NAME" ] || [ ! -x "$UPGRADE_DIR/$DAEMON_NAME" ]; then
    echo "Error: Binary installation failed" >&2
    exit 1
fi

echo "INFO: Upgrade $UPGRADE_NAME prepared successfully"

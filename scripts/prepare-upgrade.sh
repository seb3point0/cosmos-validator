#!/bin/bash
set -e

# Prepare Cosmos Chain Upgrade
# This script downloads and installs a new binary for a pending upgrade
# Used by the upgrade-monitor service or can be run manually

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
CHAIN_NETWORK=${CHAIN_NETWORK}
RPC_PORT=${RPC_PORT}
BLOCK_TIME_SECONDS=${BLOCK_TIME_SECONDS:-6}

# Arguments
UPGRADE_NAME=${1:-}
BINARY_URL=${2:-}
UPGRADE_HEIGHT=${3:-}
BINARY_HASH=${4:-}

if [ -z "$UPGRADE_NAME" ] || [ -z "$BINARY_URL" ]; then
    echo "Usage: $0 <upgrade_name> <binary_url> [upgrade_height] [binary_hash]"
    echo ""
    echo "Example:"
    echo "  $0 v26 https://github.com/cosmos/gaia/releases/download/v26.0.0/gaiad-v26.0.0-linux-amd64 28356500"
    exit 1
fi

echo "=========================================="
echo "${CHAIN_NETWORK} Upgrade Preparation"
echo "=========================================="
echo ""
echo "Upgrade Name: $UPGRADE_NAME"
echo "Binary URL: $BINARY_URL"
echo "Upgrade Height: ${UPGRADE_HEIGHT:-Unknown}"
echo "Daemon: $DAEMON_NAME"
echo "Home: $DAEMON_HOME"
echo ""

# Create upgrade directory
UPGRADE_DIR="$DAEMON_HOME/cosmovisor/upgrades/$UPGRADE_NAME/bin"
mkdir -p "$UPGRADE_DIR"

echo "Step 1: Downloading new binary..."
echo "----------------------------------"
TEMP_BINARY="/tmp/${DAEMON_NAME}_${UPGRADE_NAME}"
wget -O "$TEMP_BINARY" "$BINARY_URL"

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to download binary from $BINARY_URL"
    exit 1
fi

echo "✓ Binary downloaded"
echo ""

# Verify hash if provided
if [ ! -z "$BINARY_HASH" ]; then
    echo "Step 2: Verifying binary hash..."
    echo "---------------------------------"
    DOWNLOADED_HASH=$(sha256sum "$TEMP_BINARY" | cut -d' ' -f1)
    
    if [ "$DOWNLOADED_HASH" != "$BINARY_HASH" ]; then
        echo "❌ Error: Hash mismatch!"
        echo "Expected: $BINARY_HASH"
        echo "Got: $DOWNLOADED_HASH"
        rm -f "$TEMP_BINARY"
        exit 1
    fi
    echo "✓ Hash verified"
    echo ""
else
    echo "Step 2: Skipping hash verification (no hash provided)"
    echo ""
fi

# Make binary executable
echo "Step 3: Installing binary..."
echo "----------------------------"
chmod +x "$TEMP_BINARY"

# Test the binary
echo "Testing binary..."
if $TEMP_BINARY version > /dev/null 2>&1; then
    VERSION=$($TEMP_BINARY version 2>&1)
    echo "✓ Binary version: $VERSION"
else
    echo "⚠️  Warning: Could not verify binary version (may be normal for some chains)"
fi

# Install binary
mv "$TEMP_BINARY" "$UPGRADE_DIR/$DAEMON_NAME"
echo "✓ Binary installed to: $UPGRADE_DIR/$DAEMON_NAME"
echo ""

# Create upgrade-info.json if upgrade height is provided
if [ ! -z "$UPGRADE_HEIGHT" ]; then
    echo "Step 4: Creating upgrade info..."
    echo "--------------------------------"
    UPGRADE_INFO_FILE="$DAEMON_HOME/data/upgrade-info.json"
    cat > "$UPGRADE_INFO_FILE" <<EOF
{
  "name": "$UPGRADE_NAME",
  "height": $UPGRADE_HEIGHT,
  "info": "Binary prepared by prepare-upgrade.sh"
}
EOF
    echo "✓ Upgrade info created: $UPGRADE_INFO_FILE"
    echo ""
fi

# Verify installation
echo "Step 5: Verification"
echo "--------------------"
if [ -f "$UPGRADE_DIR/$DAEMON_NAME" ] && [ -x "$UPGRADE_DIR/$DAEMON_NAME" ]; then
    BINARY_SIZE=$(du -h "$UPGRADE_DIR/$DAEMON_NAME" | cut -f1)
    echo "✓ Binary is ready: $UPGRADE_DIR/$DAEMON_NAME ($BINARY_SIZE)"
else
    echo "❌ Error: Binary installation failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ Upgrade Preparation Complete!"
echo "=========================================="
echo ""
echo "Upgrade: $UPGRADE_NAME"
if [ ! -z "$UPGRADE_HEIGHT" ]; then
    echo "Height: $UPGRADE_HEIGHT"
    
    # Calculate blocks remaining if we can get current height
    CURRENT_HEIGHT=$(curl -s http://localhost:${RPC_PORT}/status 2>/dev/null | jq -r '.result.sync_info.latest_block_height' || echo "")
    if [ ! -z "$CURRENT_HEIGHT" ] && [ "$CURRENT_HEIGHT" != "null" ]; then
        BLOCKS_REMAINING=$((UPGRADE_HEIGHT - CURRENT_HEIGHT))
        if [ $BLOCKS_REMAINING -gt 0 ]; then
            # Use block time from chains.yaml
            SECONDS_REMAINING=$((BLOCKS_REMAINING * BLOCK_TIME_SECONDS))
            HOURS_REMAINING=$((SECONDS_REMAINING / 3600))
            echo "Blocks Remaining: $BLOCKS_REMAINING (~$HOURS_REMAINING hours)"
        fi
    fi
fi
echo ""
echo "Cosmovisor will automatically switch to the new binary"
echo "at the upgrade height. No manual intervention required."
echo ""
echo "Monitor the upgrade:"
echo "  - Watch logs: docker-compose logs -f <chain>-validator"
echo "  - Check status: docker exec <container> /scripts/check-status.sh"
echo ""



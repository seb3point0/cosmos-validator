#!/bin/bash
set -e

echo "============================================"
echo "Cosmos Hub Snapshot Installation"
echo "============================================"
echo ""

# Configuration
SNAPSHOT_URL="${1:-https://snapshots.polkachu.com/snapshots/cosmos/cosmos_28294157.tar.lz4}"
DAEMON_HOME="/root/.gaia"

echo "Snapshot URL: $SNAPSHOT_URL"
echo "Data directory: $DAEMON_HOME"
echo ""

# Step 1: Backup priv_validator_state.json (if it exists)
echo "Step 1: Backing up priv_validator_state.json..."
if [ -f "$DAEMON_HOME/data/priv_validator_state.json" ]; then
    cp "$DAEMON_HOME/data/priv_validator_state.json" "$DAEMON_HOME/priv_validator_state.json.backup"
    echo "✓ Backed up priv_validator_state.json"
else
    echo "ℹ No priv_validator_state.json found (first time setup)"
fi
echo ""

# Step 2: Reset the node (keep address book and config)
echo "Step 2: Resetting node state..."
gaiad tendermint unsafe-reset-all --home "$DAEMON_HOME" --keep-addr-book
echo "✓ Node state reset complete"
echo ""

# Step 3: Remove wasm folder
echo "Step 3: Removing old wasm folder..."
if [ -d "$DAEMON_HOME/wasm" ]; then
    rm -rf "$DAEMON_HOME/wasm"
    echo "✓ Old wasm folder removed"
else
    echo "ℹ No wasm folder found"
fi
echo ""

# Step 4: Download snapshot
echo "Step 4: Downloading snapshot..."
echo "This may take several minutes depending on your connection..."
cd /tmp
wget -O cosmos_snapshot.tar.lz4 "$SNAPSHOT_URL" --inet4-only --show-progress
echo "✓ Snapshot downloaded"
echo ""

# Step 5: Extract snapshot
echo "Step 5: Extracting snapshot to $DAEMON_HOME..."
echo "This will take several minutes..."
lz4 -c -d cosmos_snapshot.tar.lz4 | tar -x -C "$DAEMON_HOME"
echo "✓ Snapshot extracted"
echo ""

# Step 6: Restore priv_validator_state.json
echo "Step 6: Restoring priv_validator_state.json..."
if [ -f "$DAEMON_HOME/priv_validator_state.json.backup" ]; then
    cp "$DAEMON_HOME/priv_validator_state.json.backup" "$DAEMON_HOME/data/priv_validator_state.json"
    echo "✓ priv_validator_state.json restored"
else
    echo "ℹ No backup to restore"
fi
echo ""

# Step 7: Verify wasm folder
echo "Step 7: Checking wasm folder..."
if [ -d "$DAEMON_HOME/wasm" ] && [ "$(ls -A $DAEMON_HOME/wasm)" ]; then
    echo "✓ wasm folder exists and is not empty"
else
    echo "⚠ wasm folder is empty, downloading..."
    cd /tmp
    wget -O cosmos_wasmonly.tar.lz4 https://snapshots.polkachu.com/wasm/cosmos/cosmos_wasmonly.tar.lz4 --inet4-only --show-progress
    lz4 -c -d cosmos_wasmonly.tar.lz4 | tar -x -C "$DAEMON_HOME"
    rm -f cosmos_wasmonly.tar.lz4
    echo "✓ wasm folder downloaded and extracted"
fi
echo ""

# Step 8: Clean up
echo "Step 8: Cleaning up..."
rm -f /tmp/cosmos_snapshot.tar.lz4
echo "✓ Cleanup complete"
echo ""

echo "============================================"
echo "Snapshot installation complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Exit this container"
echo "2. Run: docker-compose up -d"
echo "3. Monitor: docker logs cosmos-validator -f"
echo ""


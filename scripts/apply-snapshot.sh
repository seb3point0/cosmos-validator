#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
SNAPSHOT_URL="${1:-${SNAPSHOT_URL}}"
SNAPSHOT_WASM_URL="${SNAPSHOT_WASM_URL:-}"

if [ -z "$SNAPSHOT_URL" ]; then
    echo "Error: SNAPSHOT_URL is required" >&2
    exit 1
fi

# Backup priv_validator_state.json if it exists
if [ -f "$DAEMON_HOME/data/priv_validator_state.json" ]; then
    cp "$DAEMON_HOME/data/priv_validator_state.json" "$DAEMON_HOME/priv_validator_state.json.backup"
fi

# Reset the node (keep address book and config)
$DAEMON_NAME tendermint unsafe-reset-all --home "$DAEMON_HOME" --keep-addr-book

# Remove wasm folder
if [ -d "$DAEMON_HOME/wasm" ]; then
    rm -rf "$DAEMON_HOME/wasm"
fi

# Download snapshot
cd /tmp
wget -O chain_snapshot.tar.lz4 "$SNAPSHOT_URL" --inet4-only --quiet --show-progress

# Extract snapshot
lz4 -c -d chain_snapshot.tar.lz4 | tar -x -C "$DAEMON_HOME"

# Restore priv_validator_state.json
if [ -f "$DAEMON_HOME/priv_validator_state.json.backup" ]; then
    cp "$DAEMON_HOME/priv_validator_state.json.backup" "$DAEMON_HOME/data/priv_validator_state.json"
fi

# Verify wasm folder (if applicable)
if [ ! -z "$SNAPSHOT_WASM_URL" ]; then
    if [ ! -d "$DAEMON_HOME/wasm" ] || [ -z "$(ls -A $DAEMON_HOME/wasm 2>/dev/null)" ]; then
        cd /tmp
        wget -O chain_wasmonly.tar.lz4 "$SNAPSHOT_WASM_URL" --inet4-only --quiet --show-progress
        lz4 -c -d chain_wasmonly.tar.lz4 | tar -x -C "$DAEMON_HOME"
        rm -f chain_wasmonly.tar.lz4
    fi
fi

# Clean up
rm -f /tmp/chain_snapshot.tar.lz4

echo "INFO: Snapshot applied successfully"

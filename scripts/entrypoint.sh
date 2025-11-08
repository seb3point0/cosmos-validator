#!/bin/bash
set -e

echo "Starting ${CHAIN_NETWORK:-Cosmos} Validator Node..."
echo "Chain: ${CHAIN_ID}"
echo "Daemon: ${DAEMON_NAME}"
echo "Home: ${DAEMON_HOME}"

# Ensure required directories exist
mkdir -p "$DAEMON_HOME/backup"
mkdir -p "$DAEMON_HOME/cosmovisor/genesis/bin"
mkdir -p "$DAEMON_HOME/cosmovisor/upgrades"

# Ensure the correct binary is in cosmovisor directory (in case volume has old binary)
if [ -f "/usr/local/bin/${DAEMON_NAME}" ]; then
    cp -f "/usr/local/bin/${DAEMON_NAME}" "${DAEMON_HOME}/cosmovisor/genesis/bin/${DAEMON_NAME}"
    chmod +x "${DAEMON_HOME}/cosmovisor/genesis/bin/${DAEMON_NAME}"
fi

# Check if node is already initialized
if [ ! -f "$DAEMON_HOME/config/config.toml" ]; then
    echo "Node not initialized. Running initialization..."
    /scripts/init-node.sh
fi

# Setup keys (script is idempotent - will display address even if key exists)
echo "Setting up validator keys..."
/scripts/setup-keys.sh

# Disable automatic binary downloads to prevent architecture mismatch issues
export DAEMON_ALLOW_DOWNLOAD_BINARIES=false

echo "Starting Cosmovisor with ${DAEMON_NAME}..."
# Try with wasm skip first (for chains with wasm), fallback to normal start
exec cosmovisor run start --wasm.skip_wasmvm_version_check 2>/dev/null || exec cosmovisor run start


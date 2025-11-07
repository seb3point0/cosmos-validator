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

# Check if node is already initialized
if [ ! -f "$DAEMON_HOME/config/config.toml" ]; then
    echo "Node not initialized. Running initialization..."
    /scripts/init-node.sh
fi

# Setup keys if not already done
if [ ! -f "$DAEMON_HOME/config/priv_validator_key.json" ]; then
    echo "Setting up validator keys..."
    /scripts/setup-keys.sh
fi

echo "Starting Cosmovisor with ${DAEMON_NAME}..."
# Try with wasm skip first (for chains with wasm), fallback to normal start
exec cosmovisor run start --wasm.skip_wasmvm_version_check 2>/dev/null || exec cosmovisor run start


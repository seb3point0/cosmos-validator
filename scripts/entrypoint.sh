#!/bin/bash
set -e

echo "Starting Cosmos Hub Validator Node..."

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

echo "Starting Cosmovisor..."
exec cosmovisor run start --x-crisis-skip-assert-invariants --wasm.skip_wasmvm_version_check


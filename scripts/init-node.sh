#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
CHAIN_ID=${CHAIN_ID}
MONIKER=${MONIKER}
GENESIS_URL=${GENESIS_URL:-}
PERSISTENT_PEERS=${PERSISTENT_PEERS:-}
STATE_SYNC_RPC=${STATE_SYNC_RPC:-}
MIN_GAS_PRICES=${MIN_GAS_PRICES}
PRUNING=${PRUNING:-custom}
PRUNING_KEEP_RECENT=${PRUNING_KEEP_RECENT:-100}
PRUNING_KEEP_EVERY=${PRUNING_KEEP_EVERY:-0}
PRUNING_INTERVAL=${PRUNING_INTERVAL:-10}
P2P_PORT=${P2P_PORT:-26656}
STATE_SYNC_TRUST_HEIGHT_OFFSET=${STATE_SYNC_TRUST_HEIGHT_OFFSET:-2000}
STATE_SYNC_TRUST_PERIOD=${STATE_SYNC_TRUST_PERIOD:-168h0m0s}
TIMEOUT_COMMIT=${TIMEOUT_COMMIT:-5s}
PROMETHEUS_RETENTION_TIME=${PROMETHEUS_RETENTION_TIME:-60}

# Validate required environment variables
if [ -z "$DAEMON_HOME" ] || [ -z "$DAEMON_NAME" ] || [ -z "$CHAIN_ID" ] || [ -z "$MONIKER" ] || [ -z "$MIN_GAS_PRICES" ]; then
    echo "Error: Required environment variables not set!"
    echo "Missing: DAEMON_HOME, DAEMON_NAME, CHAIN_ID, MONIKER, or MIN_GAS_PRICES"
    exit 1
fi

echo "Initializing ${CHAIN_NETWORK:-Chain} node..."
echo "Daemon: $DAEMON_NAME"
echo "Chain ID: $CHAIN_ID"
echo "Moniker: $MONIKER"
echo "Home: $DAEMON_HOME"

# Initialize the node
$DAEMON_NAME init "$MONIKER" --chain-id "$CHAIN_ID" --home "$DAEMON_HOME"

# Download genesis file
echo "Downloading genesis file..."
cd "$DAEMON_HOME/config"
if [ ! -z "$GENESIS_URL" ]; then
    echo "Using genesis URL: $GENESIS_URL"
    curl -Lsf "$GENESIS_URL" -o genesis.json
    if [ $? -ne 0 ]; then
        echo "Error: Failed to download genesis file from $GENESIS_URL"
        exit 1
    fi
    echo "Genesis file downloaded successfully"
else
    echo "Warning: No GENESIS_URL provided, skipping genesis download"
fi

# Configure config.toml
CONFIG_FILE="$DAEMON_HOME/config/config.toml"
echo "Configuring config.toml..."

# P2P Configuration
if [ ! -z "$PERSISTENT_PEERS" ]; then
    echo "Setting persistent peers..."
    sed -i.bak "s|persistent_peers = \"\"|persistent_peers = \"$PERSISTENT_PEERS\"|" "$CONFIG_FILE"
fi

# Set external address if provided
if [ ! -z "$EXTERNAL_IP" ]; then
    sed -i.bak "s/external_address = \"\"/external_address = \"$EXTERNAL_IP:${P2P_PORT}\"/" "$CONFIG_FILE"
fi

# Enable Prometheus metrics
sed -i.bak 's/prometheus = false/prometheus = true/' "$CONFIG_FILE"

# Set timeout_commit from environment variable
sed -i.bak "s/timeout_commit = \"5s\"/timeout_commit = \"${TIMEOUT_COMMIT}\"/" "$CONFIG_FILE"

# Configure state-sync for fast sync
if [ ! -z "$STATE_SYNC_RPC" ]; then
    echo "Configuring state-sync..."
    # Split comma-separated RPC list
    IFS=',' read -ra RPC_SERVERS <<< "$STATE_SYNC_RPC"
    RPC1="${RPC_SERVERS[0]}"
    RPC2="${RPC_SERVERS[1]:-$RPC1}"
    
    echo "Using RPC servers: $RPC1, $RPC2"
    
    # Get latest block height and trust hash from RPC
    LATEST_HEIGHT=$(curl -s "$RPC1/block" | jq -r '.result.block.header.height' 2>/dev/null || echo "")
    
    if [ -n "$LATEST_HEIGHT" ] && [ "$LATEST_HEIGHT" != "null" ]; then
        TRUST_HEIGHT=$((LATEST_HEIGHT - STATE_SYNC_TRUST_HEIGHT_OFFSET))
        TRUST_HASH=$(curl -s "$RPC1/block?height=$TRUST_HEIGHT" | jq -r '.result.block_id.hash' 2>/dev/null || echo "")
    
    if [ -n "$TRUST_HASH" ] && [ "$TRUST_HASH" != "null" ]; then
        echo "State-sync configuration:"
        echo "Latest height: $LATEST_HEIGHT"
        echo "Trust height: $TRUST_HEIGHT"
        echo "Trust hash: $TRUST_HASH"
        
        # Enable state-sync in the [statesync] section
        sed -i.bak '/\[statesync\]/,/^enable =/ s/enable = false/enable = true/' "$CONFIG_FILE"
        sed -i.bak "s|rpc_servers = \"\"|rpc_servers = \"$RPC1,$RPC2\"|" "$CONFIG_FILE"
        sed -i.bak "s/trust_height = 0/trust_height = $TRUST_HEIGHT/" "$CONFIG_FILE"
        sed -i.bak "s/trust_hash = \"\"/trust_hash = \"$TRUST_HASH\"/" "$CONFIG_FILE"
        sed -i.bak "s|trust_period = \"168h0m0s\"|trust_period = \"${STATE_SYNC_TRUST_PERIOD}\"|" "$CONFIG_FILE"
        echo "State-sync enabled successfully"
    else
        echo "Warning: Could not fetch trust hash. Skipping state-sync setup."
        echo "Node will sync from peers (this may take longer)."
    fi
    else
        echo "Warning: Could not fetch latest height. Skipping state-sync setup."
        echo "Node will sync from peers (this may take longer)."
    fi
else
    echo "No STATE_SYNC_RPC configured. Skipping state-sync setup."
fi

# Configure app.toml
APP_CONFIG="$DAEMON_HOME/config/app.toml"
echo "Configuring app.toml..."

# Set minimum gas prices
echo "Setting minimum gas prices to: $MIN_GAS_PRICES"
sed -i.bak "s/minimum-gas-prices = \"\"/minimum-gas-prices = \"$MIN_GAS_PRICES\"/" "$APP_CONFIG"

# Enable API
sed -i.bak '/\[api\]/,/\[/ s/enable = false/enable = true/' "$APP_CONFIG"

# Enable gRPC
sed -i.bak '/\[grpc\]/,/\[/ s/enable = false/enable = true/' "$APP_CONFIG"

# Configure pruning
echo "Configuring pruning: $PRUNING"
sed -i.bak "s/pruning = \"default\"/pruning = \"$PRUNING\"/" "$APP_CONFIG"
sed -i.bak "s/pruning-keep-recent = \"0\"/pruning-keep-recent = \"$PRUNING_KEEP_RECENT\"/" "$APP_CONFIG"
sed -i.bak "s/pruning-keep-every = \"0\"/pruning-keep-every = \"$PRUNING_KEEP_EVERY\"/" "$APP_CONFIG"
sed -i.bak "s/pruning-interval = \"0\"/pruning-interval = \"$PRUNING_INTERVAL\"/" "$APP_CONFIG"

# Enable telemetry for Prometheus
sed -i.bak 's/enabled = false/enabled = true/' "$APP_CONFIG" 
sed -i.bak "s/prometheus-retention-time = 0/prometheus-retention-time = ${PROMETHEUS_RETENTION_TIME}/" "$APP_CONFIG"

echo "Note: Snapshot download skipped for initial setup."
echo "The node will sync from the network using state-sync or from peers."
if [ ! -z "$SNAPSHOT_URL" ]; then
    echo "To use a snapshot later, run the apply-snapshot script with: $SNAPSHOT_URL"
fi

# Clean up backup files
rm -f "$CONFIG_FILE.bak" "$APP_CONFIG.bak"

echo "Node initialization complete!"


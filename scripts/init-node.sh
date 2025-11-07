#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME:-/root/.gaia}
CHAIN_ID=${CHAIN_ID:-cosmoshub-4}
MONIKER=${MONIKER:-my-validator}

echo "Initializing Cosmos Hub node..."
echo "Chain ID: $CHAIN_ID"
echo "Moniker: $MONIKER"

# Initialize the node
gaiad init "$MONIKER" --chain-id "$CHAIN_ID" --home "$DAEMON_HOME"

# Download a minimal genesis file (will be replaced by state-sync)
echo "Downloading genesis file..."
cd "$DAEMON_HOME/config"
# Use a lightweight genesis from a reliable source
curl -Lsf "https://snapshots.polkachu.com/genesis/cosmos/genesis.json" -o genesis.json
if [ $? -ne 0 ]; then
    echo "Trying alternative genesis source..."
    curl -Lsf "https://rpc.cosmos.network/genesis" | jq '.result.genesis' > genesis.json
fi
echo "Genesis file downloaded"

# Configure config.toml
CONFIG_FILE="$DAEMON_HOME/config/config.toml"
echo "Configuring config.toml..."

# P2P Configuration  
# Add persistent peers from cosmos.directory
PEERS="bf8328b66dceb4987e5cd94430af66045e59899f@public-seed.cosmos.vitwit.com:26656,cfd785a4224c7940e9a10f6c1ab24c343e923bec@164.68.107.188:26656,d72b3011ed46d783e369fdf8ae2055b99a1e5074@173.249.50.25:26656"
sed -i.bak "s|persistent_peers = \"\"|persistent_peers = \"$PEERS\"|" "$CONFIG_FILE"

# Set external address if provided
if [ ! -z "$EXTERNAL_IP" ]; then
    sed -i.bak "s/external_address = \"\"/external_address = \"$EXTERNAL_IP:26656\"/" "$CONFIG_FILE"
fi

# Enable Prometheus metrics
sed -i.bak 's/prometheus = false/prometheus = true/' "$CONFIG_FILE"

# Increase timeout_commit for better performance
sed -i.bak 's/timeout_commit = "5s"/timeout_commit = "5s"/' "$CONFIG_FILE"

# Configure state-sync for fast sync
echo "Configuring state-sync..."
# Use Polkachu's state sync configuration
RPC1="https://cosmos-rpc.polkachu.com:443"
RPC2="https://rpc.cosmos.network:443"

# Get latest block height and trust hash from RPC  
LATEST_HEIGHT=$(curl -s https://cosmos-rpc.polkachu.com/block | jq -r '.result.block.header.height' 2>/dev/null || echo "")

if [ -n "$LATEST_HEIGHT" ] && [ "$LATEST_HEIGHT" != "null" ]; then
    TRUST_HEIGHT=$((LATEST_HEIGHT - 2000))
    TRUST_HASH=$(curl -s "https://cosmos-rpc.polkachu.com/block?height=$TRUST_HEIGHT" | jq -r '.result.block_id.hash' 2>/dev/null || echo "")
    
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
        sed -i.bak "s/trust_period = \"168h0m0s\"/trust_period = \"168h0m0s\"/" "$CONFIG_FILE"
        echo "State-sync enabled successfully"
    else
        echo "Warning: Could not fetch trust hash. Skipping state-sync setup."
        echo "Node will sync from peers (this may take longer)."
    fi
else
    echo "Warning: Could not fetch latest height. Skipping state-sync setup."
    echo "Node will sync from peers (this may take longer)."
fi

# Configure pruning for validators
APP_CONFIG="$DAEMON_HOME/config/app.toml"
echo "Configuring app.toml..."

# Set minimum gas prices (use env var if provided, otherwise use default)
MIN_GAS_PRICES=${MIN_GAS_PRICES:-"0.005uatom"}
echo "Setting minimum gas prices to: $MIN_GAS_PRICES"
sed -i.bak "s/minimum-gas-prices = \"\"/minimum-gas-prices = \"$MIN_GAS_PRICES\"/" "$APP_CONFIG"

# Enable API
sed -i.bak '/\[api\]/,/\[/ s/enable = false/enable = true/' "$APP_CONFIG"

# Enable gRPC
sed -i.bak '/\[grpc\]/,/\[/ s/enable = false/enable = true/' "$APP_CONFIG"

# Configure pruning (custom for validators)
sed -i.bak 's/pruning = "default"/pruning = "custom"/' "$APP_CONFIG"
sed -i.bak 's/pruning-keep-recent = "0"/pruning-keep-recent = "100"/' "$APP_CONFIG"
sed -i.bak 's/pruning-keep-every = "0"/pruning-keep-every = "0"/' "$APP_CONFIG"
sed -i.bak 's/pruning-interval = "0"/pruning-interval = "10"/' "$APP_CONFIG"

# Enable telemetry for Prometheus
sed -i.bak 's/enabled = false/enabled = true/' "$APP_CONFIG" 
sed -i.bak 's/prometheus-retention-time = 0/prometheus-retention-time = 60/' "$APP_CONFIG"

echo "Note: Snapshot download skipped for initial setup."
echo "The node will sync from the network. This may take several hours."
echo "To use a snapshot, you can manually download from https://polkachu.com/tendermint_snapshots/cosmos"

# Clean up backup files
rm -f "$CONFIG_FILE.bak" "$APP_CONFIG.bak"

echo "Node initialization complete!"


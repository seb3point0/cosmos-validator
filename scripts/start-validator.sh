#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
CHAIN_ID=${CHAIN_ID}
RPC_PORT=${RPC_PORT}
MIN_GAS_PRICES=${MIN_GAS_PRICES}
MIN_SELF_DELEGATION=${MIN_SELF_DELEGATION:-1000000}
DENOM=${DENOM}

# Validator metadata
VALIDATOR_NAME=${VALIDATOR_NAME:-${MONIKER}}
VALIDATOR_WEBSITE=${VALIDATOR_WEBSITE:-""}
VALIDATOR_IDENTITY=${VALIDATOR_IDENTITY:-""}
VALIDATOR_DETAILS=${VALIDATOR_DETAILS:-"A reliable validator"}
VALIDATOR_SECURITY_CONTACT=${VALIDATOR_SECURITY_CONTACT:-""}

# Commission rates
COMMISSION_RATE=${COMMISSION_RATE:-0.10}
COMMISSION_MAX_RATE=${COMMISSION_MAX_RATE:-0.20}
COMMISSION_MAX_CHANGE_RATE=${COMMISSION_MAX_CHANGE_RATE:-0.01}

# Gas adjustment
GAS_ADJUSTMENT=${GAS_ADJUSTMENT:-1.5}

# Validate required environment variables
if [ -z "$DAEMON_HOME" ] || [ -z "$DAEMON_NAME" ] || [ -z "$CHAIN_ID" ] || [ -z "$RPC_PORT" ]; then
    echo "Error: Required environment variables not set: DAEMON_HOME, DAEMON_NAME, CHAIN_ID, or RPC_PORT" >&2
    exit 1
fi

# Check if node is synced
SYNC_INFO=$(curl -s http://localhost:${RPC_PORT}/status | jq -r '.result.sync_info')
CATCHING_UP=$(echo "$SYNC_INFO" | jq -r '.catching_up')

if [ "$CATCHING_UP" = "true" ]; then
    echo "Error: Node is still catching up" >&2
    exit 1
fi

# Get validator address
VALIDATOR_ADDRESS=$($DAEMON_NAME keys show validator -a --keyring-backend test --home "$DAEMON_HOME")

# Get validator public key
VALIDATOR_PUBKEY=$($DAEMON_NAME tendermint show-validator --home "$DAEMON_HOME")

# Create validator JSON file
VALIDATOR_JSON="$DAEMON_HOME/validator.json"
cat > "$VALIDATOR_JSON" <<EOF
{
    "pubkey": $VALIDATOR_PUBKEY,
    "amount": "${MIN_SELF_DELEGATION}${DENOM}",
    "moniker": "$VALIDATOR_NAME",
    "identity": "$VALIDATOR_IDENTITY",
    "website": "$VALIDATOR_WEBSITE",
    "security": "$VALIDATOR_SECURITY_CONTACT",
    "details": "$VALIDATOR_DETAILS",
    "commission-rate": "$COMMISSION_RATE",
    "commission-max-rate": "$COMMISSION_MAX_RATE",
    "commission-max-change-rate": "$COMMISSION_MAX_CHANGE_RATE",
    "min-self-delegation": "1"
}
EOF

# Create validator using JSON file
$DAEMON_NAME tx staking create-validator "$VALIDATOR_JSON" \
    --from=validator \
    --keyring-backend=test \
    --chain-id="$CHAIN_ID" \
    --gas="auto" \
    --gas-adjustment="${GAS_ADJUSTMENT}" \
    --gas-prices="$MIN_GAS_PRICES" \
    --home="$DAEMON_HOME" \
    --node=http://localhost:${RPC_PORT} \
    --yes

# Clean up
rm -f "$VALIDATOR_JSON"

echo "INFO: Validator creation transaction submitted"

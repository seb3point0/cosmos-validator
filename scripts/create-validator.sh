#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
CHAIN_ID=${CHAIN_ID}
MONIKER=${MONIKER}
DENOM=${DENOM}
DENOM_DISPLAY=${DENOM_DISPLAY}
MIN_GAS_PRICES=${MIN_GAS_PRICES}
RPC_PORT=${RPC_PORT}
MIN_SELF_DELEGATION=${MIN_SELF_DELEGATION:-1000000}
DECIMALS=${DECIMALS:-6}

# Validate required environment variables
if [ -z "$DAEMON_HOME" ] || [ -z "$DAEMON_NAME" ] || [ -z "$CHAIN_ID" ] || [ -z "$RPC_PORT" ]; then
    echo "Error: Required environment variables not set!"
    echo "Missing: DAEMON_HOME, DAEMON_NAME, CHAIN_ID, or RPC_PORT"
    exit 1
fi

# Validator metadata (can be overridden by environment variables)
VALIDATOR_NAME=${VALIDATOR_NAME:-$MONIKER}
VALIDATOR_WEBSITE=${VALIDATOR_WEBSITE:-""}
VALIDATOR_IDENTITY=${VALIDATOR_IDENTITY:-""}
VALIDATOR_DETAILS=${VALIDATOR_DETAILS:-"A validator"}
VALIDATOR_SECURITY_CONTACT=${VALIDATOR_SECURITY_CONTACT:-""}

# Commission rates
COMMISSION_RATE=${COMMISSION_RATE:-0.10}
COMMISSION_MAX_RATE=${COMMISSION_MAX_RATE:-0.20}
COMMISSION_MAX_CHANGE_RATE=${COMMISSION_MAX_CHANGE_RATE:-0.01}

echo "${CHAIN_NETWORK:-Chain} Validator Creation"
echo "=============================="
echo ""

# Check if node is synced
echo "Checking sync status..."
SYNC_INFO=$(curl -s http://localhost:${RPC_PORT}/status | jq -r '.result.sync_info')
CATCHING_UP=$(echo "$SYNC_INFO" | jq -r '.catching_up')
LATEST_BLOCK_HEIGHT=$(echo "$SYNC_INFO" | jq -r '.latest_block_height')

if [ "$CATCHING_UP" = "true" ]; then
    echo "❌ Error: Node is still catching up!"
    echo "Current block height: $LATEST_BLOCK_HEIGHT"
    echo "Please wait for the node to fully sync before creating the validator."
    exit 1
fi

echo "✓ Node is fully synced at block height: $LATEST_BLOCK_HEIGHT"
echo ""

# Get validator address
VALIDATOR_ADDRESS=$($DAEMON_NAME keys show validator -a --keyring-backend test --home "$DAEMON_HOME")
echo "Validator address: $VALIDATOR_ADDRESS"

# Check account balance
echo "Checking account balance..."
BALANCE=$($DAEMON_NAME query bank balances "$VALIDATOR_ADDRESS" --node http://localhost:${RPC_PORT} --output json | jq -r ".balances[] | select(.denom==\"$DENOM\") | .amount")

if [ -z "$BALANCE" ] || [ "$BALANCE" = "null" ]; then
    echo "❌ Error: No balance found!"
    echo "Please send at least 2 $DENOM_DISPLAY to: $VALIDATOR_ADDRESS"
    exit 1
fi

DIVISOR=$(printf "1%0${DECIMALS}d" 0)
BALANCE_DISPLAY=$(echo "scale=$DECIMALS; $BALANCE / $DIVISOR" | bc)
echo "Current balance: $BALANCE_DISPLAY $DENOM_DISPLAY ($BALANCE $DENOM)"

BUFFER=$(printf "1%0${DECIMALS}d" 0)
REQUIRED_BALANCE=$((MIN_SELF_DELEGATION + BUFFER))
if [ "$BALANCE" -lt "$REQUIRED_BALANCE" ]; then
    echo "❌ Error: Insufficient balance!"
    REQUIRED_DISPLAY=$(echo "scale=$DECIMALS; $REQUIRED_BALANCE / $DIVISOR" | bc)
    echo "Please send at least $REQUIRED_DISPLAY $DENOM_DISPLAY to cover self-delegation and fees."
    exit 1
fi

echo "✓ Sufficient balance available"
echo ""

# Get validator public key
VALIDATOR_PUBKEY=$($DAEMON_NAME tendermint show-validator --home "$DAEMON_HOME")
echo "Validator public key: $VALIDATOR_PUBKEY"
echo ""

# Display validator configuration
echo "Validator Configuration:"
echo "----------------------"
echo "Moniker: $VALIDATOR_NAME"
echo "Website: $VALIDATOR_WEBSITE"
echo "Identity: $VALIDATOR_IDENTITY"
echo "Details: $VALIDATOR_DETAILS"
echo "Security Contact: $VALIDATOR_SECURITY_CONTACT"
echo "Commission Rate: $COMMISSION_RATE"
echo "Commission Max Rate: $COMMISSION_MAX_RATE"
echo "Commission Max Change Rate: $COMMISSION_MAX_CHANGE_RATE"
DIVISOR=$(printf "1%0${DECIMALS}d" 0)
SELF_DELEGATION_DISPLAY=$(echo "scale=$DECIMALS; $MIN_SELF_DELEGATION / $DIVISOR" | bc)
echo "Self Delegation: $MIN_SELF_DELEGATION $DENOM ($SELF_DELEGATION_DISPLAY $DENOM_DISPLAY)"
echo ""

read -p "Do you want to proceed with validator creation? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Validator creation cancelled."
    exit 0
fi

echo ""
echo "Creating validator transaction..."

# Create validator JSON file (required for Gaia v25.1.0+)
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
    --gas-adjustment="1.5" \
    --gas-prices="$MIN_GAS_PRICES" \
    --home="$DAEMON_HOME" \
    --node=http://localhost:${RPC_PORT} \
    --yes

# Clean up
rm -f "$VALIDATOR_JSON"

echo ""
echo "✓ Validator creation transaction submitted!"
echo ""
echo "Please wait a few blocks for the transaction to be confirmed."
echo "You can check your validator status with:"
echo "  docker exec <container> /scripts/check-status.sh"
echo ""
echo "To edit your validator description later, use:"
echo "  $DAEMON_NAME tx staking edit-validator --website=\"URL\" --identity=\"KEYBASE\" ..."
echo ""


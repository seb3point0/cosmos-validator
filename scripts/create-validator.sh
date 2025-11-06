#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME:-/root/.gaia}
CHAIN_ID=${CHAIN_ID:-cosmoshub-4}
MONIKER=${MONIKER:-my-validator}

# Validator metadata (can be overridden by environment variables)
VALIDATOR_NAME=${VALIDATOR_NAME:-$MONIKER}
VALIDATOR_WEBSITE=${VALIDATOR_WEBSITE:-""}
VALIDATOR_IDENTITY=${VALIDATOR_IDENTITY:-""}
VALIDATOR_DETAILS=${VALIDATOR_DETAILS:-"A Cosmos Hub validator"}
VALIDATOR_SECURITY_CONTACT=${VALIDATOR_SECURITY_CONTACT:-""}

# Commission rates
COMMISSION_RATE=${COMMISSION_RATE:-0.10}
COMMISSION_MAX_RATE=${COMMISSION_MAX_RATE:-0.20}
COMMISSION_MAX_CHANGE_RATE=${COMMISSION_MAX_CHANGE_RATE:-0.01}

echo "Cosmos Hub Validator Creation"
echo "=============================="
echo ""

# Check if node is synced
echo "Checking sync status..."
SYNC_INFO=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info')
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
VALIDATOR_ADDRESS=$(gaiad keys show validator -a --keyring-backend test --home "$DAEMON_HOME")
echo "Validator address: $VALIDATOR_ADDRESS"

# Check account balance
echo "Checking account balance..."
BALANCE=$(gaiad query bank balances "$VALIDATOR_ADDRESS" --node http://localhost:26657 --output json | jq -r '.balances[] | select(.denom=="uatom") | .amount')

if [ -z "$BALANCE" ] || [ "$BALANCE" = "null" ]; then
    echo "❌ Error: No balance found!"
    echo "Please send at least 2000000 uatom (2 ATOM) to: $VALIDATOR_ADDRESS"
    exit 1
fi

BALANCE_ATOM=$((BALANCE / 1000000))
echo "Current balance: $BALANCE_ATOM ATOM ($BALANCE uatom)"

if [ "$BALANCE" -lt 2000000 ]; then
    echo "❌ Error: Insufficient balance!"
    echo "Please send at least 2 ATOM to cover self-delegation and fees."
    exit 1
fi

echo "✓ Sufficient balance available"
echo ""

# Get validator public key
VALIDATOR_PUBKEY=$(gaiad tendermint show-validator --home "$DAEMON_HOME")
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
echo "Self Delegation: 1000000 uatom (1 ATOM)"
echo ""

read -p "Do you want to proceed with validator creation? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Validator creation cancelled."
    exit 0
fi

echo ""
echo "Creating validator transaction..."

# Create validator
gaiad tx staking create-validator \
    --amount=1000000uatom \
    --pubkey="$VALIDATOR_PUBKEY" \
    --moniker="$VALIDATOR_NAME" \
    --chain-id="$CHAIN_ID" \
    --commission-rate="$COMMISSION_RATE" \
    --commission-max-rate="$COMMISSION_MAX_RATE" \
    --commission-max-change-rate="$COMMISSION_MAX_CHANGE_RATE" \
    --min-self-delegation="1" \
    --gas="auto" \
    --gas-adjustment="1.5" \
    --gas-prices="0.0025uatom" \
    --from=validator \
    --keyring-backend=test \
    --home="$DAEMON_HOME" \
    --node=http://localhost:26657 \
    --yes

echo ""
echo "✓ Validator creation transaction submitted!"
echo ""
echo "Please wait a few blocks for the transaction to be confirmed."
echo "You can check your validator status with:"
echo "  docker exec cosmos-validator /scripts/check-status.sh"
echo ""
echo "To edit your validator description later, use:"
echo "  gaiad tx staking edit-validator --website=\"URL\" --identity=\"KEYBASE\" ..."
echo ""


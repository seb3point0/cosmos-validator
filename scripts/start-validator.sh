#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME:-/root/.gaia}
CHAIN_ID=${CHAIN_ID:-cosmoshub-4}
MONIKER=${MONIKER:-my-validator}

# Validator metadata
VALIDATOR_NAME=${VALIDATOR_NAME:-$MONIKER}
VALIDATOR_WEBSITE=${VALIDATOR_WEBSITE:-""}
VALIDATOR_IDENTITY=${VALIDATOR_IDENTITY:-""}
VALIDATOR_DETAILS=${VALIDATOR_DETAILS:-"A Cosmos Hub validator"}
VALIDATOR_SECURITY_CONTACT=${VALIDATOR_SECURITY_CONTACT:-""}

# Commission rates
COMMISSION_RATE=${COMMISSION_RATE:-0.10}
COMMISSION_MAX_RATE=${COMMISSION_MAX_RATE:-0.20}
COMMISSION_MAX_CHANGE_RATE=${COMMISSION_MAX_CHANGE_RATE:-0.01}

# Self delegation amount (1 ATOM = 1000000 uatom)
SELF_DELEGATION=${SELF_DELEGATION:-1000000}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "======================================"
echo "🚀 Cosmos Hub Validator Starter"
echo "======================================"
echo ""

# Function to check if node is responsive
check_node() {
    if ! curl -s http://localhost:26657/status > /dev/null 2>&1; then
        echo -e "${RED}❌ Error: Node is not running or not responding${NC}"
        echo "Please ensure the node is running: docker-compose up -d"
        exit 1
    fi
}

# Function to check sync status
check_sync() {
    echo -e "${BLUE}📊 Checking sync status...${NC}"
    SYNC_INFO=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info')
    CATCHING_UP=$(echo "$SYNC_INFO" | jq -r '.catching_up')
    LATEST_BLOCK_HEIGHT=$(echo "$SYNC_INFO" | jq -r '.latest_block_height')
    LATEST_BLOCK_TIME=$(echo "$SYNC_INFO" | jq -r '.latest_block_time')
    
    echo "Latest Block Height: $LATEST_BLOCK_HEIGHT"
    echo "Latest Block Time: $LATEST_BLOCK_TIME"
    echo ""
    
    if [ "$CATCHING_UP" = "true" ]; then
        return 1
    else
        return 0
    fi
}

# Function to check if validator key exists
check_validator_key() {
    if ! gaiad keys show validator --keyring-backend test --home "$DAEMON_HOME" > /dev/null 2>&1; then
        echo -e "${RED}❌ Error: Validator key not found!${NC}"
        echo ""
        echo "Please create a validator key first:"
        echo "  docker exec -it cosmos-validator gaiad keys add validator --keyring-backend test"
        echo ""
        echo "Or import an existing mnemonic:"
        echo "  echo \"your mnemonic\" > secrets/validator_mnemonic.txt"
        echo "  docker-compose restart cosmos-node"
        exit 1
    fi
}

# Function to check if validator already exists
check_validator_exists() {
    VALIDATOR_ADDRESS=$(gaiad keys show validator -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null)
    VALOPER_ADDRESS=$(gaiad keys show validator --bech val -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null)
    
    VALIDATOR_INFO=$(gaiad query staking validator "$VALOPER_ADDRESS" --node http://localhost:26657 --output json 2>/dev/null || echo "{}")
    
    if [ "$VALIDATOR_INFO" != "{}" ] && [ "$VALIDATOR_INFO" != "null" ]; then
        echo -e "${GREEN}✓ Validator is already registered!${NC}"
        echo ""
        echo "Validator Address: $VALIDATOR_ADDRESS"
        echo "Operator Address: $VALOPER_ADDRESS"
        echo ""
        
        STATUS=$(echo "$VALIDATOR_INFO" | jq -r '.status')
        TOKENS=$(echo "$VALIDATOR_INFO" | jq -r '.tokens')
        JAILED=$(echo "$VALIDATOR_INFO" | jq -r '.jailed')
        
        TOKENS_ATOM=$(echo "scale=6; $TOKENS / 1000000" | bc)
        
        echo "Status: $STATUS"
        echo "Jailed: $JAILED"
        echo "Total Delegated: $TOKENS_ATOM ATOM"
        echo ""
        echo "Run /scripts/check-status.sh for detailed status."
        exit 0
    fi
}

# Function to check balance
check_balance() {
    VALIDATOR_ADDRESS=$(gaiad keys show validator -a --keyring-backend test --home "$DAEMON_HOME")
    echo -e "${BLUE}💰 Checking account balance...${NC}"
    echo "Address: $VALIDATOR_ADDRESS"
    
    BALANCES=$(gaiad query bank balances "$VALIDATOR_ADDRESS" --node http://localhost:26657 --output json 2>/dev/null)
    ATOM_BALANCE=$(echo "$BALANCES" | jq -r '.balances[] | select(.denom=="uatom") | .amount')
    
    if [ -z "$ATOM_BALANCE" ] || [ "$ATOM_BALANCE" = "null" ]; then
        echo -e "${RED}❌ Error: No balance found!${NC}"
        echo ""
        echo "Please send at least 2 ATOM to: $VALIDATOR_ADDRESS"
        echo ""
        echo "This covers:"
        echo "  - 1 ATOM for self-delegation"
        echo "  - ~1 ATOM for transaction fees and buffer"
        exit 1
    fi
    
    ATOM_BALANCE_DISPLAY=$(echo "scale=6; $ATOM_BALANCE / 1000000" | bc)
    echo "Balance: $ATOM_BALANCE_DISPLAY ATOM ($ATOM_BALANCE uatom)"
    
    REQUIRED_BALANCE=$((SELF_DELEGATION + 1000000))
    if [ "$ATOM_BALANCE" -lt "$REQUIRED_BALANCE" ]; then
        echo -e "${RED}❌ Error: Insufficient balance!${NC}"
        echo "Required: $(echo "scale=6; $REQUIRED_BALANCE / 1000000" | bc) ATOM"
        echo "Please send more ATOM to your address."
        exit 1
    fi
    
    echo -e "${GREEN}✓ Sufficient balance available${NC}"
    echo ""
}

# Function to create validator
create_validator() {
    echo -e "${BLUE}🔑 Preparing validator creation...${NC}"
    
    VALIDATOR_PUBKEY=$(gaiad tendermint show-validator --home "$DAEMON_HOME")
    VALIDATOR_ADDRESS=$(gaiad keys show validator -a --keyring-backend test --home "$DAEMON_HOME")
    
    echo ""
    echo "======================================"
    echo "Validator Configuration"
    echo "======================================"
    echo "Moniker: $VALIDATOR_NAME"
    echo "Website: ${VALIDATOR_WEBSITE:-"(not set)"}"
    echo "Identity: ${VALIDATOR_IDENTITY:-"(not set)"}"
    echo "Details: $VALIDATOR_DETAILS"
    echo "Security Contact: ${VALIDATOR_SECURITY_CONTACT:-"(not set)"}"
    echo "Commission Rate: $COMMISSION_RATE"
    echo "Commission Max Rate: $COMMISSION_MAX_RATE"
    echo "Commission Max Change Rate: $COMMISSION_MAX_CHANGE_RATE"
    echo "Self Delegation: $(echo "scale=6; $SELF_DELEGATION / 1000000" | bc) ATOM"
    echo "======================================"
    echo ""
    
    echo -e "${YELLOW}⚠️  Review the configuration above carefully!${NC}"
    echo ""
    
    if [ "$AUTO_CONFIRM" != "yes" ]; then
        read -p "Do you want to proceed with validator creation? (yes/no): " CONFIRM
        if [ "$CONFIRM" != "yes" ]; then
            echo "Validator creation cancelled."
            exit 0
        fi
    fi
    
    echo ""
    echo -e "${BLUE}📝 Submitting validator creation transaction...${NC}"
    
    # Create validator JSON file (required for Gaia v25.1.0+)
    VALIDATOR_JSON="$DAEMON_HOME/validator.json"
    cat > "$VALIDATOR_JSON" <<EOF
{
    "pubkey": $VALIDATOR_PUBKEY,
    "amount": "${SELF_DELEGATION}uatom",
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
    gaiad tx staking create-validator "$VALIDATOR_JSON" \
        --from=validator \
        --keyring-backend=test \
        --chain-id="$CHAIN_ID" \
        --gas="auto" \
        --gas-adjustment="1.5" \
        --gas-prices="0.005uatom" \
        --home="$DAEMON_HOME" \
        --node=http://localhost:26657 \
        --yes
    
    # Clean up
    rm -f "$VALIDATOR_JSON"
    
    echo ""
    echo -e "${GREEN}✓ Validator creation transaction submitted!${NC}"
    echo ""
    
    # Get validator operator address for display
    VALOPER_ADDRESS=$(gaiad keys show validator --bech val -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null || echo "")
    
    echo "======================================"
    echo "🎉 Next Steps"
    echo "======================================"
    echo ""
    echo "1. Wait a few blocks for the transaction to be confirmed (1-2 minutes)"
    echo ""
    echo "2. Check your validator status:"
    echo "   docker exec cosmos-validator /scripts/check-status.sh"
    echo ""
    if [ ! -z "$VALOPER_ADDRESS" ]; then
        echo "3. View your validator on block explorers:"
        echo "   https://www.mintscan.io/cosmos/validators/$VALOPER_ADDRESS"
        echo ""
    fi
    echo "4. Edit your validator description (optional):"
    echo "   docker exec -it cosmos-validator gaiad tx staking edit-validator \\"
    echo "     --website=\"https://yoursite.com\" \\"
    echo "     --identity=\"YOUR_KEYBASE_ID\" \\"
    echo "     --from=validator \\"
    echo "     --chain-id=cosmoshub-4"
    echo ""
    echo "5. Monitor your validator:"
    echo "   - Grafana: http://localhost:3001"
    echo "   - Logs: docker logs cosmos-validator -f"
    echo ""
    echo "======================================"
}

# Main execution
echo "Step 1: Checking node status..."
check_node
echo -e "${GREEN}✓ Node is running${NC}"
echo ""

echo "Step 2: Checking sync status..."
if check_sync; then
    echo -e "${GREEN}✓ Node is fully synced!${NC}"
    echo ""
else
    echo -e "${YELLOW}⏳ Node is still syncing...${NC}"
    echo ""
    echo "The validator can only be created after the node is fully synced."
    echo ""
    echo "To monitor sync progress:"
    echo "  docker logs cosmos-validator -f"
    echo ""
    echo "To check status later:"
    echo "  docker exec cosmos-validator /scripts/start-validator.sh"
    exit 1
fi

echo "Step 3: Checking validator key..."
check_validator_key
echo -e "${GREEN}✓ Validator key found${NC}"
echo ""

echo "Step 4: Checking if validator already exists..."
check_validator_exists

echo "Step 5: Checking account balance..."
check_balance

echo "Step 6: Creating validator..."
create_validator


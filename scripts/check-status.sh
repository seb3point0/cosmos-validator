#!/bin/bash

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
CHAIN_ID=${CHAIN_ID}
CHAIN_NETWORK=${CHAIN_NETWORK}
DENOM=${DENOM}
DENOM_DISPLAY=${DENOM_DISPLAY}
DECIMALS=${DECIMALS:-6}
RPC_PORT=${RPC_PORT}

# Validate required environment variables
if [ -z "$DAEMON_HOME" ] || [ -z "$DAEMON_NAME" ] || [ -z "$RPC_PORT" ]; then
    echo "Error: Required environment variables not set!"
    echo "Missing: DAEMON_HOME, DAEMON_NAME, or RPC_PORT"
    exit 1
fi

echo "${CHAIN_NETWORK:-Chain} Validator Status"
echo "============================"
echo "Chain ID: $CHAIN_ID"
echo ""

# Check if node is running
if ! curl -s http://localhost:${RPC_PORT}/status > /dev/null 2>&1; then
    echo "❌ Error: Node is not running or not responding on port ${RPC_PORT}"
    exit 1
fi

# Sync status
echo "📊 Sync Status:"
echo "---------------"
SYNC_INFO=$(curl -s http://localhost:${RPC_PORT}/status | jq -r '.result.sync_info')
CATCHING_UP=$(echo "$SYNC_INFO" | jq -r '.catching_up')
LATEST_BLOCK_HEIGHT=$(echo "$SYNC_INFO" | jq -r '.latest_block_height')
LATEST_BLOCK_TIME=$(echo "$SYNC_INFO" | jq -r '.latest_block_time')

if [ "$CATCHING_UP" = "true" ]; then
    echo "Status: ⏳ Catching up..."
else
    echo "Status: ✓ Fully synced"
fi
echo "Latest Block Height: $LATEST_BLOCK_HEIGHT"
echo "Latest Block Time: $LATEST_BLOCK_TIME"
echo ""

# Network info
echo "🌐 Network Info:"
echo "----------------"
NET_INFO=$(curl -s http://localhost:${RPC_PORT}/net_info | jq -r '.result')
N_PEERS=$(echo "$NET_INFO" | jq -r '.n_peers')
echo "Connected Peers: $N_PEERS"
echo ""

# Validator info
echo "🔑 Validator Info:"
echo "------------------"
VALIDATOR_ADDRESS=$($DAEMON_NAME keys show validator -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null)
if [ ! -z "$VALIDATOR_ADDRESS" ]; then
    echo "Validator Address: $VALIDATOR_ADDRESS"
    
    # Get operator address (valoper)
    VALOPER_ADDRESS=$($DAEMON_NAME keys show validator --bech val -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null)
    echo "Operator Address: $VALOPER_ADDRESS"
    
    # Check if validator exists
    VALIDATOR_INFO=$($DAEMON_NAME query staking validator "$VALOPER_ADDRESS" --node http://localhost:${RPC_PORT} --output json 2>/dev/null || echo "{}")
    
    if [ "$VALIDATOR_INFO" != "{}" ] && [ ! -z "$VALIDATOR_INFO" ]; then
        echo ""
        echo "✓ Validator is registered!"
        
        STATUS=$(echo "$VALIDATOR_INFO" | jq -r '.status')
        TOKENS=$(echo "$VALIDATOR_INFO" | jq -r '.tokens')
        DELEGATOR_SHARES=$(echo "$VALIDATOR_INFO" | jq -r '.delegator_shares')
        JAILED=$(echo "$VALIDATOR_INFO" | jq -r '.jailed')
        
        # Convert tokens to display denom
        DIVISOR=$(printf "1%0${DECIMALS}d" 0)
        TOKENS_DISPLAY=$(echo "scale=$DECIMALS; $TOKENS / $DIVISOR" | bc)
        
        echo "Status: $STATUS"
        echo "Jailed: $JAILED"
        echo "Total Delegated: $TOKENS_DISPLAY $DENOM_DISPLAY"
        echo "Delegator Shares: $DELEGATOR_SHARES"
        
        # Check signing info (may not work for all chains)
        CONSENSUS_PUBKEY=$(echo "$VALIDATOR_INFO" | jq -r '.consensus_pubkey.key')
        if [ ! -z "$CONSENSUS_PUBKEY" ] && [ "$CONSENSUS_PUBKEY" != "null" ]; then
            SIGNING_INFO=$($DAEMON_NAME query slashing signing-info "$CONSENSUS_PUBKEY" --node http://localhost:${RPC_PORT} --output json 2>/dev/null || echo "{}")
            
            if [ "$SIGNING_INFO" != "{}" ]; then
                MISSED_BLOCKS=$(echo "$SIGNING_INFO" | jq -r '.val_signing_info.missed_blocks_counter // .missed_blocks_counter // "0"')
                echo "Missed Blocks: $MISSED_BLOCKS"
            fi
        fi
    else
        echo ""
        echo "⚠️  Validator not yet registered"
        echo "Run /scripts/create-validator.sh to create your validator"
    fi
    
    # Check balance
    echo ""
    echo "💰 Account Balance:"
    echo "-------------------"
    BALANCES=$($DAEMON_NAME query bank balances "$VALIDATOR_ADDRESS" --node http://localhost:${RPC_PORT} --output json 2>/dev/null)
    BALANCE=$(echo "$BALANCES" | jq -r ".balances[] | select(.denom==\"$DENOM\") | .amount")
    
    if [ ! -z "$BALANCE" ] && [ "$BALANCE" != "null" ]; then
        DIVISOR=$(printf "1%0${DECIMALS}d" 0)
        BALANCE_DISPLAY=$(echo "scale=$DECIMALS; $BALANCE / $DIVISOR" | bc)
        echo "Balance: $BALANCE_DISPLAY $DENOM_DISPLAY"
    else
        echo "Balance: 0 $DENOM_DISPLAY"
    fi
else
    echo "⚠️  No validator key found"
fi

echo ""
echo "============================"

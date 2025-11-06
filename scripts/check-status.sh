#!/bin/bash

DAEMON_HOME=${DAEMON_HOME:-/root/.gaia}
CHAIN_ID=${CHAIN_ID:-cosmoshub-4}

echo "Cosmos Hub Validator Status"
echo "============================"
echo ""

# Check if node is running
if ! curl -s http://localhost:26657/status > /dev/null 2>&1; then
    echo "❌ Error: Node is not running or not responding"
    exit 1
fi

# Sync status
echo "📊 Sync Status:"
echo "---------------"
SYNC_INFO=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info')
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
NET_INFO=$(curl -s http://localhost:26657/net_info | jq -r '.result')
N_PEERS=$(echo "$NET_INFO" | jq -r '.n_peers')
echo "Connected Peers: $N_PEERS"
echo ""

# Validator info
echo "🔑 Validator Info:"
echo "------------------"
VALIDATOR_ADDRESS=$(gaiad keys show validator -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null)
if [ ! -z "$VALIDATOR_ADDRESS" ]; then
    echo "Validator Address: $VALIDATOR_ADDRESS"
    
    # Get operator address (valoper)
    VALOPER_ADDRESS=$(gaiad keys show validator --bech val -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null)
    echo "Operator Address: $VALOPER_ADDRESS"
    
    # Check if validator exists
    VALIDATOR_INFO=$(gaiad query staking validator "$VALOPER_ADDRESS" --node http://localhost:26657 --output json 2>/dev/null || echo "{}")
    
    if [ "$VALIDATOR_INFO" != "{}" ] && [ ! -z "$VALIDATOR_INFO" ]; then
        echo ""
        echo "✓ Validator is registered!"
        
        STATUS=$(echo "$VALIDATOR_INFO" | jq -r '.status')
        TOKENS=$(echo "$VALIDATOR_INFO" | jq -r '.tokens')
        DELEGATOR_SHARES=$(echo "$VALIDATOR_INFO" | jq -r '.delegator_shares')
        JAILED=$(echo "$VALIDATOR_INFO" | jq -r '.jailed')
        
        # Convert tokens to ATOM
        TOKENS_ATOM=$(echo "scale=6; $TOKENS / 1000000" | bc)
        
        echo "Status: $STATUS"
        echo "Jailed: $JAILED"
        echo "Total Delegated: $TOKENS_ATOM ATOM"
        echo "Delegator Shares: $DELEGATOR_SHARES"
        
        # Check signing info
        CONSENSUS_PUBKEY=$(echo "$VALIDATOR_INFO" | jq -r '.consensus_pubkey.key')
        SIGNING_INFO=$(gaiad query slashing signing-info "$CONSENSUS_PUBKEY" --node http://localhost:26657 --output json 2>/dev/null || echo "{}")
        
        if [ "$SIGNING_INFO" != "{}" ]; then
            MISSED_BLOCKS=$(echo "$SIGNING_INFO" | jq -r '.val_signing_info.missed_blocks_counter')
            echo "Missed Blocks: $MISSED_BLOCKS"
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
    BALANCES=$(gaiad query bank balances "$VALIDATOR_ADDRESS" --node http://localhost:26657 --output json 2>/dev/null)
    ATOM_BALANCE=$(echo "$BALANCES" | jq -r '.balances[] | select(.denom=="uatom") | .amount')
    
    if [ ! -z "$ATOM_BALANCE" ] && [ "$ATOM_BALANCE" != "null" ]; then
        ATOM_BALANCE_DISPLAY=$(echo "scale=6; $ATOM_BALANCE / 1000000" | bc)
        echo "Balance: $ATOM_BALANCE_DISPLAY ATOM"
    else
        echo "Balance: 0 ATOM"
    fi
else
    echo "⚠️  No validator key found"
fi

echo ""
echo "============================"


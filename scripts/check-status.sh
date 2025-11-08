#!/bin/bash

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
CHAIN_ID=${CHAIN_ID}
RPC_PORT=${RPC_PORT}
DENOM=${DENOM}
DECIMALS=${DECIMALS:-6}

# Validate required environment variables
if [ -z "$DAEMON_HOME" ] || [ -z "$DAEMON_NAME" ] || [ -z "$RPC_PORT" ]; then
    echo "Error: Required environment variables not set: DAEMON_HOME, DAEMON_NAME, or RPC_PORT" >&2
    exit 1
fi

# Check if node is running
if ! curl -s http://localhost:${RPC_PORT}/status > /dev/null 2>&1; then
    echo "Error: Node is not running or not responding on port ${RPC_PORT}" >&2
    exit 1
fi

# Get sync status
SYNC_INFO=$(curl -s http://localhost:${RPC_PORT}/status | jq -r '.result.sync_info')
CATCHING_UP=$(echo "$SYNC_INFO" | jq -r '.catching_up')
LATEST_BLOCK_HEIGHT=$(echo "$SYNC_INFO" | jq -r '.latest_block_height')
LATEST_BLOCK_TIME=$(echo "$SYNC_INFO" | jq -r '.latest_block_time')

# Get network info
NET_INFO=$(curl -s http://localhost:${RPC_PORT}/net_info | jq -r '.result')
N_PEERS=$(echo "$NET_INFO" | jq -r '.n_peers')

# Get validator info
VALIDATOR_ADDRESS=""
VALOPER_ADDRESS=""
VALIDATOR_INFO_JSON="{}"
if $DAEMON_NAME keys show validator -a --keyring-backend test --home "$DAEMON_HOME" >/dev/null 2>&1; then
    VALIDATOR_ADDRESS=$($DAEMON_NAME keys show validator -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null)
    VALOPER_ADDRESS=$($DAEMON_NAME keys show validator --bech val -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null)
    
    if [ -n "$VALOPER_ADDRESS" ]; then
        VALIDATOR_INFO_JSON=$($DAEMON_NAME query staking validator "$VALOPER_ADDRESS" --node http://localhost:${RPC_PORT} --output json 2>/dev/null || echo "{}")
    fi
fi

# Get balance
BALANCE="0"
if [ -n "$VALIDATOR_ADDRESS" ]; then
    BALANCES=$($DAEMON_NAME query bank balances "$VALIDATOR_ADDRESS" --node http://localhost:${RPC_PORT} --output json 2>/dev/null || echo "{\"balances\":[]}")
    BALANCE=$(echo "$BALANCES" | jq -r ".balances[] | select(.denom==\"$DENOM\") | .amount // \"0\"" || echo "0")
fi

# Output as JSON for CLI parsing
jq -n \
    --arg chain_id "$CHAIN_ID" \
    --argjson catching_up "$([ "$CATCHING_UP" = "true" ] && echo true || echo false)" \
    --arg latest_block_height "$LATEST_BLOCK_HEIGHT" \
    --arg latest_block_time "$LATEST_BLOCK_TIME" \
    --argjson n_peers "$N_PEERS" \
    --arg validator_address "$VALIDATOR_ADDRESS" \
    --arg valoper_address "$VALOPER_ADDRESS" \
    --argjson validator_info "$VALIDATOR_INFO_JSON" \
    --arg balance "$BALANCE" \
    --argjson decimals "$DECIMALS" \
    '{
        chain_id: $chain_id,
        sync: {
            catching_up: $catching_up,
            latest_block_height: $latest_block_height,
            latest_block_time: $latest_block_time
        },
        network: {
            peers: $n_peers
        },
        validator: {
            address: $validator_address,
            operator_address: $valoper_address,
            info: $validator_info
        },
        balance: {
            amount: $balance,
            decimals: $decimals
        }
    }'

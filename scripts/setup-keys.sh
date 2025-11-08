#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
CHAIN_NAME=${CHAIN_NAME}

# Validate required environment variables
if [ -z "$DAEMON_HOME" ] || [ -z "$DAEMON_NAME" ]; then
    echo "Error: Required environment variables not set: DAEMON_HOME or DAEMON_NAME" >&2
    exit 1
fi

# Determine private key secret file name based on chain
PRIVATE_KEY_FILE=""

# Method 1: Use CHAIN_NAME environment variable if set
if [ -n "$CHAIN_NAME" ] && [ -f "/run/secrets/${CHAIN_NAME}_private_key" ]; then
    PRIVATE_KEY_FILE="/run/secrets/${CHAIN_NAME}_private_key"
fi

# Method 2: Extract from DAEMON_HOME if still not found
if [ -z "$PRIVATE_KEY_FILE" ]; then
    EXTRACTED_CHAIN=$(echo "$DAEMON_HOME" | sed 's/.*\.\(.*\)/\1/')
    if [ -f "/run/secrets/${EXTRACTED_CHAIN}_private_key" ]; then
        PRIVATE_KEY_FILE="/run/secrets/${EXTRACTED_CHAIN}_private_key"
    fi
fi

# Method 3: Try to find any _private_key file in /run/secrets
if [ -z "$PRIVATE_KEY_FILE" ]; then
    FOUND_FILE=$(ls /run/secrets/*_private_key 2>/dev/null | head -1)
    if [ -n "$FOUND_FILE" ]; then
        PRIVATE_KEY_FILE="$FOUND_FILE"
    fi
fi

# Final fallback to generic validator_private_key
if [ -z "$PRIVATE_KEY_FILE" ] || [ ! -f "$PRIVATE_KEY_FILE" ]; then
    PRIVATE_KEY_FILE="/run/secrets/validator_private_key"
fi

# Ensure config directory exists
mkdir -p "$DAEMON_HOME/config"

# Read account_address from secret file if it exists
ACCOUNT_ADDRESS=""
if [ -f "$PRIVATE_KEY_FILE" ] && [ -s "$PRIVATE_KEY_FILE" ]; then
    if command -v jq >/dev/null 2>&1; then
        ACCOUNT_ADDRESS=$(jq -r '.account_address // empty' "$PRIVATE_KEY_FILE" 2>/dev/null || echo "")
    else
        ACCOUNT_ADDRESS=$(grep -o '"account_address"[[:space:]]*:[[:space:]]*"[^"]*"' "$PRIVATE_KEY_FILE" 2>/dev/null | sed 's/.*"account_address"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
    fi
fi

# Check if private key exists and needs to be copied
if [ -f "$PRIVATE_KEY_FILE" ] && [ -s "$PRIVATE_KEY_FILE" ]; then
    if [ ! -f "$DAEMON_HOME/config/priv_validator_key.json" ]; then
        cp "$PRIVATE_KEY_FILE" "$DAEMON_HOME/config/priv_validator_key.json"
        echo "INFO: Private key copied to $DAEMON_HOME/config/priv_validator_key.json"
    fi
else
    # Generate new key (this will also create priv_validator_key.json during init)
    $DAEMON_NAME keys add validator --keyring-backend test --home "$DAEMON_HOME" >/dev/null 2>&1 || true
fi

# Output validator address for CLI to parse (JSON format for easy parsing)
VALIDATOR_ADDRESS=""
if [ -n "$ACCOUNT_ADDRESS" ]; then
    VALIDATOR_ADDRESS="$ACCOUNT_ADDRESS"
elif $DAEMON_NAME keys show validator -a --keyring-backend test --home "$DAEMON_HOME" >/dev/null 2>&1; then
    VALIDATOR_ADDRESS=$($DAEMON_NAME keys show validator -a --keyring-backend test --home "$DAEMON_HOME" 2>/dev/null || echo "")
fi

# Output in JSON format for CLI parsing
if [ -n "$VALIDATOR_ADDRESS" ]; then
    echo "{\"validator_address\": \"$VALIDATOR_ADDRESS\", \"account_address\": \"$ACCOUNT_ADDRESS\"}"
else
    echo "{\"validator_address\": null, \"account_address\": null}"
fi

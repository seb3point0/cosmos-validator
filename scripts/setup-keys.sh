#!/bin/bash
set -e

DAEMON_HOME=${DAEMON_HOME}
DAEMON_NAME=${DAEMON_NAME}
CHAIN_NETWORK=${CHAIN_NETWORK}
DENOM_DISPLAY=${DENOM_DISPLAY}

# Validate required environment variables
if [ -z "$DAEMON_HOME" ] || [ -z "$DAEMON_NAME" ]; then
    echo "Error: Required environment variables not set!"
    echo "Missing: DAEMON_HOME or DAEMON_NAME"
    exit 1
fi

# Determine mnemonic secret file name based on chain
CHAIN_NAME=$(echo "$DAEMON_HOME" | sed 's/.*\.\(.*\)/\1/')
MNEMONIC_FILE="/run/secrets/${CHAIN_NAME}_mnemonic"

# Fallback to generic validator_mnemonic if chain-specific not found
if [ ! -f "$MNEMONIC_FILE" ]; then
    MNEMONIC_FILE="/run/secrets/validator_mnemonic"
fi

echo "Setting up validator keys for ${CHAIN_NETWORK}..."
echo "Daemon: $DAEMON_NAME"
echo "Home: $DAEMON_HOME"

# Check if mnemonic exists
if [ -f "$MNEMONIC_FILE" ] && [ -s "$MNEMONIC_FILE" ]; then
    echo "Found existing mnemonic. Importing keys..."
    
    # Import validator key from mnemonic
    echo "Importing validator key..."
    cat "$MNEMONIC_FILE" | $DAEMON_NAME keys add validator --recover --keyring-backend test --home "$DAEMON_HOME"
    
else
    echo "No mnemonic found. Generating new keys..."
    echo "⚠️  WARNING: SAVE THE MNEMONIC PHRASE THAT WILL BE DISPLAYED!"
    echo "⚠️  Store it securely - this is the ONLY way to recover your validator!"
    echo ""
    
    # Generate new key
    $DAEMON_NAME keys add validator --keyring-backend test --home "$DAEMON_HOME" 2>&1 | tee /tmp/validator_key_output.txt
    
    # Extract mnemonic from output (last line is the mnemonic)
    MNEMONIC=$(grep -A 1 "Important" /tmp/validator_key_output.txt | tail -1)
    
    echo ""
    echo "==========================================="
    echo "⚠️  CRITICAL: SAVE THIS MNEMONIC PHRASE ⚠️"
    echo "==========================================="
    echo "$MNEMONIC"
    echo "==========================================="
    echo ""
    echo "Save this to ./secrets/validator_mnemonic.txt on your host!"
    
    # Clean up temporary file
    rm -f /tmp/validator_key_output.txt
fi

# Display validator address
echo ""
echo "Validator Key Information:"
echo "=========================="
VALIDATOR_ADDRESS=$($DAEMON_NAME keys show validator -a --keyring-backend test --home "$DAEMON_HOME")
echo "Validator Address: $VALIDATOR_ADDRESS"
echo ""
echo "⚠️  IMPORTANT NEXT STEPS:"
echo "1. Send at least 2 $DENOM_DISPLAY to: $VALIDATOR_ADDRESS"
echo "   (1 $DENOM_DISPLAY for self-delegation + extra for transaction fees)"
echo "2. Wait for the node to fully sync"
echo "3. Run the create-validator transaction"
echo ""

# Backup the priv_validator_key.json
if [ -f "$DAEMON_HOME/config/priv_validator_key.json" ]; then
    echo "Backing up priv_validator_key.json..."
    cp "$DAEMON_HOME/config/priv_validator_key.json" "$DAEMON_HOME/priv_validator_key_backup.json"
    echo "✓ Backup saved to priv_validator_key_backup.json"
    echo "⚠️  Copy this file to your host machine for safekeeping!"
fi

echo ""
echo "Key setup complete!"


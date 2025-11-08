"""Validator creation commands"""

import sys
import json

from ..output import success, error, info, warning
from ..utils.docker import exec_in_container, is_container_running
from ..utils.chain_config import get_container_name, get_daemon_home, get_binary_name, get_rpc_port
from ..utils.errors import ChainNotFoundError, ContainerNotRunningError
from ..utils.validation import validate_chain_name
from ..config import get_chain_config


def create(chain_name: str):
    """Create validator for a chain"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        config = get_chain_config(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        daemon_name = get_binary_name(chain_name)
        daemon_home = get_daemon_home(chain_name)
        rpc_port = get_rpc_port(chain_name)
        denom = config.get('denom', '')
        denom_display = config.get('denom_display', '')
        decimals = config.get('decimals', 6)
        min_self_delegation = int(config.get('min_self_delegation', '1000000'))
        
        info(f"Preparing validator creation for {chain_name}...")
        
        # Check sync status
        status_result = exec_in_container(container_name, ['/scripts/check-status.sh'], interactive=False)
        if status_result.returncode != 0:
            error("Failed to check node status")
            sys.exit(1)
        
        status_data = json.loads(status_result.stdout)
        sync = status_data.get('sync', {})
        
        if sync.get('catching_up'):
            error("Node is still catching up. Please wait for the node to fully sync before creating the validator.")
            info(f"Current block height: {sync.get('latest_block_height', 'N/A')}")
            sys.exit(1)
        
        info(f"✓ Node is fully synced at block height: {sync.get('latest_block_height', 'N/A')}")
        
        # Check validator key exists
        validator = status_data.get('validator', {})
        validator_addr = validator.get('address', '')
        if not validator_addr:
            error("No validator key found. Run 'validay keys setup' first.")
            sys.exit(1)
        
        info(f"✓ Validator key found: {validator_addr}")
        
        # Check if validator already exists
        validator_info = validator.get('info', {})
        if validator_info and validator_info != {}:
            warning("Validator is already registered!")
            info(f"Operator Address: {validator.get('operator_address', 'N/A')}")
            return
        
        # Check balance
        balance_data = status_data.get('balance', {})
        balance_amount = balance_data.get('amount', '0')
        balance_int = int(balance_amount) if balance_amount else 0
        
        if balance_int == 0:
            error("No balance found!")
            info(f"Please send at least 2 {denom_display} to: {validator_addr}")
            sys.exit(1)
        
        divisor = 10 ** decimals
        balance_display = balance_int / divisor
        required_balance = min_self_delegation + divisor  # self-delegation + buffer
        
        if balance_int < required_balance:
            required_display = required_balance / divisor
            error("Insufficient balance!")
            info(f"Required: {required_display} {denom_display} (for self-delegation and fees)")
            info(f"Current: {balance_display} {denom_display}")
            sys.exit(1)
        
        info(f"✓ Sufficient balance: {balance_display} {denom_display}")
        
        # Display validator configuration
        validator_name = config.get('validator', {}).get('name', config.get('moniker', f'{chain_name}-validator'))
        validator_website = config.get('validator', {}).get('website', '')
        validator_identity = config.get('validator', {}).get('identity', '')
        validator_details = config.get('validator', {}).get('details', 'A reliable validator')
        validator_security = config.get('validator', {}).get('security_contact', '')
        commission_rate = config.get('validator', {}).get('commission_rate', 0.10)
        commission_max_rate = config.get('validator', {}).get('commission_max_rate', 0.20)
        commission_max_change_rate = config.get('validator', {}).get('commission_max_change_rate', 0.01)
        
        print("")
        info("Validator Configuration:")
        print("=" * 60)
        print(f"Moniker: {validator_name}")
        print(f"Website: {validator_website or '(not set)'}")
        print(f"Identity: {validator_identity or '(not set)'}")
        print(f"Details: {validator_details}")
        print(f"Security Contact: {validator_security or '(not set)'}")
        print(f"Commission Rate: {commission_rate}")
        print(f"Commission Max Rate: {commission_max_rate}")
        print(f"Commission Max Change Rate: {commission_max_change_rate}")
        self_delegation_display = min_self_delegation / divisor
        print(f"Self Delegation: {self_delegation_display} {denom_display}")
        print("=" * 60)
        print("")
        
        warning("Review the configuration above carefully!")
        response = input("Do you want to proceed with validator creation? (yes/no): ")
        if response.lower() != 'yes':
            info("Validator creation cancelled.")
            return
        
        # Execute validator creation
        info("Submitting validator creation transaction...")
        result = exec_in_container(container_name, ['/scripts/start-validator.sh'], interactive=False)
        
        if result.returncode == 0:
            success("Validator creation transaction submitted!")
            print("")
            info("Next steps:")
            print("  1. Wait a few blocks for the transaction to be confirmed (1-2 minutes)")
            print("  2. Check your validator status: validay chain status " + chain_name)
            valoper_addr = validator.get('operator_address', '')
            if valoper_addr:
                block_explorer = config.get('block_explorer_url', '')
                if block_explorer:
                    explorer_url = block_explorer.replace('{address}', valoper_addr)
                    print(f"  3. View on block explorer: {explorer_url}")
        else:
            error(f"Failed to create validator: {result.stderr}")
            sys.exit(1)
            
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)
    except json.JSONDecodeError:
        error("Failed to parse status output")
        sys.exit(1)


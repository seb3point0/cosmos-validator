"""Chain management commands"""

import sys
import json
import yaml
from typing import Optional

from ..output import success, error, info, warning
from ..progress import Spinner, show_progress
from ..config import load_chains_config, get_chain_config, clear_cache
from ..utils.docker import (
    start_container, stop_container, restart_container, get_container_logs,
    exec_in_container, rebuild_container, remove_container, is_container_running,
    get_container_status
)
from ..utils.chain_config import get_container_name, get_daemon_home, get_binary_name, get_rpc_port
from ..utils.errors import ChainNotFoundError, ContainerNotRunningError, DockerError
from ..utils.validation import validate_chain_name


def start(chain_name: str):
    """Start a chain"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        def _start():
            start_container(container_name)
        
        show_progress(f"Starting {chain_name} validator...", _start)
        success(f"Chain '{chain_name}' started successfully")
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)


def stop(chain_name: str):
    """Stop a chain"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            warning(f"Container '{container_name}' is not running")
            return
        
        def _stop():
            stop_container(container_name)
        
        show_progress(f"Stopping {chain_name} validator...", _stop)
        success(f"Chain '{chain_name}' stopped successfully")
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)


def restart(chain_name: str):
    """Restart a chain"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        def _restart():
            restart_container(container_name)
        
        show_progress(f"Restarting {chain_name} validator...", _restart)
        success(f"Chain '{chain_name}' restarted successfully")
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)


def logs(chain_name: str, follow: bool = True):
    """View chain logs"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if follow:
            info(f"Viewing logs for {chain_name} validator (Ctrl+C to exit)...")
        get_container_logs(container_name, follow=follow)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)
    except KeyboardInterrupt:
        info("Log viewing stopped")


def status(chain_name: str):
    """Check chain status"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        result = exec_in_container(container_name, ['/scripts/check-status.sh'], interactive=False)
        if result.returncode != 0:
            error(f"Failed to get status: {result.stderr}")
            sys.exit(1)
        
        # Parse JSON output from script
        import json
        try:
            status_data = json.loads(result.stdout)
        except json.JSONDecodeError:
            error("Failed to parse status output")
            sys.exit(1)
        
        # Format and display status
        config = get_chain_config(chain_name)
        denom_display = config.get('denom_display', '')
        decimals = config.get('decimals', 6)
        
        info(f"{chain_name.title()} Validator Status")
        print("=" * 60)
        print(f"Chain ID: {status_data.get('chain_id', 'N/A')}")
        print("")
        
        # Sync status
        sync = status_data.get('sync', {})
        if sync.get('catching_up'):
            print("📊 Sync Status: ⏳ Catching up...")
        else:
            print("📊 Sync Status: ✓ Fully synced")
        print(f"Latest Block Height: {sync.get('latest_block_height', 'N/A')}")
        print(f"Latest Block Time: {sync.get('latest_block_time', 'N/A')}")
        print("")
        
        # Network info
        network = status_data.get('network', {})
        print(f"🌐 Connected Peers: {network.get('peers', 0)}")
        print("")
        
        # Validator info
        validator = status_data.get('validator', {})
        validator_addr = validator.get('address', '')
        valoper_addr = validator.get('operator_address', '')
        validator_info = validator.get('info', {})
        
        if validator_addr:
            print("🔑 Validator Info:")
            print("------------------")
            print(f"Validator Address: {validator_addr}")
            if valoper_addr:
                print(f"Operator Address: {valoper_addr}")
            
            if validator_info and validator_info != {}:
                print("")
                print("✓ Validator is registered!")
                status_val = validator_info.get('status', 'N/A')
                tokens = validator_info.get('tokens', '0')
                jailed = validator_info.get('jailed', False)
                
                # Convert tokens to display denom
                if tokens and tokens != '0':
                    divisor = 10 ** decimals
                    tokens_display = float(tokens) / divisor
                    print(f"Status: {status_val}")
                    print(f"Jailed: {jailed}")
                    print(f"Total Delegated: {tokens_display} {denom_display}")
                else:
                    print(f"Status: {status_val}")
                    print(f"Jailed: {jailed}")
            else:
                print("")
                print("⚠️  Validator not yet registered")
        else:
            print("⚠️  No validator key found")
        
        # Balance
        balance_data = status_data.get('balance', {})
        balance_amount = balance_data.get('amount', '0')
        if balance_amount and balance_amount != '0':
            divisor = 10 ** decimals
            balance_display = float(balance_amount) / divisor
            print("")
            print("💰 Account Balance:")
            print("-------------------")
            print(f"Balance: {balance_display} {denom_display}")
        
        print("")
        print("=" * 60)
        
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)


def shell(chain_name: str):
    """Enter chain container shell"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        info(f"Entering {chain_name} validator shell...")
        result = exec_in_container(container_name, ['/bin/bash'], interactive=True)
        sys.exit(result.returncode if result.returncode else 0)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)


def init(chain_name: str):
    """Initialize chain"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running. Start it first.")
            sys.exit(1)
        
        info(f"Initializing {chain_name}...")
        result = exec_in_container(container_name, ['/scripts/init-node.sh'], interactive=False)
        if result.returncode == 0:
            success(f"Chain '{chain_name}' initialized successfully")
            print(result.stdout)
        else:
            error(f"Initialization failed: {result.stderr}")
            sys.exit(1)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)


def rebuild(chain_name: str):
    """Rebuild chain container"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        def _rebuild():
            rebuild_container(container_name)
        
        show_progress(f"Rebuilding {chain_name} container...", _rebuild)
        success(f"Chain '{chain_name}' container rebuilt successfully")
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)


def clean(chain_name: str, confirm: bool = False):
    """Remove chain container and volume"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not confirm:
            warning(f"This will remove {chain_name} container and volume!")
            response = input("Are you sure? [y/N]: ")
            if response.lower() != 'y':
                info("Cancelled")
                return
        
        def _clean():
            remove_container(container_name, volumes=True)
        
        show_progress(f"Removing {chain_name} container and volume...", _clean)
        success(f"Chain '{chain_name}' removed successfully")
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)
    except KeyboardInterrupt:
        info("Cancelled")


def enable(chain_name: str):
    """Enable chain in chains.yaml"""
    try:
        validate_chain_name(chain_name)
        
        from ..config import get_project_root
        root = get_project_root()
        config_file = root / "chains.yaml"
        
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)
        
        if chain_name not in config.get('chains', {}):
            error(f"Chain '{chain_name}' not found in chains.yaml")
            sys.exit(1)
        
        config['chains'][chain_name]['enabled'] = True
        
        with open(config_file, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False)
        
        clear_cache()
        success(f"Chain '{chain_name}' enabled. Run 'validay generate' to update configuration")
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except Exception as e:
        error(f"Failed to enable chain: {e}")
        sys.exit(1)


def disable(chain_name: str):
    """Disable chain in chains.yaml"""
    try:
        validate_chain_name(chain_name)
        
        from ..config import get_project_root
        root = get_project_root()
        config_file = root / "chains.yaml"
        
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)
        
        if chain_name not in config.get('chains', {}):
            error(f"Chain '{chain_name}' not found in chains.yaml")
            sys.exit(1)
        
        config['chains'][chain_name]['enabled'] = False
        
        with open(config_file, 'w') as f:
            yaml.dump(config, f, default_flow_style=False, sort_keys=False)
        
        clear_cache()
        success(f"Chain '{chain_name}' disabled. Run 'validay generate' to update configuration")
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except Exception as e:
        error(f"Failed to disable chain: {e}")
        sys.exit(1)


def create_validator(chain_name: str):
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


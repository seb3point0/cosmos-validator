"""Query commands"""

import sys

from ..output import error
from ..utils.docker import exec_in_container, is_container_running
from ..utils.chain_config import get_container_name, get_daemon_home, get_binary_name, get_rpc_port
from ..utils.errors import ChainNotFoundError, ContainerNotRunningError
from ..utils.validation import validate_chain_name
from ..config import get_chain_config


def balance(chain_name: str):
    """Query account balance"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        config = get_chain_config(chain_name)
        daemon_name = get_binary_name(chain_name)
        daemon_home = get_daemon_home(chain_name)
        rpc_port = get_rpc_port(chain_name)
        
        result = exec_in_container(
            container_name,
            ['bash', '-c', f'''
                ADDR=$({daemon_name} keys show validator -a --keyring-backend test --home {daemon_home} 2>/dev/null)
                if [ -z "$ADDR" ]; then
                    echo "No validator key found"
                    exit 1
                fi
                {daemon_name} query bank balances $ADDR --node http://localhost:{rpc_port}
            '''],
            interactive=False
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            error(result.stderr or "Failed to query balance")
            sys.exit(1)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)


def validator_info(chain_name: str):
    """Query validator info"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        config = get_chain_config(chain_name)
        daemon_name = get_binary_name(chain_name)
        daemon_home = get_daemon_home(chain_name)
        rpc_port = get_rpc_port(chain_name)
        
        result = exec_in_container(
            container_name,
            ['bash', '-c', f'''
                VALOPER=$({daemon_name} keys show validator --bech val -a --keyring-backend test --home {daemon_home} 2>/dev/null)
                if [ -z "$VALOPER" ]; then
                    echo "No validator key found"
                    exit 1
                fi
                {daemon_name} query staking validator $VALOPER --node http://localhost:{rpc_port}
            '''],
            interactive=False
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            error(result.stderr or "Failed to query validator info")
            sys.exit(1)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)


def delegations(chain_name: str):
    """Query delegations"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        config = get_chain_config(chain_name)
        daemon_name = get_binary_name(chain_name)
        daemon_home = get_daemon_home(chain_name)
        rpc_port = get_rpc_port(chain_name)
        
        result = exec_in_container(
            container_name,
            ['bash', '-c', f'''
                VALOPER=$({daemon_name} keys show validator --bech val -a --keyring-backend test --home {daemon_home} 2>/dev/null)
                if [ -z "$VALOPER" ]; then
                    echo "No validator key found"
                    exit 1
                fi
                {daemon_name} query staking delegations-to $VALOPER --node http://localhost:{rpc_port}
            '''],
            interactive=False
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            error(result.stderr or "Failed to query delegations")
            sys.exit(1)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)


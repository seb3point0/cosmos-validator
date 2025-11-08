"""Upgrade management commands"""

import sys
import subprocess
import json

from ..output import success, error, info
from ..utils.docker import exec_in_container, is_container_running
from ..utils.chain_config import get_container_name
from ..utils.errors import ChainNotFoundError, ContainerNotRunningError
from ..utils.validation import validate_chain_name


def list_upgrades():
    """List pending upgrades from Polkachu API"""
    info("Fetching pending upgrades from Polkachu API...")
    
    try:
        result = subprocess.run(
            ['curl', '-s', 'https://polkachu.com/api/v2/chain_upgrades'],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            try:
                upgrades = json.loads(result.stdout)
                if upgrades:
                    for upgrade in upgrades:
                        network = upgrade.get('network', 'N/A')
                        version = upgrade.get('node_version', 'N/A')
                        block = upgrade.get('block', 'N/A')
                        time = upgrade.get('estimated_upgrade_time', 'N/A')
                        print(f"{network} - {version} at block {block} (~{time})")
                else:
                    info("No pending upgrades found")
            except json.JSONDecodeError:
                error("Failed to parse API response")
        else:
            error("Failed to fetch upgrade information")
    except Exception as e:
        error(f"Failed to list upgrades: {e}")
        sys.exit(1)


def check(chain_name: str):
    """Check upgrade status for a chain"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        info(f"Checking upgrade status for {chain_name}...")
        
        result = exec_in_container(
            container_name,
            ['bash', '-c', 'ls -la /root/.*/cosmovisor/upgrades/ 2>/dev/null || echo "No upgrades prepared yet"'],
            interactive=False
        )
        
        print(result.stdout)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)


def prepare(chain_name: str, upgrade_name: str, binary_url: str, height: str = None):
    """Prepare upgrade for a chain"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        if not upgrade_name or not binary_url:
            error("Upgrade name and binary URL are required")
            error("Usage: validator upgrade prepare <chain> --name <name> --url <url> [--height <height>]")
            sys.exit(1)
        
        info(f"Preparing upgrade {upgrade_name} for {chain_name}...")
        
        cmd = ['/scripts/prepare-upgrade.sh', upgrade_name, binary_url]
        if height:
            cmd.append(height)
        
        result = exec_in_container(container_name, cmd, interactive=False)
        
        if result.returncode == 0:
            success(f"Upgrade {upgrade_name} prepared successfully")
            print(result.stdout)
        else:
            error(f"Failed to prepare upgrade: {result.stderr}")
            sys.exit(1)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)


#!/usr/bin/env python3
"""
Cosmos Chain Upgrade Monitor
Monitors Polkachu's upgrade API and prepares binaries for pending upgrades
"""

import os
import sys
import time
import json
import logging
import requests
import yaml
import subprocess
from datetime import datetime, timezone
from typing import Dict, List, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('upgrade-monitor')

# Configuration from environment
CHAINS_CONFIG = os.getenv('CHAINS_CONFIG', '/config/chains.yaml')
POLKACHU_API_URL = os.getenv('POLKACHU_API_URL', 'https://polkachu.com/api/v2/chain_upgrades')
CHECK_INTERVAL = int(os.getenv('CHECK_INTERVAL', '300'))  # 5 minutes
SLACK_WEBHOOK_URL = os.getenv('SLACK_WEBHOOK_URL', '')
PREPARATION_HOURS = int(os.getenv('PREPARATION_HOURS', '48'))
API_TIMEOUT = int(os.getenv('API_TIMEOUT', '30'))
DOCKER_EXEC_TIMEOUT = int(os.getenv('DOCKER_EXEC_TIMEOUT', '300'))

# State file to track processed upgrades
STATE_FILE = '/tmp/upgrade-monitor-state.json'


def load_chains_config() -> Dict:
    """Load chains configuration"""
    try:
        with open(CHAINS_CONFIG, 'r') as f:
            config = yaml.safe_load(f)
            return config.get('chains', {})
    except Exception as e:
        logger.error(f"Failed to load chains config: {e}")
        return {}


def load_state() -> Dict:
    """Load monitor state"""
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"Failed to load state: {e}")
    return {'processed_upgrades': {}}


def save_state(state: Dict):
    """Save monitor state"""
    try:
        with open(STATE_FILE, 'w') as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        logger.error(f"Failed to save state: {e}")


def fetch_polkachu_upgrades() -> List[Dict]:
    """Fetch upgrade information from Polkachu API"""
    try:
        logger.info(f"Fetching upgrades from {POLKACHU_API_URL}")
        response = requests.get(POLKACHU_API_URL, timeout=API_TIMEOUT)
        response.raise_for_status()
        upgrades = response.json()
        logger.info(f"Found {len(upgrades)} pending upgrades")
        return upgrades
    except Exception as e:
        logger.error(f"Failed to fetch upgrades: {e}")
        return []


def send_slack_notification(message: str):
    """Send notification to Slack"""
    if not SLACK_WEBHOOK_URL:
        return
    
    try:
        payload = {'text': message}
        response = requests.post(SLACK_WEBHOOK_URL, json=payload, timeout=10)
        response.raise_for_status()
        logger.info("Slack notification sent")
    except Exception as e:
        logger.error(f"Failed to send Slack notification: {e}")


def get_chain_binary_url(chain_config: Dict, version: str) -> Optional[str]:
    """Construct binary URL from chain config and version"""
    repo = chain_config.get('repo', '')
    binary_name = chain_config.get('binary_name', '')
    
    if not repo or not version:
        return None
    
    # Get URL template from chain config, or use default GitHub pattern
    binary_config = chain_config.get('binary', {})
    url_template = binary_config.get('url_template', '{repo}/releases/download/{version}/{binary_name}-{version}-linux-amd64')
    
    # Replace template variables
    binary_url = url_template.format(
        repo=repo,
        version=version,
        binary_name=binary_name
    )
    
    return binary_url


def get_current_block_height(chain_name: str, rpc_port: int) -> Optional[int]:
    """Get current block height for a chain"""
    try:
        response = requests.get(f"http://{chain_name}-validator:{rpc_port}/status", timeout=10)
        if response.status_code == 200:
            data = response.json()
            height = int(data['result']['sync_info']['latest_block_height'])
            return height
    except Exception as e:
        logger.debug(f"Could not get block height for {chain_name}: {e}")
    return None


def prepare_upgrade(chain_name: str, chain_config: Dict, upgrade_info: Dict):
    """Prepare upgrade binary for a chain"""
    upgrade_name = upgrade_info['cosmovisor_folder']
    upgrade_height = upgrade_info['block']
    node_version = upgrade_info['node_version']
    
    logger.info(f"Preparing upgrade for {chain_name}: {upgrade_name} at height {upgrade_height}")
    
    # Construct binary URL
    binary_url = get_chain_binary_url(chain_config, node_version)
    if not binary_url:
        logger.error(f"Could not construct binary URL for {chain_name}")
        return False
    
    # Call prepare-upgrade.sh script inside the chain's container
    container_name = f"{chain_name}-validator"
    daemon_home = chain_config.get('daemon_home', f'/root/.{chain_name}')
    
    try:
        cmd = [
            'docker', 'exec', container_name,
            '/scripts/prepare-upgrade.sh',
            upgrade_name,
            binary_url,
            str(upgrade_height),
            upgrade_info.get('git_hash', '')
        ]
        
        logger.info(f"Running: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=DOCKER_EXEC_TIMEOUT)
        
        if result.returncode == 0:
            logger.info(f"✓ Upgrade prepared successfully for {chain_name}")
            
            # Send notification
            message = f"🔄 Upgrade Prepared: {chain_name}\n" \
                     f"Upgrade: {upgrade_name}\n" \
                     f"Version: {node_version}\n" \
                     f"Height: {upgrade_height}\n" \
                     f"Time: {upgrade_info.get('estimated_upgrade_time', 'Unknown')}\n" \
                     f"Guide: {upgrade_info.get('guide', 'N/A')}"
            send_slack_notification(message)
            return True
        else:
            logger.error(f"Failed to prepare upgrade for {chain_name}")
            logger.error(f"STDERR: {result.stderr}")
            return False
            
    except Exception as e:
        logger.error(f"Exception while preparing upgrade for {chain_name}: {e}")
        return False


def check_upgrade_readiness(chain_name: str, chain_config: Dict, upgrade_info: Dict) -> str:
    """Check if upgrade is approaching and return status"""
    upgrade_height = upgrade_info['block']
    rpc_port = chain_config.get('ports', {}).get('rpc', 26657)
    block_time_seconds = chain_config.get('block_time_seconds', 6)
    
    current_height = get_current_block_height(chain_name, rpc_port)
    if not current_height:
        return 'unknown'
    
    blocks_remaining = upgrade_height - current_height
    
    # Use block time from chains.yaml
    hours_remaining = (blocks_remaining * block_time_seconds) / 3600
    
    if blocks_remaining <= 0:
        return 'passed'
    elif hours_remaining <= 1:
        return 'imminent'
    elif hours_remaining <= PREPARATION_HOURS:
        return 'prepare'
    else:
        return 'waiting'


def process_upgrades():
    """Main upgrade processing logic"""
    chains_config = load_chains_config()
    if not chains_config:
        logger.error("No chains configured")
        return
    
    # Get enabled chains
    enabled_chains = {name: cfg for name, cfg in chains_config.items() if cfg.get('enabled', False)}
    if not enabled_chains:
        logger.info("No enabled chains")
        return
    
    logger.info(f"Monitoring {len(enabled_chains)} chains: {', '.join(enabled_chains.keys())}")
    
    # Fetch upgrades from Polkachu
    polkachu_upgrades = fetch_polkachu_upgrades()
    if not polkachu_upgrades:
        return
    
    # Load state
    state = load_state()
    processed = state.get('processed_upgrades', {})
    
    # Process each enabled chain
    for chain_name, chain_config in enabled_chains.items():
        network = chain_config.get('network', chain_name)
        
        # Find matching upgrade in Polkachu data
        matching_upgrade = None
        for upgrade in polkachu_upgrades:
            if upgrade['network'] == network:
                matching_upgrade = upgrade
                break
        
        if not matching_upgrade:
            continue
        
        upgrade_id = f"{network}_{matching_upgrade['node_version']}"
        
        logger.info(f"Found pending upgrade for {chain_name}: {matching_upgrade['node_version']} at height {matching_upgrade['block']}")
        
        # Check if already processed
        if upgrade_id in processed and processed[upgrade_id].get('prepared', False):
            logger.debug(f"Upgrade {upgrade_id} already prepared")
            
            # Check if upgrade is imminent
            readiness = check_upgrade_readiness(chain_name, chain_config, matching_upgrade)
            if readiness == 'imminent' and not processed[upgrade_id].get('imminent_alert_sent', False):
                message = f"⚠️ Upgrade Imminent: {chain_name}\n" \
                         f"Upgrade: {matching_upgrade['cosmovisor_folder']}\n" \
                         f"Height: {matching_upgrade['block']}\n" \
                         f"Less than 1 hour remaining!"
                send_slack_notification(message)
                processed[upgrade_id]['imminent_alert_sent'] = True
                save_state(state)
            
            continue
        
        # Check if it's time to prepare
        readiness = check_upgrade_readiness(chain_name, chain_config, matching_upgrade)
        
        if readiness == 'prepare' or readiness == 'imminent':
            success = prepare_upgrade(chain_name, chain_config, matching_upgrade)
            
            if success:
                processed[upgrade_id] = {
                    'prepared': True,
                    'timestamp': datetime.now(timezone.utc).isoformat(),
                    'upgrade_name': matching_upgrade['cosmovisor_folder'],
                    'upgrade_height': matching_upgrade['block'],
                    'imminent_alert_sent': False
                }
                state['processed_upgrades'] = processed
                save_state(state)
        elif readiness == 'waiting':
            logger.info(f"Upgrade for {chain_name} not yet ready to prepare (waiting for {PREPARATION_HOURS}h window)")
        elif readiness == 'unknown':
            logger.warning(f"Could not determine readiness for {chain_name} upgrade")


def main():
    """Main monitor loop"""
    logger.info("=" * 60)
    logger.info("Cosmos Chain Upgrade Monitor Started")
    logger.info("=" * 60)
    logger.info(f"Chains config: {CHAINS_CONFIG}")
    logger.info(f"Polkachu API: {POLKACHU_API_URL}")
    logger.info(f"Check interval: {CHECK_INTERVAL}s")
    logger.info(f"Preparation window: {PREPARATION_HOURS}h")
    logger.info("=" * 60)
    
    while True:
        try:
            logger.info("Checking for upgrades...")
            process_upgrades()
            logger.info(f"Next check in {CHECK_INTERVAL} seconds")
        except Exception as e:
            logger.error(f"Error in main loop: {e}", exc_info=True)
        
        time.sleep(CHECK_INTERVAL)


if __name__ == '__main__':
    main()



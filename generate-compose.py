#!/usr/bin/env python3
"""
Generate docker-compose.yml from chains.yaml configuration
This script creates a multi-chain validator setup with shared monitoring
"""

import yaml
import sys
from typing import Dict, List, Any

def load_chains_config(config_file: str = 'chains.yaml') -> Dict:
    """Load the chains configuration file"""
    try:
        with open(config_file, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        print(f"Error: {config_file} not found")
        sys.exit(1)
    except yaml.YAMLError as e:
        print(f"Error parsing {config_file}: {e}")
        sys.exit(1)

def load_global_config(config_file: str = 'config.yml') -> Dict:
    """Load the global configuration file"""
    try:
        with open(config_file, 'r') as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        print(f"Warning: {config_file} not found, using defaults")
        return {}
    except yaml.YAMLError as e:
        print(f"Error parsing {config_file}: {e}")
        sys.exit(1)

def create_chain_service(chain_name: str, chain_config: Dict, global_config: Dict = None) -> Dict:
    """Create a docker-compose service definition for a chain"""
    if global_config is None:
        global_config = {}
    
    # Start with defaults from config.yml
    validator_defaults = global_config.get('validator_defaults', {})
    
    # Get validator config from chains.yaml (if present)
    chain_validator_config = chain_config.get('validator', {})
    
    # Merge: chains.yaml overrides > config.yml defaults
    # Start with defaults, then override with chain-specific values
    validator_config = {
        'moniker': chain_validator_config.get('moniker', validator_defaults.get('moniker', '')),
        'external_ip': chain_validator_config.get('external_ip', validator_defaults.get('external_ip', '')),
        'name': chain_validator_config.get('name', validator_defaults.get('name', '')),
        'website': chain_validator_config.get('website', validator_defaults.get('website', '')),
        'identity': chain_validator_config.get('identity', validator_defaults.get('identity', '')),
        'details': chain_validator_config.get('details', validator_defaults.get('details', '')),
        'security_contact': chain_validator_config.get('security_contact', validator_defaults.get('security_contact', '')),
        'commission_rate': chain_validator_config.get('commission_rate', validator_defaults.get('commission_rate', 0.10)),
        'commission_max_rate': chain_validator_config.get('commission_max_rate', validator_defaults.get('commission_max_rate', 0.20)),
        'commission_max_change_rate': chain_validator_config.get('commission_max_change_rate', validator_defaults.get('commission_max_change_rate', 0.01))
    }
    
    # If moniker is empty, use default pattern
    if not validator_config['moniker']:
        validator_config['moniker'] = f'{chain_name}-validator'
    
    binary_name = chain_config['binary_name']
    daemon_home = chain_config['daemon_home']
    ports = chain_config['ports']
    
    service = {
        'build': {
            'context': '.',
            'dockerfile': 'Dockerfile',
            'args': {
                'CHAIN_BINARY_URL': chain_config['binary_url'],
                'CHAIN_BINARY_NAME': binary_name,
                'CHAIN_VERSION': chain_config['binary_version'],
                'DAEMON_HOME': daemon_home
            }
        },
        'container_name': f'{chain_name}-validator',
        'restart': 'unless-stopped',
        'ports': [
            f"{ports['p2p']}:{ports['p2p']}",      # P2P
            f"{ports['rpc']}:{ports['rpc']}",      # RPC
            f"{ports['rest_api']}:{ports['rest_api']}",  # REST API
            f"{ports['grpc']}:{ports['grpc']}",    # gRPC
            f"{ports['prometheus']}:{ports['prometheus']}"  # Prometheus metrics
        ],
        'volumes': [
            f'{chain_name}-data:{daemon_home}',
            './scripts:/scripts:ro'
        ],
        'environment': [
            f"CHAIN_ID={chain_config['chain_id']}",
            f"CHAIN_NETWORK={chain_config.get('chain_name', chain_name.title())}",
            # Moniker: chains.yaml > config.yml defaults > pattern default
            f"MONIKER={validator_config['moniker']}",
            # External IP: chains.yaml > config.yml defaults
            f"EXTERNAL_IP={validator_config['external_ip']}",
            f"DAEMON_NAME={binary_name}",
            f"DAEMON_HOME={daemon_home}",
            "DAEMON_ALLOW_DOWNLOAD_BINARIES=true",
            "DAEMON_RESTART_AFTER_UPGRADE=true",
            "UNSAFE_SKIP_BACKUP=true",
            f"MIN_GAS_PRICES={chain_config['min_gas_price']}",
            f"DENOM={chain_config['denom']}",
            f"DENOM_DISPLAY={chain_config['denom_display']}",
            f"DECIMALS={chain_config.get('decimals', 6)}",
            f"RPC_PORT={ports['rpc']}",
            f"P2P_PORT={ports['p2p']}",
            f"BLOCK_TIME_SECONDS={chain_config.get('block_time_seconds', 6)}",
            f"BLOCK_EXPLORER_URL={chain_config.get('block_explorer_url', '')}",
            f"MIN_SELF_DELEGATION={chain_config.get('min_self_delegation', '1000000')}",
            f"GENESIS_URL={chain_config['genesis_url']}",
            f"SNAPSHOT_URL={chain_config['snapshot_url']}",
            f"SNAPSHOT_WASM_URL={chain_config['snapshot_wasm_url']}",
            f"PERSISTENT_PEERS={chain_config['persistent_peers']}",
            f"STATE_SYNC_RPC={','.join(chain_config['state_sync_rpc'])}",
            f"PRUNING={chain_config['pruning']}",
            f"PRUNING_KEEP_RECENT={chain_config['pruning_keep_recent']}",
            f"PRUNING_KEEP_EVERY={chain_config['pruning_keep_every']}",
            f"PRUNING_INTERVAL={chain_config['pruning_interval']}",
            f"CHAIN_REPO={chain_config['repo']}",
            # Validator configuration (chains.yaml > config.yml defaults)
            f"VALIDATOR_NAME={validator_config['name']}",
            f"VALIDATOR_WEBSITE={validator_config['website']}",
            f"VALIDATOR_IDENTITY={validator_config['identity']}",
            f"VALIDATOR_DETAILS={validator_config['details']}",
            f"VALIDATOR_SECURITY_CONTACT={validator_config['security_contact']}",
            f"COMMISSION_RATE={validator_config['commission_rate']}",
            f"COMMISSION_MAX_RATE={validator_config['commission_max_rate']}",
            f"COMMISSION_MAX_CHANGE_RATE={validator_config['commission_max_change_rate']}"
        ],
        'secrets': [
            f'{chain_name}_mnemonic'
        ],
        'networks': ['cosmos-network'],
        'healthcheck': {
            'test': [
                'CMD',
                'curl',
                '-f',
                f"http://localhost:{ports['rpc']}/health"
            ],
            'interval': '30s',
            'timeout': '10s',
            'retries': 3,
            'start_period': '120s'
        },
        'logging': {
            'driver': 'json-file',
            'options': {
                'max-size': '100m',
                'max-file': '3'
            }
        }
    }
    
    return service

def create_prometheus_service(enabled_chains: List[str], global_config: Dict = None) -> Dict:
    """Create Prometheus service with dynamic scrape configs"""
    if global_config is None:
        global_config = {}
    
    retention = global_config.get('monitoring', {}).get('prometheus_retention', '15d')
    
    return {
        'image': 'prom/prometheus:latest',
        'container_name': 'prometheus',
        'restart': 'unless-stopped',
        'ports': ['9091:9090'],
        'volumes': [
            './prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro',
            './prometheus/alerts.yml:/etc/prometheus/alerts.yml:ro',
            'prometheus-data:/prometheus'
        ],
        'command': [
            '--config.file=/etc/prometheus/prometheus.yml',
            '--storage.tsdb.path=/prometheus',
            f'--storage.tsdb.retention.time={retention}',
            '--web.console.libraries=/usr/share/prometheus/console_libraries',
            '--web.console.templates=/usr/share/prometheus/consoles'
        ],
        'networks': ['cosmos-network'],
        'depends_on': [f'{chain}-validator' for chain in enabled_chains]
    }

def create_upgrade_monitor_service(enabled_chains: List[str], global_config: Dict = None) -> Dict:
    """Create upgrade monitor service"""
    if global_config is None:
        global_config = {}
    
    volumes = ['./chains.yaml:/config/chains.yaml:ro']
    
    # Add volume mounts for each enabled chain's data directory
    for chain in enabled_chains:
        volumes.append(f'{chain}-data:/data/{chain}')
    
    upgrade_config = global_config.get('upgrade_monitoring', {})
    check_interval = upgrade_config.get('check_interval', 300)
    slack_webhook = global_config.get('alerting', {}).get('slack_webhook_url', '')
    
    return {
        'build': {
            'context': './upgrade-monitor',
            'dockerfile': 'Dockerfile'
        },
        'container_name': 'upgrade-monitor',
        'restart': 'unless-stopped',
        'environment': [
            'CHAINS_CONFIG=/config/chains.yaml',
            'POLKACHU_API_URL=https://polkachu.com/api/v2/chain_upgrades',
            f'CHECK_INTERVAL={check_interval}',
            f'SLACK_WEBHOOK_URL={slack_webhook}'
        ],
        'volumes': volumes,
        'networks': ['cosmos-network'],
        'depends_on': [f'{chain}-validator' for chain in enabled_chains],
        'logging': {
            'driver': 'json-file',
            'options': {
                'max-size': '50m',
                'max-file': '3'
            }
        }
    }

def create_monitoring_services(global_config: Dict = None) -> Dict:
    """Create shared monitoring services (Grafana, Alertmanager, node-exporter)"""
    if global_config is None:
        global_config = {}
    
    monitoring_config = global_config.get('monitoring', {})
    alerting_config = global_config.get('alerting', {})
    
    grafana_password = monitoring_config.get('grafana_admin_password', 'admin')
    slack_webhook = alerting_config.get('slack_webhook_url', '')
    
    return {
        'grafana': {
            'image': 'grafana/grafana:latest',
            'container_name': 'grafana',
            'restart': 'unless-stopped',
            'ports': ['3001:3000'],
            'volumes': [
                './grafana/provisioning:/etc/grafana/provisioning:ro',
                'grafana-data:/var/lib/grafana'
            ],
            'environment': [
                f'GF_SECURITY_ADMIN_PASSWORD={grafana_password}',
                'GF_USERS_ALLOW_SIGN_UP=false',
                'GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource'
            ],
            'networks': ['cosmos-network'],
            'depends_on': ['prometheus']
        },
        'alertmanager': {
            'image': 'prom/alertmanager:latest',
            'container_name': 'alertmanager',
            'restart': 'unless-stopped',
            'ports': ['9093:9093'],
            'volumes': [
                './alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro',
                'alertmanager-data:/alertmanager'
            ],
            'command': [
                '--config.file=/etc/alertmanager/alertmanager.yml',
                '--storage.path=/alertmanager'
            ],
            'environment': [
                f'SLACK_WEBHOOK_URL={slack_webhook}'
            ],
            'networks': ['cosmos-network'],
            'depends_on': ['prometheus']
        },
        'node-exporter': {
            'image': 'prom/node-exporter:latest',
            'container_name': 'node-exporter',
            'restart': 'unless-stopped',
            'ports': ['9100:9100'],
            'command': [
                '--path.procfs=/host/proc',
                '--path.sysfs=/host/sys',
                '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
            ],
            'volumes': [
                '/proc:/host/proc:ro',
                '/sys:/host/sys:ro',
                '/:/rootfs:ro'
            ],
            'networks': ['cosmos-network']
        }
    }

def generate_docker_compose(config: Dict, global_config: Dict = None) -> Dict:
    """Generate the complete docker-compose configuration"""
    if global_config is None:
        global_config = {}
    
    compose = {
        'services': {},
        'networks': {
            'cosmos-network': {
                'driver': 'bridge'
            }
        },
        'volumes': {},
        'secrets': {}
    }
    
    enabled_chains = []
    
    # Add chain services
    for chain_name, chain_config in config['chains'].items():
        if chain_config.get('enabled', False):
            enabled_chains.append(chain_name)
            compose['services'][f'{chain_name}-validator'] = create_chain_service(chain_name, chain_config, global_config)
            compose['volumes'][f'{chain_name}-data'] = None
            compose['secrets'][f'{chain_name}_mnemonic'] = {
                'file': f'./secrets/{chain_name}-mnemonic.txt'
            }
    
    if not enabled_chains:
        print("Warning: No chains are enabled in chains.yaml")
        return compose
    
    # Add Prometheus with dynamic chain monitoring
    compose['services']['prometheus'] = create_prometheus_service(enabled_chains, global_config)
    compose['volumes']['prometheus-data'] = None
    
    # Add upgrade monitor
    compose['services']['upgrade-monitor'] = create_upgrade_monitor_service(enabled_chains, global_config)
    
    # Add other monitoring services
    monitoring = create_monitoring_services(global_config)
    compose['services'].update(monitoring)
    compose['volumes']['grafana-data'] = None
    compose['volumes']['alertmanager-data'] = None
    
    return compose

def generate_prometheus_config(config: Dict, global_config: Dict = None) -> str:
    """Generate prometheus.yml configuration for all enabled chains"""
    if global_config is None:
        global_config = {}
    
    enabled_chains = {name: cfg for name, cfg in config['chains'].items() if cfg.get('enabled', False)}
    
    # Get retention from config.yml
    retention = global_config.get('monitoring', {}).get('prometheus_retention', '15d')
    
    prom_config = {
        'global': {
            'scrape_interval': '15s',
            'evaluation_interval': '15s',
            'external_labels': {
                'monitor': 'cosmos-multi-validator'
            }
        },
        'alerting': {
            'alertmanagers': [{
                'static_configs': [{'targets': ['alertmanager:9093']}]
            }]
        },
        'rule_files': ['/etc/prometheus/alerts.yml'],
        'scrape_configs': []
    }
    
    # Add scrape config for each enabled chain
    for chain_name, chain_config in enabled_chains.items():
        prometheus_port = chain_config.get('ports', {}).get('prometheus', 26660)
        chain_id = chain_config.get('chain_id', '')
        
        scrape_config = {
            'job_name': f'{chain_name}-validator',
            'static_configs': [{
                'targets': [f'{chain_name}-validator:{prometheus_port}'],
                'labels': {
                    'chain': chain_id,
                    'chain_name': chain_name,
                    'instance': f'{chain_name}-validator'
                }
            }],
            'metrics_path': '/metrics',
            'scrape_interval': '10s'
        }
        prom_config['scrape_configs'].append(scrape_config)
    
    # Add monitoring services
    prom_config['scrape_configs'].extend([
        {
            'job_name': 'prometheus',
            'static_configs': [{'targets': ['localhost:9090']}]
        },
        {
            'job_name': 'node-exporter',
            'static_configs': [{
                'targets': ['node-exporter:9100'],
                'labels': {'instance': 'validator-host'}
            }]
        },
        {
            'job_name': 'alertmanager',
            'static_configs': [{'targets': ['alertmanager:9093']}]
        }
    ])
    
    return yaml.dump(prom_config, default_flow_style=False, sort_keys=False, width=120)


def main():
    """Main function"""
    print("Generating docker-compose.yml and prometheus.yml from chains.yaml and config.yml...")
    
    # Load configurations
    config = load_chains_config()
    global_config = load_global_config()
    
    # Generate docker-compose
    compose = generate_docker_compose(config, global_config)
    
    # Write docker-compose.yml
    output_file = 'docker-compose.yml'
    with open(output_file, 'w') as f:
        f.write("# Auto-generated by generate-compose.py from chains.yaml and config.yml\n")
        f.write("# DO NOT EDIT THIS FILE MANUALLY - Changes will be overwritten\n")
        f.write("# To make changes, edit chains.yaml or config.yml and run: make generate\n\n")
        yaml.dump(compose, f, default_flow_style=False, sort_keys=False, width=120)
    
    # Generate prometheus.yml
    prom_config = generate_prometheus_config(config, global_config)
    prom_file = 'prometheus/prometheus.yml'
    with open(prom_file, 'w') as f:
        f.write("# Auto-generated by generate-compose.py from chains.yaml and config.yml\n")
        f.write("# DO NOT EDIT THIS FILE MANUALLY - Changes will be overwritten\n")
        f.write("# To make changes, edit chains.yaml or config.yml and run: make generate\n\n")
        f.write(prom_config)
    
    enabled_chains = [name for name, cfg in config['chains'].items() if cfg.get('enabled', False)]
    print(f"✓ Generated {output_file}")
    print(f"✓ Generated {prom_file}")
    print(f"✓ Enabled chains: {', '.join(enabled_chains) if enabled_chains else 'None'}")
    print(f"✓ Services created: {len(compose['services'])}")
    print(f"✓ Volumes created: {len(compose['volumes'])}")
    print("\nNext steps:")
    print("  1. Review the generated docker-compose.yml and prometheus.yml")
    print("  2. Ensure secrets exist for each chain in ./secrets/")
    print("  3. Review config.yml for global settings (Grafana password, Slack webhook, etc.)")
    print("  4. Run: docker-compose up -d")

if __name__ == '__main__':
    main()


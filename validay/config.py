"""Configuration loading and validation"""

import yaml
import os
from typing import Dict, Optional
from pathlib import Path

from .utils.errors import ConfigError


_config_cache: Optional[Dict] = None
_chains_cache: Optional[Dict] = None


def get_project_root() -> Path:
    """Get the project root directory"""
    # If running in Docker, we're already in /work
    # If running locally, find the directory containing chains.yaml
    cwd = Path.cwd()
    
    # Check current directory and parents
    for path in [cwd] + list(cwd.parents):
        if (path / "chains.yaml").exists():
            return path
    
    # Fallback to current directory
    return cwd


def load_chains_config() -> Dict:
    """Load chains.yaml configuration"""
    global _chains_cache
    
    if _chains_cache is not None:
        return _chains_cache
    
    root = get_project_root()
    config_file = root / "chains.yaml"
    
    if not config_file.exists():
        raise ConfigError(f"chains.yaml not found in {root}")
    
    try:
        with open(config_file, 'r') as f:
            config = yaml.safe_load(f)
            if not config:
                raise ConfigError("chains.yaml is empty")
            _chains_cache = config
            return config
    except yaml.YAMLError as e:
        raise ConfigError(f"Error parsing chains.yaml: {e}")
    except Exception as e:
        raise ConfigError(f"Error reading chains.yaml: {e}")


def load_global_config() -> Dict:
    """Load config.yml configuration with defaults"""
    global _config_cache
    
    if _config_cache is not None:
        return _config_cache
    
    root = get_project_root()
    config_file = root / "config.yml"
    
    defaults = {
        'paths': {
            'secrets_dir': './secrets',
            'backup_dir': './backups'
        },
        'monitoring': {
            'prometheus_retention': '15d',
            'grafana_admin_password': 'admin',
            'ports': {
                'prometheus': 9091,
                'grafana': 3001,
                'alertmanager': 9093,
                'node_exporter': 9100
            },
            'prometheus': {
                'global_scrape_interval': '15s',
                'global_evaluation_interval': '15s',
                'chain_scrape_interval': '10s'
            },
            'grafana': {
                'query_timeout': '60s'
            }
        },
        'alerting': {
            'slack_webhook_url': '',
            'alert_on_upgrade': True,
            'alert_on_sync_issues': True,
            'alert_on_missed_blocks': True,
            'group_wait': '10s',
            'group_interval': '10s',
            'repeat_interval': '3h'
        },
        'upgrade_monitoring': {
            'check_interval': 300,
            'preparation_hours': 48,
            'api_url': 'https://polkachu.com/api/v2/chain_upgrades',
            'api_timeout': 30,
            'docker_exec_timeout': 300,
            'python_version': '3.11'
        },
        'validator_defaults': {
            'moniker': '',
            'external_ip': '',
            'commission_rate': 0.10,
            'commission_max_rate': 0.20,
            'commission_max_change_rate': 0.01,
            'gas_adjustment': 1.5
        },
        'state_sync_defaults': {
            'trust_height_offset': 2000,
            'trust_period': '168h0m0s'
        },
        'consensus_defaults': {
            'timeout_commit': '5s'
        },
        'telemetry_defaults': {
            'prometheus_retention_time': 60
        },
        'binary_defaults': {
            'url_template': '{repo}/releases/download/{version}/{binary_name}-{version}-linux-amd64'
        },
        'docker': {
            'platform': 'linux/amd64',
            'go_version': '1.23',
            'base_image': 'debian:bookworm-slim',
            'network_name': 'validay-network',
            'restart_policy': 'unless-stopped',
            'healthcheck_defaults': {
                'interval': '30s',
                'timeout': '10s',
                'retries': 3,
                'start_period': '120s'
            },
            'logging_defaults': {
                'max_size': '100m',
                'max_files': 3
            }
        }
    }
    
    if not config_file.exists():
        _config_cache = defaults
        return defaults
    
    try:
        with open(config_file, 'r') as f:
            user_config = yaml.safe_load(f) or {}
            # Deep merge with defaults
            config = defaults.copy()
            for key, value in user_config.items():
                if isinstance(value, dict) and key in config and isinstance(config[key], dict):
                    # Recursively merge nested dictionaries
                    def deep_merge(base, update):
                        for k, v in update.items():
                            if k in base and isinstance(base[k], dict) and isinstance(v, dict):
                                deep_merge(base[k], v)
                            else:
                                base[k] = v
                    deep_merge(config[key], value)
                else:
                    config[key] = value
            _config_cache = config
            return config
    except yaml.YAMLError as e:
        raise ConfigError(f"Error parsing config.yml: {e}")
    except Exception as e:
        raise ConfigError(f"Error reading config.yml: {e}")


def get_chain_config(chain_name: str) -> Dict:
    """Get configuration for a specific chain"""
    chains_config = load_chains_config()
    chains = chains_config.get('chains', {})
    
    if chain_name not in chains:
        available = ', '.join(sorted(chains.keys()))
        raise ConfigError(
            f"Chain '{chain_name}' not found in chains.yaml. "
            f"Available chains: {available}"
        )
    
    return chains[chain_name]


def get_enabled_chains() -> Dict[str, Dict]:
    """Get all enabled chains"""
    chains_config = load_chains_config()
    chains = chains_config.get('chains', {})
    return {name: config for name, config in chains.items() 
            if config.get('enabled', False)}


def validate_config() -> bool:
    """Validate chains.yaml syntax"""
    try:
        load_chains_config()
        return True
    except ConfigError:
        return False


def get_secrets_dir() -> Path:
    """Get the secrets directory path from config"""
    root = get_project_root()
    config = load_global_config()
    secrets_path = config.get('paths', {}).get('secrets_dir', './secrets')
    # Resolve relative paths from project root
    if secrets_path.startswith('./') or not Path(secrets_path).is_absolute():
        return (root / secrets_path).resolve()
    return Path(secrets_path).resolve()


def get_backup_dir() -> Path:
    """Get the backup directory path from config"""
    root = get_project_root()
    config = load_global_config()
    backup_path = config.get('paths', {}).get('backup_dir', './backups')
    # Resolve relative paths from project root
    if backup_path.startswith('./') or not Path(backup_path).is_absolute():
        return (root / backup_path).resolve()
    return Path(backup_path).resolve()


def clear_cache():
    """Clear configuration cache (useful for testing or after config changes)"""
    global _config_cache, _chains_cache
    _config_cache = None
    _chains_cache = None


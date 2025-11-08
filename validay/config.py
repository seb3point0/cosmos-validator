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
            'grafana_admin_password': 'admin'
        },
        'alerting': {
            'slack_webhook_url': '',
            'alert_on_upgrade': True,
            'alert_on_sync_issues': True,
            'alert_on_missed_blocks': True
        },
        'validator_defaults': {
            'moniker': '',
            'external_ip': '',
            'commission_rate': 0.10,
            'commission_max_rate': 0.20,
            'commission_max_change_rate': 0.01
        }
    }
    
    if not config_file.exists():
        _config_cache = defaults
        return defaults
    
    try:
        with open(config_file, 'r') as f:
            user_config = yaml.safe_load(f) or {}
            # Merge with defaults
            config = defaults.copy()
            for key, value in user_config.items():
                if isinstance(value, dict) and key in config:
                    config[key].update(value)
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


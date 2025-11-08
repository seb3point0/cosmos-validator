"""Configuration commands"""

import sys

from ..output import success, error, info
from ..progress import show_progress
from ..config import (
    load_chains_config, validate_config, get_enabled_chains,
    get_project_root, clear_cache, load_global_config
)
from ..utils.errors import ConfigError
from ..utils.docker import is_container_running
from ..utils.chain_config import get_container_name
from ..utils.generate_compose import write_files
from ..output import print_table


def generate():
    """Generate docker-compose.yml and prometheus.yml"""
    # Check for required config files
    root = get_project_root()
    config_file = root / "config.yml"
    if not config_file.exists():
        error("config.yml not found")
        info(f"Create config.yml in {root} with your global settings")
        sys.exit(1)
    
    def _generate():
        root = get_project_root()
        compose_file, prom_file = write_files(root)
        
        # Get enabled chains for summary
        config = load_chains_config()
        enabled_chains = [name for name, cfg in config['chains'].items() if cfg.get('enabled', False)]
        
        return compose_file, prom_file, enabled_chains
    
    try:
        compose_file, prom_file, enabled_chains = show_progress(
            "Generating docker-compose.yml and prometheus.yml...", 
            _generate
        )
        success(f"Generated {compose_file.name}")
        success(f"Generated {prom_file.name}")
        if enabled_chains:
            info(f"Enabled chains: {', '.join(enabled_chains)}")
        else:
            info("No chains are enabled in chains.yaml")
    except Exception as e:
        error(f"Failed to generate configuration: {e}")
        sys.exit(1)


def validate():
    """Validate chains.yaml syntax"""
    try:
        if validate_config():
            success("chains.yaml is valid")
        else:
            error("chains.yaml has syntax errors")
            sys.exit(1)
    except Exception as e:
        error(f"Validation failed: {e}")
        sys.exit(1)


def list_chains():
    """List all configured chains with status"""
    try:
        chains_config = load_chains_config()
        chains = chains_config.get('chains', {})
        
        if not chains:
            info("No chains configured")
            return
        
        info("Configured chains in chains.yaml:")
        print("=" * 60)
        
        headers = ['Chain', 'Chain ID', 'Status', 'Enabled']
        rows = []
        
        for name, config in sorted(chains.items()):
            chain_id = config.get('chain_id', 'N/A')
            enabled = 'yes' if config.get('enabled', False) else 'no'
            
            container_name = get_container_name(name)
            if is_container_running(container_name):
                status = 'running'
            else:
                status = 'stopped'
            
            rows.append([name, chain_id, status, enabled])
        
        print_table(headers, rows)
    except Exception as e:
        error(f"Failed to list chains: {e}")
        sys.exit(1)


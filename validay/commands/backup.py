"""Backup commands"""

import sys
from pathlib import Path

from ..output import success, error, info
from ..config import get_enabled_chains, get_project_root, get_backup_dir
from ..utils.docker import exec_in_container, is_container_running, run_docker
from ..utils.chain_config import get_container_name, get_daemon_home
from ..utils.errors import ChainNotFoundError


def backup_all():
    """Backup all chain keys"""
    try:
        enabled_chains = get_enabled_chains()
        
        if not enabled_chains:
            info("No enabled chains found")
            return
        
        info("Backing up all chain keys...")
        
        for chain_name in enabled_chains.keys():
            container_name = get_container_name(chain_name)
            
            if not is_container_running(container_name):
                info(f"Skipping {chain_name} - container not running")
                continue
            
            try:
                # Run backup script in container
                result = exec_in_container(container_name, ['/scripts/backup-keys.sh'], interactive=False)
                
                if result.returncode == 0:
                    # Parse JSON output
                    import json
                    try:
                        backup_info = json.loads(result.stdout)
                        backup_path = backup_info.get('backup_path', '')
                        if backup_path:
                            info(f"Backup created: {backup_path}")
                    except json.JSONDecodeError:
                        pass
                    
                    # Copy backup from container
                    backup_dir = get_backup_dir() / chain_name
                    backup_dir.mkdir(parents=True, exist_ok=True)
                    
                    daemon_home = get_daemon_home(chain_name)
                    run_docker([
                        'cp', f'{container_name}:{daemon_home}/backup/.', str(backup_dir)
                    ], check=False)
                    
                    success(f"Backed up {chain_name}")
                else:
                    error(f"Failed to backup {chain_name}: {result.stderr}")
            except Exception as e:
                error(f"Error backing up {chain_name}: {e}")
        
        backup_base = get_backup_dir().relative_to(get_project_root())
        success(f"All backups complete in {backup_base}/")
    except Exception as e:
        error(f"Failed to backup all chains: {e}")
        sys.exit(1)


def list_backups():
    """List all backups"""
    try:
        root = get_project_root()
        backup_dir = get_backup_dir()
        
        if not backup_dir.exists():
            info("No backups found")
            return
        
        info("Available backups:")
        print("=" * 60)
        
        backup_files = list(backup_dir.rglob("*.tar.gz")) + list(backup_dir.rglob("*.json"))
        backup_files.sort()
        
        if backup_files:
            for backup_file in backup_files:
                rel_path = backup_file.relative_to(root)
                print(str(rel_path))
        else:
            info("No backup files found")
    except Exception as e:
        error(f"Failed to list backups: {e}")
        sys.exit(1)


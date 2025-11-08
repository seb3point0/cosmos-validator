"""System commands"""

import sys
import subprocess
from pathlib import Path

from ..output import success, error, info, warning
from ..progress import show_progress
from ..config import get_enabled_chains, get_project_root
from ..utils.docker import (
    get_all_containers, get_container_stats, run_docker, run_docker_compose
)
from ..output import print_table


def diagnose():
    """Run system diagnostics"""
    info("System Diagnostics")
    print("=" * 60)
    print("")
    
    # Docker version
    info("Docker Status:")
    try:
        result = subprocess.run(['docker', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"  {result.stdout.strip()}")
        
        result = subprocess.run(['docker-compose', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"  {result.stdout.strip()}")
    except FileNotFoundError:
        error("Docker not found")
    
    print("")
    
    # Running containers
    info("Running Containers:")
    containers = get_all_containers()
    if containers:
        headers = ['Name', 'Status', 'Ports']
        rows = [[c['name'], c['status'], c['ports']] for c in containers]
        print_table(headers, rows)
    else:
        print("  No containers found")
    
    print("")
    
    # Disk usage
    info("Disk Usage:")
    try:
        result = subprocess.run(['df', '-h'], capture_output=True, text=True)
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            for line in lines[:2]:  # Header and root
                print(f"  {line}")
    except Exception:
        pass
    
    print("")
    
    # Docker volumes
    info("Docker Volumes:")
    try:
        result = run_docker(['volume', 'ls', '--format', '{{.Name}}'], check=False)
        volumes = [v for v in result.stdout.strip().split('\n') if v and ('validator' in v or 'data' in v)]
        if volumes:
            for vol in volumes:
                print(f"  {vol}")
        else:
            print("  No validator volumes found")
    except Exception as e:
        error(f"Failed to list volumes: {e}")


def ps():
    """Show container status"""
    containers = get_all_containers()
    if containers:
        headers = ['Name', 'Status', 'Ports']
        rows = [[c['name'], c['status'], c['ports']] for c in containers]
        print_table(headers, rows)
    else:
        info("No containers found")


def stats():
    """Show container resource usage"""
    stats_list = get_container_stats()
    if stats_list:
        headers = ['Name', 'CPU', 'Memory', 'Network']
        rows = [[s['name'], s['cpu'], s['memory'], s['network']] for s in stats_list]
        print_table(headers, rows)
    else:
        info("No container stats available")


def prune():
    """Prune unused Docker resources"""
    def _prune():
        result = run_docker(['system', 'prune', '-f'], check=False)
        if result.returncode != 0:
            raise Exception(result.stderr)
    
    try:
        show_progress("Pruning unused Docker resources...", _prune)
        success("Docker cleanup complete")
    except Exception as e:
        error(f"Failed to prune Docker: {e}")
        sys.exit(1)


def clean(confirm: bool = False):
    """Clean all containers, volumes, and generated files (reset to original state)"""
    root = get_project_root()
    
    # Show warnings
    warning("=" * 60)
    warning("WARNING: This will delete ALL of the following:")
    warning("  - All Docker containers")
    warning("  - All Docker volumes (including chain data)")
    warning("  - docker-compose.yml (generated file)")
    warning("  - prometheus/prometheus.yml (generated file)")
    warning("")
    warning("This will NOT delete:")
    warning("  - secrets/ directory (your keys are safe)")
    warning("  - chains.yaml or config.yml")
    warning("=" * 60)
    print("")
    
    if not confirm:
        response = input("Are you sure you want to proceed? Type 'yes' to continue: ")
        if response.lower() != 'yes':
            info("Clean cancelled")
            return
    
    def _clean():
        # Step 1: Stop and remove all containers and volumes using docker-compose
        compose_file = root / 'docker-compose.yml'
        if compose_file.exists():
            try:
                # Stop all services
                run_docker_compose(['down', '-v'], check=False)
            except Exception as e:
                # If docker-compose fails, try to remove containers manually
                info(f"docker-compose down failed: {e}")
                info("Attempting manual cleanup...")
                
                # Get all containers
                result = run_docker(['ps', '-a', '--format', '{{.Names}}'], check=False)
                if result.returncode == 0:
                    containers = [c.strip() for c in result.stdout.strip().split('\n') if c.strip()]
                    for container in containers:
                        if 'validator' in container or 'prometheus' in container or 'grafana' in container or 'alertmanager' in container or 'upgrade-monitor' in container or 'node-exporter' in container:
                            run_docker(['rm', '-f', '-v', container], check=False)
        
        # Step 2: Remove any remaining validator-related volumes
        try:
            result = run_docker(['volume', 'ls', '--format', '{{.Name}}'], check=False)
            if result.returncode == 0:
                volumes = [v.strip() for v in result.stdout.strip().split('\n') if v.strip()]
                for volume in volumes:
                    if any(keyword in volume for keyword in ['validator', 'prometheus', 'grafana', 'alertmanager', 'data']):
                        run_docker(['volume', 'rm', '-f', volume], check=False)
        except Exception as e:
            info(f"Volume cleanup warning: {e}")
        
        # Step 3: Delete generated files
        compose_file = root / 'docker-compose.yml'
        if compose_file.exists():
            compose_file.unlink()
            info("Deleted docker-compose.yml")
        
        prom_file = root / 'prometheus' / 'prometheus.yml'
        if prom_file.exists():
            prom_file.unlink()
            info("Deleted prometheus/prometheus.yml")
    
    try:
        show_progress("Cleaning all containers, volumes, and generated files...", _clean)
        success("Clean complete! Repository reset to original state.")
        info("Your secrets/ directory and configuration files are intact.")
    except Exception as e:
        error(f"Failed to clean: {e}")
        sys.exit(1)


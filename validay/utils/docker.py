"""Docker and docker-compose operations"""

import subprocess
import sys
from typing import List, Optional, Dict
from pathlib import Path

from ..utils.errors import DockerError, ContainerNotRunningError
from ..config import get_project_root


def run_docker_compose(args: List[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run docker-compose command"""
    root = get_project_root()
    cmd = ['docker-compose', '-f', str(root / 'docker-compose.yml')] + args
    
    try:
        result = subprocess.run(
            cmd,
            cwd=root,
            capture_output=True,
            text=True,
            check=check
        )
        return result
    except subprocess.CalledProcessError as e:
        raise DockerError(f"Docker compose command failed: {e.stderr}")
    except FileNotFoundError:
        raise DockerError("docker-compose not found. Is Docker installed?")


def run_docker(args: List[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run docker command"""
    try:
        result = subprocess.run(
            ['docker'] + args,
            capture_output=True,
            text=True,
            check=check
        )
        return result
    except subprocess.CalledProcessError as e:
        raise DockerError(f"Docker command failed: {e.stderr}")
    except FileNotFoundError:
        raise DockerError("docker not found. Is Docker installed?")


def is_container_running(container_name: str) -> bool:
    """Check if a container is running"""
    result = run_docker(['ps', '--format', '{{.Names}}'], check=False)
    return container_name in result.stdout


def get_container_status(container_name: str) -> Optional[str]:
    """Get container status (running, stopped, etc.)"""
    result = run_docker(
        ['ps', '-a', '--filter', f'name={container_name}', '--format', '{{.Status}}'],
        check=False
    )
    if result.stdout.strip():
        return result.stdout.strip()
    return None


def start_container(container_name: str):
    """Start a container"""
    run_docker_compose(['up', '-d', container_name])


def stop_container(container_name: str):
    """Stop a container"""
    run_docker_compose(['stop', container_name])


def restart_container(container_name: str):
    """Restart a container"""
    run_docker_compose(['restart', container_name])


def get_container_logs(container_name: str, follow: bool = False) -> None:
    """Get container logs"""
    if follow:
        # For follow mode, we need to stream output
        root = get_project_root()
        cmd = ['docker-compose', '-f', str(root / 'docker-compose.yml'), 
               'logs', '-f', container_name]
        process = subprocess.Popen(cmd, cwd=root)
        try:
            process.wait()
        except KeyboardInterrupt:
            process.terminate()
            process.wait()
    else:
        result = run_docker_compose(['logs', container_name])
        print(result.stdout)


def exec_in_container(container_name: str, command: List[str], interactive: bool = False) -> subprocess.CompletedProcess:
    """Execute command in container"""
    if not is_container_running(container_name):
        raise ContainerNotRunningError(f"Container '{container_name}' is not running")
    
    docker_args = ['exec']
    if interactive:
        docker_args.append('-it')
    docker_args.extend([container_name] + command)
    
    return run_docker(docker_args, check=False)


def rebuild_container(container_name: str):
    """Rebuild a container"""
    run_docker_compose(['build', '--no-cache', container_name])


def remove_container(container_name: str, volumes: bool = False):
    """Remove a container"""
    args = ['rm', '-f', container_name]
    if volumes:
        args.append('-v')
    run_docker_compose(args)


def get_all_containers() -> List[Dict[str, str]]:
    """Get all containers with their status"""
    result = run_docker(['ps', '-a', '--format', '{{.Names}}|{{.Status}}|{{.Ports}}'], check=False)
    containers = []
    for line in result.stdout.strip().split('\n'):
        if line:
            parts = line.split('|', 2)
            if len(parts) == 3:
                containers.append({
                    'name': parts[0],
                    'status': parts[1],
                    'ports': parts[2]
                })
    return containers


def get_container_stats() -> List[Dict[str, str]]:
    """Get container resource usage"""
    result = run_docker(['stats', '--no-stream', '--format', 
                        '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.NetIO}}'], check=False)
    stats = []
    for line in result.stdout.strip().split('\n')[1:]:  # Skip header
        if line:
            parts = line.split('|')
            if len(parts) >= 3:
                stats.append({
                    'name': parts[0],
                    'cpu': parts[1] if len(parts) > 1 else '',
                    'memory': parts[2] if len(parts) > 2 else '',
                    'network': parts[3] if len(parts) > 3 else ''
                })
    return stats


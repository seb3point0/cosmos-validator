"""Snapshot commands"""

import sys
import subprocess

from ..output import success, error, info
from ..progress import show_progress
from ..utils.docker import stop_container, start_container, run_docker
from ..utils.chain_config import get_container_name, get_daemon_home, get_binary_name
from ..utils.errors import ChainNotFoundError, DockerError
from ..utils.validation import validate_chain_name
from ..config import get_chain_config, get_project_root


def list_snapshots(chain_name: str):
    """List available snapshots for a chain"""
    try:
        validate_chain_name(chain_name)
        config = get_chain_config(chain_name)
        
        info(f"Available snapshots for {chain_name} from Polkachu:")
        print("=" * 60)
        
        # Use curl to fetch from Polkachu API
        import subprocess
        result = subprocess.run(
            ['curl', '-s', 'https://polkachu.com/api/v2/chains'],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            import json
            try:
                chains = json.loads(result.stdout)
                for chain in chains:
                    if chain.get('name') == chain_name:
                        snapshot_url = chain.get('snapshot_url', 'N/A')
                        print(f"Latest: {snapshot_url}")
                        break
                else:
                    print(f"No snapshot information found for {chain_name}")
            except json.JSONDecodeError:
                error("Failed to parse API response")
        else:
            error("Failed to fetch snapshot information")
        
        print("")
        print(f"Visit: https://polkachu.com/tendermint_snapshots/{chain_name}")
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except Exception as e:
        error(f"Failed to list snapshots: {e}")
        sys.exit(1)


def apply(chain_name: str, snapshot_url: str):
    """Apply snapshot to a chain"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        config = get_chain_config(chain_name)
        daemon_home = get_daemon_home(chain_name)
        daemon_name = get_binary_name(chain_name)
        
        if not snapshot_url:
            error("Snapshot URL is required. Use --url <url>")
            sys.exit(1)
        
        info(f"Applying snapshot for {chain_name}...")
        
        # Stop container
        def _stop():
            stop_container(container_name)
        show_progress(f"Stopping {chain_name} validator...", _stop)
        
        # Get volume name
        root = get_project_root()
        volume_name = None
        result = run_docker(['volume', 'ls', '--format', '{{.Name}}'], check=False)
        for line in result.stdout.strip().split('\n'):
            if f'{chain_name}-data' in line:
                volume_name = line
                break
        
        if not volume_name:
            error(f"Volume for {chain_name} not found")
            sys.exit(1)
        
        # Apply snapshot
        info("Applying snapshot...")
        result = run_docker([
            'run', '--rm',
            '-v', f'{volume_name}:{daemon_home}',
            '-v', f'{root}/scripts:/scripts:ro',
            '-e', f'DAEMON_HOME={daemon_home}',
            '-e', f'DAEMON_NAME={daemon_name}',
            '-e', f'SNAPSHOT_URL={snapshot_url}',
            '--entrypoint', '/bin/bash',
            container_name,
            '-c', 'apt-get update && apt-get install -y wget lz4 && /scripts/apply-snapshot.sh'
        ])
        
        if result.returncode != 0:
            error(f"Failed to apply snapshot: {result.stderr}")
            sys.exit(1)
        
        # Restart container
        def _start():
            start_container(container_name)
        show_progress(f"Restarting {chain_name} validator...", _start)
        
        success("Snapshot applied successfully")
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)


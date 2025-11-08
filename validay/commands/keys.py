"""Key management commands"""

import sys
import json

from ..output import success, error, info, warning
from ..progress import show_progress
from ..config import get_project_root, get_chain_config, get_secrets_dir, get_backup_dir
from ..utils.docker import exec_in_container, is_container_running
from ..utils.chain_config import get_container_name, get_daemon_home, get_binary_name
from ..utils.errors import ChainNotFoundError, ContainerNotRunningError
from ..utils.validation import validate_chain_name
from ..utils.generate_validator_key import (
    generate_validator_key, generate_validator_key_from_mnemonic
)


def setup(chain_name: str):
    """Setup private key for a chain"""
    try:
        validate_chain_name(chain_name)
        secrets_dir = get_secrets_dir()
        secrets_dir.mkdir(parents=True, exist_ok=True)
        
        key_file = secrets_dir / f"{chain_name}-private-key.json"
        
        if key_file.exists():
            warning(f"secrets/{chain_name}-private-key.json already exists")
            response = input("Overwrite? [y/N]: ")
            if response.lower() != 'y':
                info("Cancelled")
                return
        
        print(f"Choose an option for {chain_name} private key:")
        print("  1) Provide a mnemonic (will be converted to priv_validator_key.json)")
        print("  2) Provide a priv_validator_key.json file")
        print("  3) Generate a new private key automatically")
        
        choice = input("Enter choice [1/2/3]: ")
        
        if choice == "1":
            print("")
            print("Enter your mnemonic phrase (12-24 words, separated by spaces):")
            print("Paste it here and press Enter:")
            mnemonic = input().strip()
            
            if not mnemonic:
                error("Empty mnemonic. Cancelled.")
                sys.exit(1)
            
            word_count = len(mnemonic.split())
            if word_count < 12 or word_count > 24:
                error(f"Mnemonic should be 12-24 words. Got {word_count} words.")
                sys.exit(1)
            
            try:
                result = generate_validator_key_from_mnemonic(mnemonic, str(key_file), chain_name)
                key_file.chmod(0o600)
                success(f"Validator key derived from mnemonic and saved to secrets/{chain_name}-private-key.json")
                info(f"Validator Address (hex): {result['address_hex']}")
                if result['account_address']:
                    info(f"Account Address ({result['address_prefix']}1...): {result['account_address']}")
            except Exception as e:
                error(f"Failed to generate key: {e}")
                sys.exit(1)
        
        elif choice == "2":
            print("")
            print(f"Paste your priv_validator_key.json content for {chain_name}:")
            print("(Press Enter, then paste JSON, then Ctrl+D or type 'EOF' on new line)")
            print("(You can also paste the entire JSON in one go)")
            
            lines = []
            try:
                while True:
                    line = input()
                    if line.strip() == 'EOF':
                        break
                    lines.append(line)
            except EOFError:
                pass
            
            private_key = '\n'.join(lines)
            
            if not private_key.strip():
                error("Empty private key. Cancelled.")
                sys.exit(1)
            
            try:
                json.loads(private_key)
            except json.JSONDecodeError:
                error("Invalid JSON format. Please provide valid priv_validator_key.json content.")
                sys.exit(1)
            
            with open(key_file, 'w') as f:
                f.write(private_key)
            key_file.chmod(0o600)
            success(f"Private key saved to secrets/{chain_name}-private-key.json")
        
        elif choice == "3":
            info(f"Generating new private key for {chain_name}...")
            
            try:
                result = generate_validator_key(str(key_file), chain_name)
                key_file.chmod(0o600)
                success(f"Private key generated and saved to secrets/{chain_name}-private-key.json")
                print("")
                print("=" * 60)
                warning("CRITICAL: SAVE THIS MNEMONIC PHRASE")
                print("=" * 60)
                print(result['mnemonic'])
                print("=" * 60)
                print("")
                info(f"Validator Address (hex): {result['address_hex']}")
                if result['account_address']:
                    info(f"Account Address ({result['address_prefix']}1...): {result['account_address']}")
            except Exception as e:
                error(f"Failed to generate key: {e}")
                sys.exit(1)
        else:
            error("Invalid choice. Cancelled.")
            sys.exit(1)
    
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except Exception as e:
        error(f"Failed to setup keys: {e}")
        sys.exit(1)


def create(chain_name: str):
    """Create new keys in container"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        config = get_chain_config(chain_name)
        daemon_name = get_binary_name(chain_name)
        daemon_home = get_daemon_home(chain_name)
        
        info(f"Creating new keys for {chain_name}...")
        result = exec_in_container(
            container_name,
            ['bash', '-c', f'{daemon_name} keys add validator --keyring-backend test --home {daemon_home}'],
            interactive=True
        )
        sys.exit(result.returncode if result.returncode else 0)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)


def import_key(chain_name: str):
    """Import keys from private key file"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        key_file = get_secrets_dir() / f"{chain_name}-private-key.json"
        
        if not key_file.exists():
            error(f"secrets/{chain_name}-private-key.json not found")
            sys.exit(1)
        
        info(f"Importing keys for {chain_name} from private key...")
        result = exec_in_container(container_name, ['/scripts/setup-keys.sh'], interactive=False)
        
        if result.returncode == 0:
            # Parse JSON output
            import json
            try:
                key_info = json.loads(result.stdout)
                validator_addr = key_info.get('validator_address', '')
                account_addr = key_info.get('account_address', '')
                
                if validator_addr:
                    success(f"Keys imported successfully")
                    info(f"Validator Address: {validator_addr}")
                    if account_addr:
                        info(f"Account Address: {account_addr}")
                else:
                    warning("Keys imported but validator address not found")
            except json.JSONDecodeError:
                # Fallback if JSON parsing fails
                if "INFO:" in result.stdout:
                    success("Keys imported successfully")
                else:
                    info(result.stdout)
        else:
            error(f"Failed to import keys: {result.stderr}")
            sys.exit(1)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)


def show(chain_name: str):
    """Show validator addresses"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        config = get_chain_config(chain_name)
        daemon_name = get_binary_name(chain_name)
        daemon_home = get_daemon_home(chain_name)
        
        info(f"Addresses for {chain_name}:")
        print("=" * 50)
        
        result = exec_in_container(
            container_name,
            ['bash', '-c', f'''
                VALIDATOR_ADDR=$({daemon_name} keys show validator -a --keyring-backend test --home {daemon_home} 2>/dev/null)
                VALOPER_ADDR=$({daemon_name} keys show validator --bech val -a --keyring-backend test --home {daemon_home} 2>/dev/null)
                echo "Validator Address: $VALIDATOR_ADDR"
                echo "Operator Address:  $VALOPER_ADDR"
            '''],
            interactive=False
        )
        
        if result.returncode == 0:
            print(result.stdout)
        else:
            error("No validator key found")
            sys.exit(1)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)


def backup(chain_name: str):
    """Backup keys for a chain"""
    try:
        validate_chain_name(chain_name)
        container_name = get_container_name(chain_name)
        
        if not is_container_running(container_name):
            error(f"Container '{container_name}' is not running")
            sys.exit(1)
        
        backup_dir = get_backup_dir() / chain_name
        backup_dir.mkdir(parents=True, exist_ok=True)
        
        info(f"Backing up keys for {chain_name}...")
        result = exec_in_container(container_name, ['/scripts/backup-keys.sh'], interactive=False)
        
        if result.returncode == 0:
            # Parse JSON output
            import json
            try:
                backup_info = json.loads(result.stdout)
                backup_path = backup_info.get('backup_path', '')
                if backup_path:
                    info(f"Backup created in container: {backup_path}")
            except json.JSONDecodeError:
                pass
            
            # Copy backup from container
            from ..utils.docker import run_docker
            daemon_home = get_daemon_home(chain_name)
            
            run_docker([
                'cp', f'{container_name}:{daemon_home}/backup/.', str(backup_dir)
            ], check=False)
            
            backup_base = get_backup_dir().relative_to(get_project_root())
            success(f"Backup saved to {backup_base}/{chain_name}/")
        else:
            error(f"Backup failed: {result.stderr}")
            sys.exit(1)
    except ChainNotFoundError as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)


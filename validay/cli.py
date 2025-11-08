"""Main CLI entry point using argparse"""

import argparse
import sys

from . import __version__
from .output import error, info
from .utils.errors import ValidatorError, ChainNotFoundError, ContainerNotRunningError, ConfigError, DockerError

# Import command modules
from .commands import (
    chain, keys, query, snapshot, upgrade, service, config, backup, system
)


def create_parser():
    """Create the main argument parser"""
    parser = argparse.ArgumentParser(
        prog='validay',
        description='Multi-chain Cosmos validator management',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        add_help=False
    )
    
    # Help is handled manually in main()
    parser.add_argument('--version', action='version', version=f'%(prog)s {__version__}', help='Show version and exit')
    
    subparsers = parser.add_subparsers(dest='command', metavar='COMMAND', help='')
    
    # Chain commands
    chain_parser = subparsers.add_parser('chain', help='Manage chain validators', add_help=False)
    chain_parser.add_argument('-h', '--help', action='help', help='Show this help message and exit')
    chain_subparsers = chain_parser.add_subparsers(dest='subcommand', metavar='COMMAND', help='')
    
    chain_start = chain_subparsers.add_parser('start', help='Start a chain')
    chain_start.add_argument('chain', help='Chain name')
    
    chain_stop = chain_subparsers.add_parser('stop', help='Stop a chain')
    chain_stop.add_argument('chain', help='Chain name')
    
    chain_restart = chain_subparsers.add_parser('restart', help='Restart a chain')
    chain_restart.add_argument('chain', help='Chain name')
    
    chain_logs = chain_subparsers.add_parser('logs', help='View chain logs')
    chain_logs.add_argument('chain', help='Chain name')
    chain_logs.add_argument('--no-follow', action='store_true', help='Do not follow logs')
    
    chain_status = chain_subparsers.add_parser('status', help='Check chain status')
    chain_status.add_argument('chain', help='Chain name')
    
    chain_shell = chain_subparsers.add_parser('shell', help='Enter chain container shell')
    chain_shell.add_argument('chain', help='Chain name')
    
    chain_init = chain_subparsers.add_parser('init', help='Initialize chain')
    chain_init.add_argument('chain', help='Chain name')
    
    chain_rebuild = chain_subparsers.add_parser('rebuild', help='Rebuild chain container')
    chain_rebuild.add_argument('chain', help='Chain name')
    
    chain_clean = chain_subparsers.add_parser('clean', help='Remove chain container and volume')
    chain_clean.add_argument('chain', help='Chain name')
    chain_clean.add_argument('--yes', action='store_true', help='Skip confirmation')
    
    chain_enable = chain_subparsers.add_parser('enable', help='Enable chain in chains.yaml')
    chain_enable.add_argument('chain', help='Chain name')
    
    chain_disable = chain_subparsers.add_parser('disable', help='Disable chain in chains.yaml')
    chain_disable.add_argument('chain', help='Chain name')
    
    chain_create_validator = chain_subparsers.add_parser('create-validator', help='Create validator on chain')
    chain_create_validator.add_argument('chain', help='Chain name')
    
    # Keys commands
    keys_parser = subparsers.add_parser('keys', help='Manage validator keys', add_help=False)
    keys_parser.add_argument('-h', '--help', action='help', help='Show this help message and exit')
    keys_subparsers = keys_parser.add_subparsers(dest='subcommand', metavar='COMMAND', help='')
    
    keys_setup = keys_subparsers.add_parser('setup', help='Setup private key')
    keys_setup.add_argument('chain', help='Chain name')
    
    keys_create = keys_subparsers.add_parser('create', help='Create new keys')
    keys_create.add_argument('chain', help='Chain name')
    
    keys_import = keys_subparsers.add_parser('import', help='Import keys from private key')
    keys_import.add_argument('chain', help='Chain name')
    
    keys_show = keys_subparsers.add_parser('show', help='Show validator addresses')
    keys_show.add_argument('chain', help='Chain name')
    
    # Query commands
    query_parser = subparsers.add_parser('query', help='Query chain data', add_help=False)
    query_parser.add_argument('-h', '--help', action='help', help='Show this help message and exit')
    query_subparsers = query_parser.add_subparsers(dest='subcommand', metavar='COMMAND', help='')
    
    query_balance = query_subparsers.add_parser('balance', help='Query account balance')
    query_balance.add_argument('chain', help='Chain name')
    
    query_validator = query_subparsers.add_parser('validator', help='Query validator info')
    query_validator.add_argument('chain', help='Chain name')
    
    query_delegations = query_subparsers.add_parser('delegations', help='Query delegations')
    query_delegations.add_argument('chain', help='Chain name')
    
    # Snapshot commands
    snapshot_parser = subparsers.add_parser('snapshot', help='Snapshot operations', add_help=False)
    snapshot_parser.add_argument('-h', '--help', action='help', help='Show this help message and exit')
    snapshot_subparsers = snapshot_parser.add_subparsers(dest='subcommand', metavar='COMMAND', help='')
    
    snapshot_list = snapshot_subparsers.add_parser('list', help='List available snapshots')
    snapshot_list.add_argument('chain', help='Chain name')
    
    snapshot_apply = snapshot_subparsers.add_parser('apply', help='Apply snapshot')
    snapshot_apply.add_argument('chain', help='Chain name')
    snapshot_apply.add_argument('--url', required=True, help='Snapshot URL')
    
    # Upgrade commands
    upgrade_parser = subparsers.add_parser('upgrade', help='Upgrade management', add_help=False)
    upgrade_parser.add_argument('-h', '--help', action='help', help='Show this help message and exit')
    upgrade_subparsers = upgrade_parser.add_subparsers(dest='subcommand', metavar='COMMAND', help='')
    
    upgrade_check = upgrade_subparsers.add_parser('check', help='Check upgrade status')
    upgrade_check.add_argument('chain', help='Chain name')
    
    upgrade_prepare = upgrade_subparsers.add_parser('prepare', help='Prepare upgrade')
    upgrade_prepare.add_argument('chain', help='Chain name')
    upgrade_prepare.add_argument('--name', required=True, help='Upgrade name')
    upgrade_prepare.add_argument('--url', required=True, help='Binary URL')
    upgrade_prepare.add_argument('--height', help='Upgrade height (optional)')
    
    # Backup commands
    backup_parser = subparsers.add_parser('backup', help='Backup operations', add_help=False)
    backup_parser.add_argument('-h', '--help', action='help', help='Show this help message and exit')
    backup_parser.add_argument('chain', nargs='?', help='Chain name (backs up single chain, omit for all)')
    backup_parser.add_argument('--list', action='store_true', help='List all backups')
    
    # Service commands
    service_parser = subparsers.add_parser('service', help='Monitoring services', add_help=False)
    service_parser.add_argument('-h', '--help', action='help', help='Show this help message and exit')
    service_subparsers = service_parser.add_subparsers(dest='subcommand', metavar='COMMAND', help='')
    
    service_subparsers.add_parser('start', help='Start all monitoring services')
    service_subparsers.add_parser('stop', help='Stop all services')
    service_subparsers.add_parser('restart', help='Restart all services')
    
    service_logs = service_subparsers.add_parser('logs', help='View service logs')
    service_logs.add_argument('service', nargs='?', help='Service name (prometheus/grafana/alertmanager)')
    
    # Top-level setup/maintenance commands
    subparsers.add_parser('generate', help='Generate docker-compose.yml and prometheus.yml')
    subparsers.add_parser('validate', help='Validate chains.yaml syntax')
    subparsers.add_parser('list', help='List all configured chains')
    subparsers.add_parser('ps', help='Show container status')
    subparsers.add_parser('stats', help='Show container resource usage')
    subparsers.add_parser('diagnose', help='Run system diagnostics')
    subparsers.add_parser('prune', help='Prune unused Docker resources')
    subparsers.add_parser('upgrades', help='List all pending upgrades')
    
    # Clean command
    clean_parser = subparsers.add_parser('clean', help='Clean all containers, volumes, and generated files')
    clean_parser.add_argument('--yes', action='store_true', help='Skip confirmation')
    
    # Help and version commands (not shown in help output)
    subparsers.add_parser('help', help=argparse.SUPPRESS)
    subparsers.add_parser('version', help=argparse.SUPPRESS)
    
    # Return parser and subparsers for help display
    return parser, {
        'chain': chain_parser,
        'keys': keys_parser,
        'query': query_parser,
        'snapshot': snapshot_parser,
        'upgrade': upgrade_parser,
        'service': service_parser,
        'backup': backup_parser
    }


def print_help(parser):
    """Print help in Docker-style format"""
    print(f"Usage:  {parser.prog} [OPTIONS] COMMAND\n")
    print(f"{parser.description}\n")
    print("Commands:")
    
    # Group commands into Setup/Maintenance and Daily Operations
    setup_maintenance = {
        'clean': 'Clean all containers, volumes, and generated files',
        'generate': 'Generate docker-compose.yml and prometheus.yml',
        'validate': 'Validate chains.yaml syntax',
        'list': 'List all configured chains',
        'ps': 'Show container status',
        'stats': 'Show container resource usage',
        'diagnose': 'Run system diagnostics',
        'prune': 'Prune unused Docker resources',
        'upgrades': 'List all pending upgrades',
    }
    
    daily_operations = {
        'chain': 'Manage chain validators',
        'keys': 'Manage validator keys',
        'query': 'Query chain data',
        'backup': 'Backup operations',
        'snapshot': 'Snapshot operations',
        'upgrade': 'Upgrade management',
        'service': 'Monitoring services',
    }
    
    print("Setup & Maintenance:")
    for cmd, desc in sorted(setup_maintenance.items()):
        print(f"  {cmd:<12} {desc}")
    
    print("\nChain Operations:")
    for cmd, desc in sorted(daily_operations.items()):
        print(f"  {cmd:<12} {desc}")
    
    print("\nOptions:")
    print("  -h, --help     Show this help message and exit")
    print("      --version  Show version and exit")
    print(f"\nRun '{parser.prog} COMMAND --help' for more information on a command.")


def print_subcommand_help(main_parser, command_name, subcommand_parser):
    """Print subcommand help in Docker-style format"""
    descriptions = {
        'chain': 'Manage chain validators',
        'keys': 'Manage validator keys',
        'query': 'Query chain data',
        'backup': 'Backup operations',
        'snapshot': 'Snapshot operations',
        'upgrade': 'Upgrade management',
        'service': 'Monitoring services',
    }
    
    desc = descriptions.get(command_name, command_name)
    print(f"Usage:  {main_parser.prog} {command_name} COMMAND\n")
    print(f"{desc}\n")
    print("Commands:")
    
    # Get subcommands from the subcommand parser
    subparser_action = None
    for action in subcommand_parser._actions:
        if isinstance(action, argparse._SubParsersAction):
            subparser_action = action
            break
    
    if subparser_action:
        # The help text is stored in the subparser action's _choices_actions
        for choice_action in sorted(subparser_action._choices_actions, key=lambda x: x.dest):
            cmd_name = choice_action.dest
            help_text = choice_action.help or ''
            
            # Get the subcommand parser to check for required arguments
            cmd_parser = subparser_action.choices.get(cmd_name)
            if cmd_parser:
                # Find required positional arguments
                required_args = []
                for action in cmd_parser._actions:
                    # Check for positional arguments (not options)
                    if not action.option_strings and action.dest != 'help':
                        # Get the metavar or use the dest name, format as <param>
                        if action.metavar:
                            metavar = f"<{action.metavar.lower()}>"
                        else:
                            metavar = f"<{action.dest.lower()}>"
                        if action.required or (not hasattr(action, 'required') and action.nargs not in ['?', '*', argparse.OPTIONAL]):
                            required_args.append(metavar)
                
                # Format command with parameters
                if required_args:
                    params = ' '.join(required_args)
                    # Calculate spacing: command name + space + params should align
                    cmd_with_params = f"{cmd_name} {params}"
                    print(f"  {cmd_with_params:<20} {help_text}")
                else:
                    print(f"  {cmd_name:<20} {help_text}")
            else:
                print(f"  {cmd_name:<12} {help_text}")
    
    print("\nOptions:")
    print("  -h, --help     Show this help message and exit")
    print(f"\nRun '{main_parser.prog} {command_name} COMMAND --help' for more information on a command.")


def check_dependencies():
    """Check Python version and required dependencies"""
    import sys
    
    # Check Python version (3.9+)
    if sys.version_info < (3, 9):
        error(f"Python 3.9 or later is required. Found Python {sys.version_info.major}.{sys.version_info.minor}")
        sys.exit(1)
    
    # Check required dependencies
    missing_deps = []
    try:
        import yaml
    except ImportError:
        missing_deps.append("pyyaml")
    
    try:
        import cryptography
    except ImportError:
        missing_deps.append("cryptography")
    
    try:
        import mnemonic
    except ImportError:
        missing_deps.append("mnemonic")
    
    try:
        import bech32
    except ImportError:
        missing_deps.append("bech32")
    
    try:
        import bip_utils
    except ImportError:
        missing_deps.append("bip-utils")
    
    if missing_deps:
        error("Missing required Python dependencies:")
        for dep in missing_deps:
            error(f"  - {dep}")
        info("Install dependencies with: python3 -m pip install -r requirements.txt")
        sys.exit(1)


def main():
    """Main CLI entry point"""
    # Check dependencies first
    check_dependencies()
    
    parser, subparsers_dict = create_parser()
    
    # Handle --help before parsing (to show custom help)
    if '--help' in sys.argv or '-h' in sys.argv:
        if len(sys.argv) == 2:  # Just 'validay --help'
            print_help(parser)
            sys.exit(0)
        elif len(sys.argv) == 3:  # 'validay COMMAND --help'
            cmd = sys.argv[1]
            if cmd in subparsers_dict:
                print_subcommand_help(parser, cmd, subparsers_dict[cmd])
                sys.exit(0)
        # For deeper subcommand help, let argparse handle it
    
    args = parser.parse_args()
    
    if not args.command:
        print_help(parser)
        sys.exit(0)
    
    try:
        # Route to appropriate command handler
        if args.command == 'chain':
            if not args.subcommand:
                print_subcommand_help(parser, 'chain', subparsers_dict['chain'])
                sys.exit(0)
            elif args.subcommand == 'start':
                chain.start(args.chain)
            elif args.subcommand == 'stop':
                chain.stop(args.chain)
            elif args.subcommand == 'restart':
                chain.restart(args.chain)
            elif args.subcommand == 'logs':
                chain.logs(args.chain, follow=not args.no_follow)
            elif args.subcommand == 'status':
                chain.status(args.chain)
            elif args.subcommand == 'shell':
                chain.shell(args.chain)
            elif args.subcommand == 'init':
                chain.init(args.chain)
            elif args.subcommand == 'rebuild':
                chain.rebuild(args.chain)
            elif args.subcommand == 'clean':
                chain.clean(args.chain, confirm=args.yes)
            elif args.subcommand == 'enable':
                chain.enable(args.chain)
            elif args.subcommand == 'disable':
                chain.disable(args.chain)
            elif args.subcommand == 'create-validator':
                chain.create_validator(args.chain)
            else:
                print_subcommand_help(parser, 'chain', subparsers_dict['chain'])
                sys.exit(0)
        
        elif args.command == 'keys':
            if not args.subcommand:
                print_subcommand_help(parser, 'keys', subparsers_dict['keys'])
                sys.exit(0)
            elif args.subcommand == 'setup':
                keys.setup(args.chain)
            elif args.subcommand == 'create':
                keys.create(args.chain)
            elif args.subcommand == 'import':
                keys.import_key(args.chain)
            elif args.subcommand == 'show':
                keys.show(args.chain)
            else:
                print_subcommand_help(parser, 'keys', subparsers_dict['keys'])
                sys.exit(0)
        
        elif args.command == 'query':
            if not args.subcommand:
                print_subcommand_help(parser, 'query', subparsers_dict['query'])
                sys.exit(0)
            elif args.subcommand == 'balance':
                query.balance(args.chain)
            elif args.subcommand == 'validator':
                query.validator_info(args.chain)
            elif args.subcommand == 'delegations':
                query.delegations(args.chain)
            else:
                print_subcommand_help(parser, 'query', subparsers_dict['query'])
                sys.exit(0)
        
        elif args.command == 'snapshot':
            if not args.subcommand:
                print_subcommand_help(parser, 'snapshot', subparsers_dict['snapshot'])
                sys.exit(0)
            elif args.subcommand == 'list':
                snapshot.list_snapshots(args.chain)
            elif args.subcommand == 'apply':
                snapshot.apply(args.chain, args.url)
            else:
                print_subcommand_help(parser, 'snapshot', subparsers_dict['snapshot'])
                sys.exit(0)
        
        elif args.command == 'upgrade':
            if not args.subcommand:
                print_subcommand_help(parser, 'upgrade', subparsers_dict['upgrade'])
                sys.exit(0)
            elif args.subcommand == 'check':
                upgrade.check(args.chain)
            elif args.subcommand == 'prepare':
                upgrade.prepare(args.chain, args.name, args.url, args.height)
            else:
                print_subcommand_help(parser, 'upgrade', subparsers_dict['upgrade'])
                sys.exit(0)
        
        elif args.command == 'service':
            if not args.subcommand:
                print_subcommand_help(parser, 'service', subparsers_dict['service'])
                sys.exit(0)
            elif args.subcommand == 'start':
                service.start_services()
            elif args.subcommand == 'stop':
                service.stop_services()
            elif args.subcommand == 'restart':
                service.restart_services()
            elif args.subcommand == 'logs':
                service.logs(args.service)
            else:
                print_subcommand_help(parser, 'service', subparsers_dict['service'])
                sys.exit(0)
        
        elif args.command == 'backup':
            if args.list:
                backup.list_backups()
            elif args.chain:
                # Import keys.backup function for single chain backup
                from .commands import keys
                keys.backup(args.chain)
            else:
                backup.backup_all()
        
        elif args.command == 'generate':
            config.generate()
        
        elif args.command == 'validate':
            config.validate()
        
        elif args.command == 'list':
            config.list_chains()
        
        elif args.command == 'ps':
            system.ps()
        
        elif args.command == 'stats':
            system.stats()
        
        elif args.command == 'diagnose':
            system.diagnose()
        
        elif args.command == 'prune':
            system.prune()
        
        elif args.command == 'upgrades':
            upgrade.list_upgrades()
        
        elif args.command == 'clean':
            system.clean(confirm=args.yes)
        
        elif args.command == 'help':
            print_help(parser)
            sys.exit(0)
        
        elif args.command == 'version':
            print(f"{parser.prog} {__version__}")
            sys.exit(0)
        
        else:
            print_help(parser)
            sys.exit(0)
    
    except KeyboardInterrupt:
        info("Operation cancelled")
        sys.exit(130)
    except (ChainNotFoundError, ConfigError) as e:
        error(str(e))
        sys.exit(1)
    except ContainerNotRunningError as e:
        error(str(e))
        sys.exit(1)
    except DockerError as e:
        error(str(e))
        sys.exit(1)
    except ValidatorError as e:
        error(str(e))
        sys.exit(1)
    except Exception as e:
        error(f"Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()


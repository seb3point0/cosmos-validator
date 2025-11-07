.PHONY: help setup start stop restart logs status backup backup-copy backup-full backup-list clean build generate \
        list-chains validate-config start-chain stop-chain restart-chain logs-chain status-chain shell-chain \
        create-mnemonic create-keys import-keys show-address backup-keys backup-all list-backups \
        create-validator query-balance query-validator query-delegations init-chain \
        apply-snapshot list-snapshots urls open-grafana watch-status watch-chain \
        prepare-upgrade list-upgrades check-upgrade rebuild rebuild-chain clean-chain diagnose \
        enable-chain disable-chain logs-node logs-prom logs-grafana logs-alert sync-status \
        ps stats prune-docker grafana-url prometheus-url alertmanager-url

help:
	@echo "Multi-Chain Cosmos Validator - Available Commands"
	@echo "=================================================="
	@echo ""
	@echo "⚙️  Setup & Configuration:"
	@echo "  make setup              - First-time setup (create dirs, copy templates)"
	@echo "  make generate           - Generate docker-compose.yml from chains.yaml"
	@echo "  make list-chains        - List all configured chains"
	@echo "  make validate-config    - Validate chains.yaml syntax"
	@echo ""
	@echo "🚀 Quick Start:"
	@echo "  make start              - Start all enabled services"
	@echo "  make stop               - Stop all services"
	@echo "  make restart            - Restart all services"
	@echo "  make status             - Check status of all validators"
	@echo ""
	@echo "🔗 Chain-Specific Commands:"
	@echo "  make start-chain <chain>     - Start specific chain (e.g. make start-chain osmosis)"
	@echo "  make stop-chain <chain>      - Stop specific chain"
	@echo "  make restart-chain <chain>   - Restart specific chain"
	@echo "  make logs-chain <chain>      - View logs for specific chain"
	@echo "  make status-chain <chain>    - Check status of specific chain"
	@echo "  make shell-chain <chain>     - Enter shell for specific chain"
	@echo "  make init-chain <chain>      - Initialize chain (run init script)"
	@echo ""
	@echo "🔑 Key Management:"
	@echo "  make create-mnemonic <chain> - Create mnemonic file for chain"
	@echo "  make create-keys <chain>     - Create new keys for chain"
	@echo "  make import-keys <chain>     - Import keys from mnemonic"
	@echo "  make show-address <chain>    - Show validator address"
	@echo "  make backup-keys <chain>     - Backup keys for specific chain"
	@echo ""
	@echo "👤 Validator Operations:"
	@echo "  make create-validator <chain>  - Create validator for specific chain"
	@echo "  make query-balance <chain>     - Query balance for chain"
	@echo "  make query-validator <chain>   - Query validator info"
	@echo "  make query-delegations <chain> - Query delegations"
	@echo ""
	@echo "📊 Monitoring & URLs:"
	@echo "  make urls               - Show all monitoring URLs"
	@echo "  make grafana-url        - Show Grafana URL"
	@echo "  make prometheus-url     - Show Prometheus URL"
	@echo "  make open-grafana       - Open Grafana in browser"
	@echo ""
	@echo "🔄 Upgrade Management:"
	@echo "  make list-upgrades          - List pending upgrades from Polkachu"
	@echo "  make check-upgrade <chain>  - Check if upgrade is ready for chain"
	@echo ""
	@echo "💾 Snapshot Operations:"
	@echo "  make list-snapshots <chain> - List available snapshots for chain"
	@echo ""
	@echo "🔐 Backup & Security:"
	@echo "  make backup-all          - Backup all chain keys"
	@echo "  make backup-keys <chain> - Backup specific chain"
	@echo "  make list-backups        - List all backups"
	@echo ""
	@echo "📦 Container Management:"
	@echo "  make rebuild              - Rebuild all containers"
	@echo "  make rebuild-chain <chain> - Rebuild specific chain"
	@echo "  make clean-chain <chain>   - Remove chain container and volume"
	@echo "  make ps                   - Show container status"
	@echo "  make stats                - Show container resource usage"
	@echo ""
	@echo "🔧 Chain Configuration:"
	@echo "  make enable-chain <chain>  - Enable chain in chains.yaml"
	@echo "  make disable-chain <chain> - Disable chain in chains.yaml"
	@echo ""
	@echo "🔍 Diagnostics & Monitoring:"
	@echo "  make diagnose              - Run system diagnostics"
	@echo "  make watch-status          - Watch all chain statuses (auto-refresh)"
	@echo "  make watch-chain <chain>   - Watch specific chain status"
	@echo ""
	@echo "📊 Logs & Monitoring:"
	@echo "  make logs               - View all logs (follow)"
	@echo "  make logs-node          - View validator node logs"
	@echo "  make logs-prom          - View Prometheus logs"
	@echo "  make logs-grafana       - View Grafana logs"
	@echo "  make logs-alert         - View Alertmanager logs"
	@echo "  make sync-status        - Check blockchain sync status"
	@echo ""
	@echo "🔑 Validator Operations:"
	@echo "  make start-validator    - Auto-create validator (recommended)"
	@echo "  make create-validator   - Manually create validator"
	@echo "  make setup-keys         - Set up validator keys"
	@echo "  make keys-list          - List all keys"
	@echo "  make keys-show          - Show validator key"
	@echo "  make keys-add           - Create new validator key"
	@echo "  make keys-recover       - Recover validator key from mnemonic"
	@echo "  make validator-address  - Show validator addresses"
	@echo ""
	@echo "💾 Backup & Recovery:"
	@echo "  make backup             - Create backup inside container"
	@echo "  make backup-copy        - Copy validator keys to host (./validator-backup/)"
	@echo "  make backup-full        - Full backup (create + copy to host)"
	@echo "  make backup-list        - List all backup files in container"
	@echo ""
	@echo "⚙️  Maintenance:"
	@echo "  make apply-snapshot     - Apply a blockchain snapshot"
	@echo "  make update-peers       - Fetch fresh peer list"
	@echo "  make check-upgrades     - Check for pending upgrades"
	@echo "  make version            - Show gaiad version"
	@echo "  make cosmovisor-version - Show cosmovisor version"
	@echo "  make prune-docker       - Prune unused Docker resources"
	@echo ""
	@echo "🌐 Monitoring URLs:"
	@echo "  make grafana-url        - Show Grafana URL"
	@echo "  make prometheus-url     - Show Prometheus URL"
	@echo "  make alertmanager-url   - Show Alertmanager URL"
	@echo ""
	@echo "⚠️  Danger Zone:"
	@echo "  make clean              - Remove all containers and volumes (DESTRUCTIVE!)"
	@echo ""

start:
	@echo "Starting all enabled validators..."
	docker-compose up -d
	@echo "Validators started. Use 'make logs' to view logs."

stop:
	@echo "Stopping all validators..."
	docker-compose down
	@echo "Validators stopped."

restart:
	@echo "Restarting all validators..."
	docker-compose restart
	@echo "Validators restarted."

build:
	@echo "Building containers..."
	docker-compose build --no-cache

logs:
	@echo "Viewing all logs (Ctrl+C to exit)..."
	docker-compose logs -f

logs-node:
	@echo "Viewing validator node logs (Ctrl+C to exit)..."
	@echo "Note: Use 'make logs-chain <chain>' for specific chain logs"
	@docker-compose logs -f | grep -E "(validator|node)" || docker-compose logs -f

logs-prom:
	@echo "Viewing Prometheus logs (Ctrl+C to exit)..."
	docker-compose logs -f prometheus

logs-grafana:
	@echo "Viewing Grafana logs (Ctrl+C to exit)..."
	docker-compose logs -f grafana

logs-alert:
	@echo "Viewing Alertmanager logs (Ctrl+C to exit)..."
	docker-compose logs -f alertmanager

status:
	@echo "Checking all validator statuses..."
	@python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); \
		chains = {n: c for n, c in config.get('chains', {}).items() if c.get('enabled')}; \
		import subprocess; \
		[subprocess.run(['docker', 'exec', f'{name}-validator', '/scripts/check-status.sh'], check=False) \
		for name in chains.keys() if subprocess.run(['docker', 'ps', '--format', '{{.Names}}'], \
		capture_output=True, text=True).stdout.find(f'{name}-validator') >= 0]"

sync-status:
	@echo "Checking sync status for all chains..."
	@python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); \
		chains = {n: c for n, c in config.get('chains', {}).items() if c.get('enabled')}; \
		import subprocess, json; \
		[print(f'\n{name}:') or subprocess.run(['docker', 'exec', f'{name}-validator', 'curl', '-s', \
		f'http://localhost:{cfg[\"ports\"][\"rpc\"]}/status'], check=False) \
		for name, cfg in chains.items() if subprocess.run(['docker', 'ps', '--format', '{{.Names}}'], \
		capture_output=True, text=True).stdout.find(f'{name}-validator') >= 0]"

backup:
	@echo "Backing up validator keys for all chains..."
	@python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); \
		chains = {n: c for n, c in config.get('chains', {}).items() if c.get('enabled')}; \
		import subprocess; \
		[subprocess.run(['docker', 'exec', '-it', f'{name}-validator', '/scripts/backup-keys.sh'], check=False) \
		for name in chains.keys() if subprocess.run(['docker', 'ps', '--format', '{{.Names}}'], \
		capture_output=True, text=True).stdout.find(f'{name}-validator') >= 0]"
	@echo ""
	@echo "Don't forget to copy backup files from containers using: make backup-keys <chain>"

backup-copy:
	@echo "⚠️  This command is deprecated. Use 'make backup-keys <chain>' for specific chain backups."
	@echo "Or use 'make backup-all' to backup all chains."

backup-full:
	@echo "Running full backup (create backup + copy to host)..."
	@$(MAKE) backup
	@$(MAKE) backup-copy

backup-list:
	@echo "Listing all backup and key files in containers:"
	@python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); \
		chains = {n: c for n, c in config.get('chains', {}).items() if c.get('enabled')}; \
		import subprocess; \
		[print(f'\n{name}:') or subprocess.run(['docker', 'exec', f'{name}-validator', 'find', \
		cfg['daemon_home'], '-name', '*validator*', '-o', '-name', '*backup*', '-type', 'f'], check=False) \
		for name, cfg in chains.items() if subprocess.run(['docker', 'ps', '--format', '{{.Names}}'], \
		capture_output=True, text=True).stdout.find(f'{name}-validator') >= 0]"

shell:
	@echo "⚠️  This command is deprecated. Use 'make shell-chain <chain>' for specific chain shell access."

ps:
	@echo "Container status:"
	docker-compose ps

stats:
	@echo "Container resource usage:"
	docker stats --no-stream

clean:
	@echo "WARNING: This will remove all containers and volumes!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		echo "All containers and volumes removed."; \
	else \
		echo "Cancelled."; \
	fi

# Validator operations (deprecated - use chain-specific commands)
start-validator:
	@echo "⚠️  This command is deprecated. Use 'make create-validator <chain>' instead."

create-validator:
	@echo "⚠️  This command is deprecated. Use 'make create-validator <chain>' instead."

setup-keys:
	@echo "⚠️  This command is deprecated. Use 'make import-keys <chain>' instead."

keys-list:
	@echo "⚠️  This command is deprecated. Use chain-specific commands instead."

keys-show:
	@echo "⚠️  This command is deprecated. Use 'make show-address <chain>' instead."

keys-add:
	@echo "⚠️  This command is deprecated. Use 'make create-keys <chain>' instead."

keys-recover:
	@echo "⚠️  This command is deprecated. Use 'make import-keys <chain>' instead."

validator-address:
	@echo "⚠️  This command is deprecated. Use 'make show-address <chain>' instead."

# Monitoring
grafana-url:
	@echo "Grafana URL: http://$$(curl -s ifconfig.me):3000"
	@echo "Default credentials: admin / (check config.yml)"

prometheus-url:
	@echo "Prometheus URL: http://$$(curl -s ifconfig.me):9090"

alertmanager-url:
	@echo "Alertmanager URL: http://$$(curl -s ifconfig.me):9093"

# Maintenance
apply-snapshot:
	@echo "⚠️  This command is deprecated. Use 'make apply-snapshot CHAIN=<chain> SNAPSHOT_URL=<url>' instead."

init-fresh:
	@echo "⚠️  This command is deprecated. Use 'make clean-chain <chain>' to remove chain data."

prune-docker:
	@echo "Pruning unused Docker resources..."
	docker system prune -f
	@echo "Docker cleanup complete."

update-peers:
	@echo "⚠️  This command is deprecated. Peer lists should be configured in chains.yaml"
	@echo "For Cosmos Hub, visit: https://cosmos.directory/cosmoshub/nodes"

check-upgrades:
	@echo "Checking for pending upgrades..."
	@make list-upgrades

version:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make version <chain>"; \
		echo "Example: make version cosmos"; \
		exit 1; \
	fi
	@echo "$(CHAIN) version:"
	@docker exec $(CHAIN)-validator bash -c '$$DAEMON_NAME version'

cosmovisor-version:
	@echo "Cosmovisor version:"
	@docker exec $$(docker ps --format '{{.Names}}' | grep validator | head -1) cosmovisor version 2>/dev/null || echo "No validator containers running"

# Query commands (deprecated - use chain-specific commands)
query-balance:
	@echo "⚠️  This command is deprecated. Use 'make query-balance <chain>' instead."

query-validator:
	@echo "⚠️  This command is deprecated. Use 'make query-validator <chain>' instead."

query-delegations:
	@echo "⚠️  This command is deprecated. Use 'make query-delegations <chain>' instead."

# Multi-chain management commands
generate:
	@echo "Generating docker-compose.yml and prometheus.yml from chains.yaml..."
	python3 generate-compose.py
	@echo "✓ Configuration generated successfully!"

list-chains:
	@echo "Configured chains in chains.yaml:"
	@echo "================================="
	@python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); \
	chains = config.get('chains', {}); \
	[print(f\"  {'✓' if cfg.get('enabled') else '✗'} {name:15} - {cfg.get('chain_id', 'N/A'):20} ({'enabled' if cfg.get('enabled') else 'disabled'})\") \
	for name, cfg in chains.items()]"

start-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make start-chain <chain>"; \
		echo "Example: make start-chain osmosis"; \
		exit 1; \
	fi
	@echo "Starting $(CHAIN) validator..."
	@docker-compose up -d $(CHAIN)-validator
	@echo "✓ $(CHAIN) validator started"

stop-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make stop-chain <chain>"; \
		exit 1; \
	fi
	@echo "Stopping $(CHAIN) validator..."
	@docker-compose stop $(CHAIN)-validator
	@echo "✓ $(CHAIN) validator stopped"

restart-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make restart-chain <chain>"; \
		exit 1; \
	fi
	@echo "Restarting $(CHAIN) validator..."
	@docker-compose restart $(CHAIN)-validator
	@echo "✓ $(CHAIN) validator restarted"

logs-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make logs-chain <chain>"; \
		exit 1; \
	fi
	@echo "Viewing logs for $(CHAIN) validator (Ctrl+C to exit)..."
	@docker-compose logs -f $(CHAIN)-validator

status-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make status-chain <chain>"; \
		exit 1; \
	fi
	@echo "Checking $(CHAIN) validator status..."
	@docker exec $(CHAIN)-validator /scripts/check-status.sh

shell-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make shell-chain <chain>"; \
		exit 1; \
	fi
	@echo "Entering $(CHAIN) validator shell..."
	@docker exec -it $(CHAIN)-validator /bin/bash

# Upgrade management
prepare-upgrade:
	@if [ -z "$(CHAIN)" ] || [ -z "$(UPGRADE_NAME)" ] || [ -z "$(BINARY_URL)" ]; then \
		echo "Error: Required parameters missing"; \
		echo "Usage: make prepare-upgrade CHAIN=cosmos UPGRADE_NAME=v26 BINARY_URL=https://..."; \
		exit 1; \
	fi
	@echo "Preparing upgrade $(UPGRADE_NAME) for $(CHAIN)..."
	docker exec $(CHAIN)-validator /scripts/prepare-upgrade.sh $(UPGRADE_NAME) $(BINARY_URL) $(UPGRADE_HEIGHT)

list-upgrades:
	@echo "Fetching pending upgrades from Polkachu API..."
	@curl -s https://polkachu.com/api/v2/chain_upgrades | jq -r '.[] | "\(.network) - \(.node_version) at block \(.block) (~\(.estimated_upgrade_time))"'

check-upgrade:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make check-upgrade <chain>"; \
		exit 1; \
	fi
	@echo "Checking upgrade status for $(CHAIN)..."
	@docker exec $(CHAIN)-validator ls -la /root/.*/cosmovisor/upgrades/ 2>/dev/null || echo "No upgrades prepared yet"

# Setup and configuration
setup:
	@echo "Setting up multi-chain validator environment..."
	@mkdir -p secrets
	@mkdir -p validator-backup
	@if [ ! -f config.yml ]; then \
		echo "⚠️  Warning: config.yml not found. Create it from the example in README.md"; \
	fi
	@echo "✓ Created secrets directory"
	@echo "✓ Created validator-backup directory"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Create config.yml with your global settings (see README.md)"
	@echo "  2. Edit chains.yaml to enable desired chains"
	@echo "  3. Create mnemonic files in secrets/ directory"
	@echo "  4. Run: make generate"
	@echo "  5. Run: make start"

validate-config:
	@echo "Validating chains.yaml..."
	@python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); print('✓ chains.yaml is valid')" || \
		(echo "✗ chains.yaml has syntax errors"; exit 1)

# Key management for specific chains
create-mnemonic:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make create-mnemonic <chain>"; \
		echo "Example: make create-mnemonic osmosis"; \
		exit 1; \
	fi
	@mkdir -p secrets
	@if [ -f secrets/$(CHAIN)-mnemonic.txt ]; then \
		echo "⚠️  Warning: secrets/$(CHAIN)-mnemonic.txt already exists"; \
		read -p "Overwrite? [y/N] " -n 1 -r; \
		echo; \
		if [[ ! $$REPLY =~ ^[Yy]$$ ]]; then \
			echo "Cancelled."; \
			exit 0; \
		fi; \
	fi
	@echo "Enter mnemonic phrase for $(CHAIN) (press Enter after each word, or paste all at once):"
	@read -r MNEMONIC; \
	if [ -z "$$MNEMONIC" ]; then \
		echo "Error: Empty mnemonic. Cancelled."; \
		exit 1; \
	fi; \
	echo "$$MNEMONIC" > secrets/$(CHAIN)-mnemonic.txt; \
	chmod 600 secrets/$(CHAIN)-mnemonic.txt; \
	echo "✓ Mnemonic saved to secrets/$(CHAIN)-mnemonic.txt"

create-keys:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make create-keys <chain>"; \
		exit 1; \
	fi
	@echo "Creating new keys for $(CHAIN)..."
	@docker exec -it $(CHAIN)-validator bash -c '\
		$$DAEMON_NAME keys add validator --keyring-backend test --home $$DAEMON_HOME'

import-keys:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make import-keys <chain>"; \
		exit 1; \
	fi
	@echo "Importing keys for $(CHAIN) from mnemonic..."
	@if [ ! -f secrets/$(CHAIN)-mnemonic.txt ]; then \
		echo "Error: secrets/$(CHAIN)-mnemonic.txt not found"; \
		exit 1; \
	fi
	@docker exec -it $(CHAIN)-validator /scripts/setup-keys.sh

show-address:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make show-address <chain>"; \
		exit 1; \
	fi
	@echo "Addresses for $(CHAIN):"
	@echo "====================="
	@docker exec $(CHAIN)-validator bash -c '\
		echo "Validator Address: $$($$DAEMON_NAME keys show validator -a --keyring-backend test --home $$DAEMON_HOME 2>/dev/null)"; \
		echo "Operator Address:  $$($$DAEMON_NAME keys show validator --bech val -a --keyring-backend test --home $$DAEMON_HOME 2>/dev/null)"'

backup-keys:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make backup-keys <chain>"; \
		exit 1; \
	fi
	@echo "Backing up keys for $(CHAIN)..."
	@docker exec -it $(CHAIN)-validator /scripts/backup-keys.sh
	@mkdir -p ./validator-backup/$(CHAIN)
	@DAEMON_HOME=$$(python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); print(config['chains']['$(CHAIN)']['daemon_home'])") && \
	docker cp $(CHAIN)-validator:$$DAEMON_HOME/backup/ ./validator-backup/$(CHAIN)/ 2>/dev/null || true
	@echo "✓ Backup saved to ./validator-backup/$(CHAIN)/"

backup-all:
	@echo "Backing up all chain keys..."
	@python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); \
		chains = {n: c for n, c in config.get('chains', {}).items() if c.get('enabled')}; \
		import subprocess; \
		[subprocess.run(['docker', 'exec', f'{name}-validator', '/scripts/backup-keys.sh'], check=False) or \
		subprocess.run(['mkdir', '-p', f'./validator-backup/{name}'], check=False) or \
		subprocess.run(['docker', 'cp', f'{name}-validator:{cfg[\"daemon_home\"]}/backup/', \
		f'./validator-backup/{name}/'], check=False, stderr=subprocess.DEVNULL) \
		for name, cfg in chains.items() \
		if subprocess.run(['docker', 'ps', '--format', '{{.Names}}'], \
		capture_output=True, text=True).stdout.find(f'{name}-validator') >= 0]"
	@echo "✓ All backups complete in ./validator-backup/"

list-backups:
	@echo "Available backups:"
	@echo "=================="
	@find ./validator-backup -name "*.tar.gz" -o -name "*.json" 2>/dev/null | sort

# Validator operations for specific chains
create-validator:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make create-validator <chain>"; \
		exit 1; \
	fi
	@echo "Creating validator for $(CHAIN)..."
	@docker exec -it $(CHAIN)-validator /scripts/start-validator.sh

query-balance:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make query-balance <chain>"; \
		exit 1; \
	fi
	@echo "Querying balance for $(CHAIN)..."
	@docker exec $(CHAIN)-validator bash -c '\
		ADDR=$$($$DAEMON_NAME keys show validator -a --keyring-backend test --home $$DAEMON_HOME 2>/dev/null); \
		if [ -z "$$ADDR" ]; then \
			echo "No validator key found"; \
			exit 1; \
		fi; \
		$$DAEMON_NAME query bank balances $$ADDR --node http://localhost:$$RPC_PORT'

query-validator:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make query-validator <chain>"; \
		exit 1; \
	fi
	@echo "Querying validator info for $(CHAIN)..."
	@docker exec $(CHAIN)-validator bash -c '\
		VALOPER=$$($$DAEMON_NAME keys show validator --bech val -a --keyring-backend test --home $$DAEMON_HOME 2>/dev/null); \
		if [ -z "$$VALOPER" ]; then \
			echo "No validator key found"; \
			exit 1; \
		fi; \
		$$DAEMON_NAME query staking validator $$VALOPER --node http://localhost:$$RPC_PORT'

query-delegations:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make query-delegations <chain>"; \
		exit 1; \
	fi
	@echo "Querying delegations for $(CHAIN)..."
	@docker exec $(CHAIN)-validator bash -c '\
		VALOPER=$$($$DAEMON_NAME keys show validator --bech val -a --keyring-backend test --home $$DAEMON_HOME 2>/dev/null); \
		if [ -z "$$VALOPER" ]; then \
			echo "No validator key found"; \
			exit 1; \
		fi; \
		$$DAEMON_NAME query staking delegations-to $$VALOPER --node http://localhost:$$RPC_PORT'

# Chain initialization
init-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make init-chain <chain>"; \
		exit 1; \
	fi
	@echo "Initializing $(CHAIN)..."
	@docker exec $(CHAIN)-validator /scripts/init-node.sh

# Snapshot operations
apply-snapshot:
	@if [ -z "$(CHAIN)" ] || [ -z "$(SNAPSHOT_URL)" ]; then \
		echo "Error: Required parameters missing"; \
		echo "Usage: make apply-snapshot CHAIN=cosmos SNAPSHOT_URL=https://..."; \
		exit 1; \
	fi
	@echo "Applying snapshot for $(CHAIN)..."
	@DAEMON_HOME=$$(python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); print(config['chains']['$(CHAIN)']['daemon_home'])") && \
	DAEMON_NAME=$$(python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); print(config['chains']['$(CHAIN)']['binary_name'])") && \
	echo "Stopping $(CHAIN) validator..." && \
	docker-compose stop $(CHAIN)-validator && \
	echo "Applying snapshot..." && \
	docker run --rm \
		-v $$(docker volume ls -q | grep $(CHAIN)-data):$$DAEMON_HOME \
		-v $$(pwd)/scripts:/scripts:ro \
		-e DAEMON_HOME=$$DAEMON_HOME \
		-e DAEMON_NAME=$$DAEMON_NAME \
		-e SNAPSHOT_URL=$(SNAPSHOT_URL) \
		--entrypoint /bin/bash \
		$(CHAIN)-validator \
		-c "apt-get update && apt-get install -y wget lz4 && /scripts/apply-snapshot.sh" && \
	echo "Restarting $(CHAIN) validator..." && \
	docker-compose start $(CHAIN)-validator && \
	echo "✓ Snapshot applied successfully"

list-snapshots:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make list-snapshots <chain>"; \
		exit 1; \
	fi
	@echo "Available snapshots for $(CHAIN) from Polkachu:"
	@echo "==============================================="
	@curl -s https://polkachu.com/api/v2/chains | jq -r '.[] | select(.name == "$(CHAIN)") | "Latest: \(.snapshot_url)"'
	@echo ""
	@echo "Visit: https://polkachu.com/tendermint_snapshots/$(CHAIN)"

# Monitoring URLs
urls:
	@echo "Monitoring Service URLs"
	@echo "======================="
	@echo "Grafana:      http://$$(curl -s ifconfig.me 2>/dev/null || echo 'localhost'):3001"
	@echo "Prometheus:   http://$$(curl -s ifconfig.me 2>/dev/null || echo 'localhost'):9091"
	@echo "Alertmanager: http://$$(curl -s ifconfig.me 2>/dev/null || echo 'localhost'):9093"
	@echo ""
	@echo "Chain RPC Endpoints:"
	@echo "===================="
	@python3 -c "import yaml; \
		config = yaml.safe_load(open('chains.yaml')); \
		chains = {n: c for n, c in config.get('chains', {}).items() if c.get('enabled')}; \
		[print(f\"{name:15} http://localhost:{cfg['ports']['rpc']}\") for name, cfg in chains.items()]" 2>/dev/null || echo "Run 'make generate' first"

open-grafana:
	@echo "Opening Grafana in browser..."
	@open http://localhost:3001 2>/dev/null || xdg-open http://localhost:3001 2>/dev/null || echo "Please open http://localhost:3001 manually"

# Monitoring shortcuts  
watch-status:
	@watch -n 5 'make status 2>/dev/null'

watch-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make watch-chain <chain>"; \
		exit 1; \
	fi
	@watch -n 5 'docker exec $(CHAIN)-validator /scripts/check-status.sh 2>/dev/null'

# Docker management
rebuild:
	@echo "Rebuilding all containers..."
	@docker-compose build --no-cache

rebuild-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make rebuild-chain <chain>"; \
		exit 1; \
	fi
	@echo "Rebuilding $(CHAIN) container..."
	@docker-compose build --no-cache $(CHAIN)-validator

clean-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make clean-chain <chain>"; \
		exit 1; \
	fi
	@echo "⚠️  WARNING: This will remove $(CHAIN) container and volume!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose rm -sf $(CHAIN)-validator; \
		docker volume rm $$(docker volume ls -q | grep $(CHAIN)-data) 2>/dev/null || true; \
		echo "$(CHAIN) validator removed"; \
	else \
		echo "Cancelled"; \
	fi

# Quick diagnostics
diagnose:
	@echo "System Diagnostics"
	@echo "=================="
	@echo ""
	@echo "Docker Status:"
	@docker --version
	@docker-compose --version
	@echo ""
	@echo "Running Containers:"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "Disk Usage:"
	@df -h | grep -E "Filesystem|/$$"
	@echo ""
	@echo "Docker Volumes:"
	@docker volume ls | grep -E "DRIVER|validator|data"
	@echo ""
	@echo "Port Usage:"
	@python3 -c "import yaml; config = yaml.safe_load(open('chains.yaml')); \
		chains = {n: c for n, c in config.get('chains', {}).items() if c.get('enabled')}; \
		ports = [str(cfg['ports']['p2p']) for cfg in chains.values()] + \
		[str(cfg['ports']['rpc']) for cfg in chains.values()] + ['3001', '9091']; \
		port_pattern = '|'.join(ports); \
		import subprocess; \
		result = subprocess.run(['netstat', '-tulpn'], capture_output=True, text=True, check=False); \
		if result.returncode == 0: \
			import re; \
			matches = [line for line in result.stdout.split('\n') if re.search(port_pattern, line)]; \
			[print(m) for m in matches] if matches else print('No matching ports found'); \
		else: \
			print('netstat not available')"

# Quick enable/disable chains
enable-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make enable-chain <chain>"; \
		exit 1; \
	fi
	@echo "Enabling $(CHAIN) in chains.yaml..."
	@python3 -c "import yaml; \
		config = yaml.safe_load(open('chains.yaml')); \
		if '$(CHAIN)' not in config.get('chains', {}): \
			print('Error: Chain $(CHAIN) not found in chains.yaml'); \
			exit(1); \
		config['chains']['$(CHAIN)']['enabled'] = True; \
		yaml.dump(config, open('chains.yaml', 'w'), default_flow_style=False, sort_keys=False)"
	@echo "✓ $(CHAIN) enabled. Run 'make generate' to update configuration"

disable-chain:
	@$(eval CHAIN := $(filter-out $@,$(MAKECMDGOALS)))
	@if [ -z "$(CHAIN)" ]; then \
		echo "Usage: make disable-chain <chain>"; \
		exit 1; \
	fi
	@echo "Disabling $(CHAIN) in chains.yaml..."
	@python3 -c "import yaml; \
		config = yaml.safe_load(open('chains.yaml')); \
		if '$(CHAIN)' not in config.get('chains', {}): \
			print('Error: Chain $(CHAIN) not found in chains.yaml'); \
			exit(1); \
		config['chains']['$(CHAIN)']['enabled'] = False; \
		yaml.dump(config, open('chains.yaml', 'w'), default_flow_style=False, sort_keys=False)"
	@echo "✓ $(CHAIN) disabled. Run 'make generate' to update configuration"

# Catch-all target to allow chain names as arguments
# This makes "make start-chain osmosis" work instead of requiring CHAIN=osmosis
%:
	@:


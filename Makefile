.PHONY: help start stop restart logs status backup clean build

help:
	@echo "Cosmos Hub Validator - Available Commands"
	@echo "=========================================="
	@echo ""
	@echo "🚀 Quick Start:"
	@echo "  make start              - Start all services"
	@echo "  make start-validator    - Auto-create validator (checks sync, balance, etc)"
	@echo "  make status             - Check validator status"
	@echo ""
	@echo "📦 Container Management:"
	@echo "  make stop               - Stop all services"
	@echo "  make restart            - Restart all services"
	@echo "  make build              - Build containers"
	@echo "  make ps                 - Show container status"
	@echo "  make stats              - Show container resource usage"
	@echo "  make shell              - Enter validator container shell"
	@echo ""
	@echo "📊 Monitoring & Logs:"
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
	@echo "  make validator-address  - Show validator addresses"
	@echo "  make backup             - Backup validator keys"
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
	@echo "Starting Cosmos Hub validator..."
	docker-compose up -d
	@echo "Validator started. Use 'make logs' to view logs."

stop:
	@echo "Stopping Cosmos Hub validator..."
	docker-compose down
	@echo "Validator stopped."

restart:
	@echo "Restarting Cosmos Hub validator..."
	docker-compose restart
	@echo "Validator restarted."

build:
	@echo "Building containers..."
	docker-compose build --no-cache

logs:
	@echo "Viewing all logs (Ctrl+C to exit)..."
	docker-compose logs -f

logs-node:
	@echo "Viewing validator node logs (Ctrl+C to exit)..."
	docker-compose logs -f cosmos-node

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
	@echo "Checking validator status..."
	docker exec cosmos-validator /scripts/check-status.sh

sync-status:
	@echo "Checking sync status..."
	@docker exec cosmos-validator curl -s http://localhost:26657/status | jq -r '.result.sync_info | "Catching Up: \(.catching_up)\nLatest Block: \(.latest_block_height)\nLatest Block Time: \(.latest_block_time)"'

backup:
	@echo "Backing up validator keys..."
	docker exec -it cosmos-validator /scripts/backup-keys.sh
	@echo ""
	@echo "Don't forget to copy the backup file from the container:"
	@echo "docker cp cosmos-validator:/root/.gaia/backup/ ./"

shell:
	@echo "Entering validator container shell..."
	docker exec -it cosmos-validator /bin/bash

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

# Validator operations
start-validator:
	@echo "🚀 Starting automated validator creation..."
	@echo ""
	docker exec -it cosmos-validator /scripts/start-validator.sh

create-validator:
	@echo "Creating validator (manual)..."
	docker exec -it cosmos-validator /scripts/create-validator.sh

setup-keys:
	@echo "Setting up validator keys..."
	docker exec -it cosmos-validator /scripts/setup-keys.sh

keys-list:
	@echo "Listing keys..."
	docker exec cosmos-validator gaiad keys list --keyring-backend test

keys-show:
	@echo "Showing validator key..."
	docker exec cosmos-validator gaiad keys show validator -a --keyring-backend test

keys-add:
	@echo "Creating new validator key..."
	docker exec -it cosmos-validator gaiad keys add validator --keyring-backend test

keys-recover:
	@echo "Recovering validator key from mnemonic..."
	docker exec -it cosmos-validator gaiad keys add validator --recover --keyring-backend test

validator-address:
	@echo "Validator address:"
	@docker exec cosmos-validator gaiad keys show validator -a --keyring-backend test
	@echo ""
	@echo "Validator operator address:"
	@docker exec cosmos-validator gaiad keys show validator --bech val -a --keyring-backend test

# Monitoring
grafana-url:
	@echo "Grafana URL: http://$$(curl -s ifconfig.me):3000"
	@echo "Default credentials: admin / (check .env file)"

prometheus-url:
	@echo "Prometheus URL: http://$$(curl -s ifconfig.me):9090"

alertmanager-url:
	@echo "Alertmanager URL: http://$$(curl -s ifconfig.me):9093"

# Maintenance
apply-snapshot:
	@echo "⚠️  This will apply a blockchain snapshot"
	@echo "You need to provide the snapshot URL when prompted"
	@echo ""
	@read -p "Enter snapshot URL: " SNAPSHOT_URL; \
	if [ -z "$$SNAPSHOT_URL" ]; then \
		echo "No URL provided. Cancelled."; \
		exit 1; \
	fi; \
	echo ""; \
	echo "Stopping services..."; \
	docker-compose down; \
	echo "Applying snapshot..."; \
	docker run --rm \
		-v cosmos-validator_cosmos-data:/root/.gaia \
		-v "$$(pwd)/scripts:/scripts:ro" \
		--entrypoint /bin/bash \
		cosmos-validator-cosmos-node \
		-c "apt-get update -qq && apt-get install -y -qq wget lz4 > /dev/null 2>&1 && bash /scripts/apply-snapshot.sh $$SNAPSHOT_URL"; \
	echo ""; \
	echo "Starting services..."; \
	docker-compose up -d; \
	echo "Done! Monitor with: make logs-node"

init-fresh:
	@echo "⚠️  This will start with a completely fresh blockchain state"
	@echo "Current data will be removed!"
	@echo ""
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down; \
		docker volume rm cosmos-validator_cosmos-data; \
		docker-compose up -d; \
		echo "Started fresh. The node will sync from the network."; \
		echo "This may take several hours. Monitor with: make logs-node"; \
	else \
		echo "Cancelled."; \
	fi

prune-docker:
	@echo "Pruning unused Docker resources..."
	docker system prune -f
	@echo "Docker cleanup complete."

update-peers:
	@echo "Fetching fresh peer list..."
	@curl -s https://cosmos.directory/cosmoshub/nodes | jq -r '.nodes[] | select(.type == "peer") | "\(.moniker)@\(.address)"' | head -10

check-upgrades:
	@echo "Checking for pending upgrades..."
	@curl -s https://cosmos.directory/cosmoshub/chain | jq -r '.current_upgrade // "No pending upgrades"'

version:
	@echo "Gaiad version:"
	@docker exec cosmos-validator gaiad version

cosmovisor-version:
	@echo "Cosmovisor version:"
	@docker exec cosmos-validator cosmovisor version

# Query commands
query-balance:
	@echo "Querying validator balance..."
	@ADDR=$$(docker exec cosmos-validator gaiad keys show validator -a --keyring-backend test 2>/dev/null); \
	if [ -z "$$ADDR" ]; then \
		echo "No validator key found"; \
		exit 1; \
	fi; \
	docker exec cosmos-validator gaiad query bank balances $$ADDR --node http://localhost:26657

query-validator:
	@echo "Querying validator info..."
	@VALOPER=$$(docker exec cosmos-validator gaiad keys show validator --bech val -a --keyring-backend test 2>/dev/null); \
	if [ -z "$$VALOPER" ]; then \
		echo "No validator key found"; \
		exit 1; \
	fi; \
	docker exec cosmos-validator gaiad query staking validator $$VALOPER --node http://localhost:26657

query-delegations:
	@echo "Querying validator delegations..."
	@VALOPER=$$(docker exec cosmos-validator gaiad keys show validator --bech val -a --keyring-backend test 2>/dev/null); \
	if [ -z "$$VALOPER" ]; then \
		echo "No validator key found"; \
		exit 1; \
	fi; \
	docker exec cosmos-validator gaiad query staking delegations-to $$VALOPER --node http://localhost:26657


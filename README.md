# Multi-Chain Cosmos Validator

Production-ready multi-chain Cosmos validator deployment with monitoring, alerting, and automatic upgrades.

## Features

- **Multi-Chain Support**: Run validators for multiple Cosmos chains simultaneously
- **Dockerized**: Single `make start` deployment
- **Auto-Upgrades**: Cosmovisor + Polkachu API integration
- **Monitoring**: Prometheus + Grafana dashboards for all chains
- **Alerting**: Slack notifications for critical events
- **Centralized Config**: Manage all chains from `chains.yaml`

## Quick Start: Adding a New Chain

### Step 1: Configure Chain in `chains.yaml`

Edit `chains.yaml` and ensure your chain is configured with `enabled: true`. Example:

```yaml
chains:
  osmosis:
    enabled: true
    chain_id: "osmosis-1"
    # ... other settings
```

### Step 2: Create Mnemonic File

```bash
make create-mnemonic osmosis
```

This will prompt you to enter your mnemonic phrase and save it securely.

### Step 3: Generate Configuration

```bash
make generate
```

Generates `docker-compose.yml` and `prometheus.yml` from `chains.yaml`.

### Step 4: Start the Chain

```bash
make start-chain osmosis
```

### Step 5: Monitor

```bash
# View logs
make logs-chain osmosis

# Check status
make status-chain osmosis
```

### Step 6: Fund and Create Validator

```bash
# Show validator address
make show-address osmosis

# Send tokens to the address, then create validator
make create-validator osmosis
```

## Prerequisites

- Docker & Docker Compose
- Python 3
- 4 CPU cores, 16GB RAM, 500GB SSD per chain
- Public IP with available ports

## Initial Setup (First Time)

```bash
# 1. Setup environment
make setup

# 2. Create config.yml with global settings
# Copy the example from config.yml (if it exists) or create from scratch
# Set Grafana password, Slack webhook, etc.

# 3. Configure chains.yaml
nano chains.yaml  # Enable desired chains

# 4. Create mnemonics for each chain
make create-mnemonic cosmos
make create-mnemonic osmosis

# 5. Generate configuration
make generate

# 6. Start all enabled chains
make start

# 7. Check status
make status
```

## All Make Commands

### Setup & Configuration

```bash
make setup              # First-time environment setup
make generate           # Generate docker-compose.yml from chains.yaml
make list-chains        # List all configured chains
make validate-config    # Validate chains.yaml syntax
make enable-chain <chain>   # Enable chain in chains.yaml
make disable-chain <chain>  # Disable chain in chains.yaml
```

### Chain Management

```bash
make start              # Start all enabled services
make stop               # Stop all services
make restart            # Restart all services
make start-chain <chain>    # Start specific chain
make stop-chain <chain>     # Stop specific chain
make restart-chain <chain>  # Restart specific chain
make logs-chain <chain>      # View chain logs
make status-chain <chain>    # Check chain status
make shell-chain <chain>     # Enter chain container
make init-chain <chain>      # Initialize chain
```

### Key Management

```bash
make create-mnemonic <chain>  # Create mnemonic file for chain
make create-keys <chain>      # Create new keys for chain
make import-keys <chain>      # Import keys from mnemonic
make show-address <chain>     # Show validator address
make backup-keys <chain>      # Backup keys for specific chain
make backup-all               # Backup all chain keys
```

### Validator Operations

```bash
make create-validator <chain>  # Create validator for chain
make query-balance <chain>     # Query balance
make query-validator <chain>   # Query validator info
make query-delegations <chain> # Query delegations
```

### Monitoring & Logs

```bash
make logs               # View all logs
make logs-node          # View validator node logs
make logs-prom          # View Prometheus logs
make logs-grafana      # View Grafana logs
make logs-alert        # View Alertmanager logs
make status            # Check all validators status
make watch-status      # Watch all chain statuses (auto-refresh)
make watch-chain <chain> # Watch specific chain status
make urls              # Show all monitoring URLs
make open-grafana      # Open Grafana in browser
```

### Upgrade Management

```bash
make list-upgrades          # List pending upgrades from Polkachu
make check-upgrade <chain>  # Check upgrade status for chain
make prepare-upgrade CHAIN=<chain> UPGRADE_NAME=<name> BINARY_URL=<url>
```

### Snapshots

```bash
make list-snapshots <chain>  # List available snapshots
make apply-snapshot CHAIN=<chain> SNAPSHOT_URL=<url>
```

### Maintenance

```bash
make diagnose          # Run system diagnostics
make ps               # Show container status
make stats            # Show container resource usage
make prune-docker     # Prune unused Docker resources
make rebuild          # Rebuild all containers
make rebuild-chain <chain>  # Rebuild specific chain
make clean-chain <chain>   # Remove chain container and volume
make clean            # Remove all containers and volumes (DANGER!)
```

### Help

```bash
make help             # Show all available commands
```

## Monitoring URLs

After starting, access monitoring at:

- **Grafana**: http://YOUR_IP:3001 (default: admin / check config.yml)
- **Prometheus**: http://YOUR_IP:9091
- **Alertmanager**: http://YOUR_IP:9093

Use `make urls` to see all URLs with your IP.

## Configuration Files

- **`chains.yaml`** - Chain-specific configuration (binary URLs, ports, network settings)
- **`config.yml`** - Global settings and per-chain validator overrides
- **`secrets/<chain>-mnemonic.txt`** - Chain mnemonics (gitignored)

## Chains.yaml Configuration Reference

The `chains.yaml` file defines all chain configurations. Each chain entry contains the following fields:

### Basic Information

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `enabled` | boolean | Yes | Whether to run this validator | `true` |
| `chain_id` | string | Yes | Official chain ID from the network | `"cosmoshub-4"` |
| `chain_name` | string | Yes | Display name for the chain | `"Cosmos Hub"` |
| `network` | string | Yes | Network identifier (must match Polkachu API) | `"cosmos"` |

### Binary Configuration

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `binary_name` | string | Yes | Daemon executable name | `"gaiad"` |
| `binary_version` | string | Yes | Current binary version | `"v25.1.0"` |
| `binary_url` | string | Yes | Download URL for pre-built binary | `"https://github.com/cosmos/gaia/releases/download/v25.1.0/gaiad-v25.1.0-linux-amd64"` |
| `daemon_home` | string | Yes | Home directory for chain data | `"/root/.gaia"` |

### Port Configuration

**Important**: Each chain must use unique ports to avoid conflicts.

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `ports.p2p` | integer | Yes | P2P communication port | `26656` |
| `ports.rpc` | integer | Yes | RPC server port | `26657` |
| `ports.rest_api` | integer | Yes | REST API port | `1317` |
| `ports.grpc` | integer | Yes | gRPC server port | `9090` |
| `ports.prometheus` | integer | Yes | Prometheus metrics port | `26660` |

**Port Allocation Guidelines**: Use consistent offsets per chain:
- Cosmos: +0 (26656, 26657, 1317, 9090, 26660)
- Osmosis: +100 (26756, 26757, 1417, 9190, 26760)
- Juno: +200 (26856, 26857, 1517, 9290, 26860)

### Network Configuration

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `genesis_url` | string | Yes | URL to download genesis.json | `"https://snapshots.polkachu.com/genesis/cosmos/genesis.json"` |
| `snapshot_url` | string | No | URL for blockchain snapshot (for fast sync) | `"https://snapshots.polkachu.com/snapshots/cosmos/cosmos_28294157.tar.lz4"` |
| `snapshot_wasm_url` | string | No | URL for WASM data (for CosmWasm chains) | `"https://snapshots.polkachu.com/wasm/cosmos/cosmos_wasmonly.tar.lz4"` |
| `persistent_peers` | string | Yes | Comma-separated list of peer addresses | `"peer1@ip:port,peer2@ip:port"` |
| `state_sync_rpc` | array | Yes | List of RPC endpoints for state-sync | `["https://rpc.example.com:443"]` |

### Chain-Specific Settings

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `min_gas_price` | string | Yes | Minimum gas price with denom | `"0.005uatom"` |
| `denom` | string | Yes | Base denomination (smallest unit) | `"uatom"` |
| `denom_display` | string | Yes | Display denomination (human-readable) | `"ATOM"` |
| `decimals` | integer | Yes | Decimal places for the token | `6` |
| `block_time_seconds` | integer | No | Average block time in seconds (for upgrade calculations) | `6` |
| `block_explorer_url` | string | No | Block explorer URL template with `{address}` placeholder | `"https://www.mintscan.io/cosmos/validators/{address}"` |
| `min_self_delegation` | string | No | Minimum self-delegation amount (in base denom) | `"1000000"` |

### Validator Configuration (Optional)

Optional per-chain validator overrides. If not specified, uses defaults from `config.yml`. Only specify fields you want to override.

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `validator.moniker` | string | No | Validator moniker (node name) | `"cosmos-validator"` |
| `validator.name` | string | No | Validator display name | `"My Cosmos Validator"` |
| `validator.website` | string | No | Validator website URL | `"https://example.com"` |
| `validator.identity` | string | No | Keybase identity (for validator logo) | `"ABC123DEF456"` |
| `validator.details` | string | No | Validator description | `"A reliable Cosmos Hub validator"` |
| `validator.security_contact` | string | No | Security contact email | `"security@example.com"` |
| `validator.commission_rate` | float | No | Initial commission rate (as decimal) | `0.20` (20%) |
| `validator.commission_max_rate` | float | No | Maximum commission rate (as decimal) | `0.20` (20%) |
| `validator.commission_max_change_rate` | float | No | Max daily commission change (as decimal) | `0.01` (1%) |
| `validator.external_ip` | string | No | External IP address | `"1.2.3.4"` |

**Priority**: `chains.yaml` validator settings > `config.yml` defaults

**Example**: To set a 20% commission for Osmosis while keeping all other defaults:
```yaml
osmosis:
  # ... other chain config ...
  validator:
    commission_rate: 0.20  # Only this field overrides config.yml
```

### Pruning Configuration

Controls how much blockchain history to keep. More aggressive pruning saves disk space but reduces query capabilities.

| Field | Type | Required | Description | Values |
|-------|------|----------|-------------|--------|
| `pruning` | string | Yes | Pruning strategy | `"default"`, `"custom"`, `"nothing"`, `"everything"` |
| `pruning_keep_recent` | string | Conditional | Blocks to keep (if custom) | `"100"` |
| `pruning_keep_every` | string | Conditional | Snapshot interval (if custom) | `"0"` |
| `pruning_interval` | string | Conditional | Pruning interval in blocks (if custom) | `"10"` |

### Cosmovisor Settings

Cosmovisor handles automatic chain upgrades.

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `cosmovisor_enabled` | boolean | Yes | Use Cosmovisor for upgrades | `true` |
| `auto_download_binaries` | boolean | Yes | Auto-download upgrade binaries | `true` |
| `restart_after_upgrade` | boolean | Yes | Auto-restart after upgrade | `true` |

### Repository

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `repo` | string | Yes | GitHub repository URL (for upgrade monitoring) | `"https://github.com/cosmos/gaia"` |

## Config.yml Configuration Reference

The `config.yml` file contains global settings and default validator configuration. These defaults can be overridden per-chain in `chains.yaml`.

### Monitoring Configuration

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `monitoring.prometheus_retention` | string | No | Prometheus data retention period | `"15d"` |
| `monitoring.grafana_admin_password` | string | No | Grafana admin password | `"admin_change_me_now"` |

### Alerting Configuration

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `alerting.slack_webhook_url` | string | No | Slack webhook URL for alerts | `""` |
| `alerting.alert_on_upgrade` | boolean | No | Send alerts for chain upgrades | `true` |
| `alerting.alert_on_sync_issues` | boolean | No | Send alerts for sync problems | `true` |
| `alerting.alert_on_missed_blocks` | boolean | No | Send alerts for missed blocks | `true` |

### Upgrade Monitoring

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `upgrade_monitoring.check_interval` | integer | No | How often to check for upgrades (seconds) | `300` |
| `upgrade_monitoring.preparation_hours` | integer | No | Hours before upgrade to prepare binaries | `48` |

### Backup Configuration

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `backup.enabled` | boolean | No | Enable automatic backups | `true` |
| `backup.schedule` | string | No | Cron schedule for backups | `"0 0 * * *"` |

### Default Validator Configuration

Default validator settings for all chains. These can be overridden per-chain in `chains.yaml`.

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `validator_defaults.moniker` | string | No | Validator moniker (node name) | `""` (uses `<chain>-validator` pattern) |
| `validator_defaults.external_ip` | string | No | External IP address | `""` |
| `validator_defaults.name` | string | No | Validator display name | `"My Validator"` |
| `validator_defaults.website` | string | No | Validator website URL | `"https://example.com"` |
| `validator_defaults.identity` | string | No | Keybase identity | `""` |
| `validator_defaults.details` | string | No | Validator description | `"A reliable Cosmos validator"` |
| `validator_defaults.security_contact` | string | No | Security contact email | `"security@example.com"` |
| `validator_defaults.commission_rate` | float | No | Initial commission rate | `0.10` (10%) |
| `validator_defaults.commission_max_rate` | float | No | Maximum commission rate | `0.20` (20%) |
| `validator_defaults.commission_max_change_rate` | float | No | Max daily commission change | `0.01` (1%) |

**Note**: To override validator settings for a specific chain, add a `validator:` section in `chains.yaml`. Only the fields you specify will override the defaults. For example:

```yaml
# In chains.yaml
osmosis:
  # ... other chain config ...
  validator:
    commission_rate: 0.20  # Only override commission, everything else uses config.yml defaults
```

### Example Chain Configuration

```yaml
chains:
  osmosis:
    enabled: true
    chain_id: "osmosis-1"
    chain_name: "Osmosis"
    network: "osmosis"
    
    binary_name: "osmosisd"
    binary_version: "v28.0.0"
    binary_url: "https://github.com/osmosis-labs/osmosis/releases/download/v28.0.0/osmosisd-28.0.0-linux-amd64"
    daemon_home: "/root/.osmosisd"
    
    ports:
      p2p: 26756
      rpc: 26757
      rest_api: 1417
      grpc: 9190
      prometheus: 26760
    
    genesis_url: "https://snapshots.polkachu.com/genesis/osmosis/genesis.json"
    snapshot_url: "https://snapshots.polkachu.com/snapshots/osmosis/osmosis_28311949.tar.lz4"
    snapshot_wasm_url: "https://snapshots.polkachu.com/wasm/osmosis/osmosis_wasmonly.tar.lz4"
    
    persistent_peers: "peer1@ip:port,peer2@ip:port"
    state_sync_rpc:
      - "https://osmosis-rpc.polkachu.com:443"
      - "https://rpc.osmosis.zone:443"
    
    min_gas_price: "0.0025uosmo"
    denom: "uosmo"
    denom_display: "OSMO"
    decimals: 6
    
    pruning: "custom"
    pruning_keep_recent: "100"
    pruning_keep_every: "0"
    pruning_interval: "10"
    
    cosmovisor_enabled: true
    auto_download_binaries: true
    restart_after_upgrade: true
    
    repo: "https://github.com/osmosis-labs/osmosis"
```

### Finding Chain Information

- **Binary URLs**: Check GitHub releases: `https://github.com/<org>/<repo>/releases`
- **Genesis Files**: Usually at `https://snapshots.polkachu.com/genesis/<chain>/genesis.json`
- **Peers**: Check [Cosmos Directory](https://cosmos.directory/) or chain documentation
- **State Sync RPC**: Look for public RPC endpoints (Polkachu, official endpoints)

### Validating Configuration

After editing `chains.yaml`:

```bash
# Validate syntax
make validate-config

# Generate and test
make generate
```

See [Chains Reference](docs/CHAINS_REFERENCE.md) for detailed documentation.

## Documentation

- **[Multi-Chain Setup Guide](docs/MULTI_CHAIN_SETUP.md)** - Complete deployment guide
- **[Chains Reference](docs/CHAINS_REFERENCE.md)** - chains.yaml configuration reference
- **[Operations Manual](docs/OPERATIONS.md)** - Day-to-day operations
- **[Slack Setup](docs/SLACK_SETUP.md)** - Alerting configuration

## Security

- Never commit secrets to Git (`.gitignore` protects `secrets/`)
- Backup mnemonics in multiple secure locations
- Use firewall to restrict monitoring ports
- Use SSH tunnels for remote monitoring access
- **NEVER run same validator keys on multiple servers** (causes slashing)

## Troubleshooting

```bash
# Check logs
make logs-chain <chain>

# Check status
make status-chain <chain>

# Run diagnostics
make diagnose

# View container stats
make stats
```

## Support

- [Cosmos SDK Docs](https://docs.cosmos.network/)
- [Cosmovisor Guide](https://docs.cosmos.network/main/tooling/cosmovisor)
- [Polkachu Snapshots](https://polkachu.com/tendermint_snapshots)

## License

MIT

## Disclaimer

Running a validator carries financial risks. Always test on testnet first, maintain proper backups, and monitor continuously.

# Validay

Production-ready multi-chain Cosmos validator deployment with monitoring, alerting, and automatic upgrades.

## Features

- **Multi-Chain Support**: Run validators for multiple Cosmos chains simultaneously
- **Dockerized**: Single `validay chain start <chain>` deployment
- **Auto-Upgrades**: Cosmovisor + Polkachu API integration
- **Monitoring**: Prometheus + Grafana dashboards for all chains
- **Alerting**: Slack notifications for critical events
- **Centralized Config**: Manage all chains from `chains.yaml`

## System Requirements

### Architecture Compatibility

**⚠️ Important**: This validator setup is designed for **x86_64 (amd64) Linux systems**. 

**Apple Silicon (ARM64) Macs**: Pre-built Cosmos chain binaries use AVX2 CPU instructions that are not fully supported under Docker's QEMU emulation. Containers may crash with `SIGILL` errors.

**Solutions for ARM64 hosts:**
1. **Use x86_64 hardware** (recommended for production)
2. **Use x86_64 cloud instances** (AWS, GCP, DigitalOcean, etc.)
3. **Build binaries from source** for ARM64 (requires Go toolchain)
4. **Use Colima or Lima** with x86_64 emulation (may have performance issues)

The Dockerfile will automatically attempt to use ARM64 binaries if available, but most Cosmos chains only provide x86_64 binaries.

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

### Step 2: Setup Private Key

```bash
./bin/validay keys setup osmosis
```

This will prompt you to either provide your existing `priv_validator_key.json` content or generate a new one automatically.

### Step 3: Generate Configuration

```bash
./bin/validay generate
```

Generates `docker-compose.yml` and `prometheus.yml` from `chains.yaml`.

### Step 4: Start the Chain

```bash
./bin/validay chain start osmosis
```

### Step 5: Monitor

```bash
# View logs
./bin/validay chain logs osmosis

# Check status
./bin/validay chain status osmosis
```

### Step 6: Fund and Create Validator

```bash
# Show validator address
./bin/validay keys show osmosis

# Send tokens to the address, then create validator
./bin/validay chain create-validator osmosis
```

## Prerequisites

- Docker & Docker Compose
- Python 3.9 or later
- 4 CPU cores, 16GB RAM, 500GB SSD per chain
- Public IP with available ports

## Installation

The CLI is included in this repository. To use it:

```bash
# Install Python dependencies
python3 -m pip install -r requirements.txt

# Add to PATH (optional, for convenience)
export PATH="$PATH:$(pwd)/bin"

# Or use directly
./bin/validay --help
```

**Note**: The CLI requires Python 3.9+ and the dependencies listed in `requirements.txt` (pyyaml, cryptography, mnemonic, bech32, bip-utils).

## Initial Setup (First Time)

```bash
# 1. Install Python dependencies
python3 -m pip install -r requirements.txt

# 2. Create config.yml with global settings
# Copy the example from config.yml (if it exists) or create from scratch
# Set Grafana password, Slack webhook, etc.

# 3. Configure chains.yaml
nano chains.yaml  # Enable desired chains

# 4. Setup private keys for each chain
./bin/validay keys setup cosmos
./bin/validay keys setup osmosis

# 5. Generate configuration
./bin/validay generate

# 6. Start a chain
./bin/validay chain start cosmos

# 7. Check status
./bin/validay chain status cosmos
```

## CLI Commands

### Setup & Maintenance Commands

```bash
validay generate           # Generate docker-compose.yml from chains.yaml
validay list               # List all configured chains
validay validate          # Validate chains.yaml syntax
validay ps                 # Show container status
validay stats              # Show container resource usage
validay diagnose           # Run system diagnostics
validay prune              # Prune unused Docker resources
validay upgrades           # List all pending upgrades
validay clean              # Clean all containers, volumes, and generated files
```

### Chain Management

```bash
validay service start      # Start all monitoring services
validay service stop      # Stop all services
validay service restart   # Restart all services
validay chain start <chain>    # Start specific chain
validay chain stop <chain>     # Stop specific chain
validay chain restart <chain>  # Restart specific chain
validay chain logs <chain>     # View chain logs
validay chain status <chain>   # Check chain status
validay chain shell <chain>    # Enter chain container
validay chain init <chain>     # Initialize chain
validay chain rebuild <chain>   # Rebuild chain container
validay chain clean <chain>    # Remove chain container and volume
```

### Key Management

```bash
validay keys setup <chain>    # Setup private key (provide or generate)
validay keys create <chain>   # Create new keys for chain
validay keys import <chain>   # Import keys from private key
validay keys show <chain>     # Show validator address
validay backup              # Backup all chain keys
validay backup <chain>       # Backup keys for specific chain
validay backup --list        # List all backups
```

### Validator Operations

```bash
validay chain create-validator <chain>  # Create validator for chain
validay query balance <chain>     # Query balance
validay query validator <chain>   # Query validator info
validay query delegations <chain> # Query delegations
```

### Monitoring & Logs

```bash
validay service logs [service]   # View service logs (prometheus/grafana/alertmanager)
validay chain logs <chain>        # View chain logs
validay chain status <chain>      # Check chain status
```

### Upgrade Management

```bash
validay upgrades                       # List all pending upgrades from Polkachu API
validay upgrade check <chain>          # Check upgrade status for chain
validay upgrade prepare <chain> --name <name> --url <url> [--height <height>]
```

### Snapshots

```bash
validay snapshot list <chain>          # List available snapshots from Polkachu
validay snapshot apply <chain> --url <url>  # Apply snapshot (requires --url)
```

### Maintenance

```bash
validay diagnose           # Run system diagnostics
validay ps                 # Show container status
validay stats              # Show container resource usage
validay prune              # Prune unused Docker resources
validay chain rebuild <chain>  # Rebuild specific chain
validay chain clean <chain>    # Remove chain container and volume
```

### Help

```bash
validay --help            # Show all available commands
validay <command> --help  # Show help for specific command
```

## Monitoring URLs

After starting, access monitoring at:

- **Grafana**: http://YOUR_IP:3001 (default: admin / check `config.yml` for password)
- **Prometheus**: http://YOUR_IP:9091
- **Alertmanager**: http://YOUR_IP:9093
- **Node Exporter**: http://YOUR_IP:9100

**Note**: Ports are configurable in `config.yml` under `monitoring.ports`. Use `validay list` to see all configured chains and their status.

## Configuration Files

- **`chains.yaml`** - Chain-specific configuration (binary URLs, ports, network settings, chain-specific overrides)
- **`config.yml`** - Global settings, defaults, and per-chain validator overrides
- **`secrets/<chain>-private-key.json`** - Chain private keys in priv_validator_key.json format (gitignored)

### Configuration Priority

When configuring chains, the priority order is:

1. **Chain-specific overrides in `chains.yaml`** (highest priority)
2. **Global defaults in `config.yml`**
3. **Hardcoded fallbacks** (lowest priority)

This allows you to:
- Set sensible defaults in `config.yml` for all chains
- Override specific settings per-chain in `chains.yaml` when needed
- Keep configuration DRY (Don't Repeat Yourself)

**Example**: If you set `state_sync_defaults.trust_height_offset: 2000` in `config.yml`, all chains will use 2000 blocks unless a specific chain overrides it in `chains.yaml`.

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
| `validator.gas_adjustment` | float | No | Gas adjustment multiplier for transactions | `1.5` |

**Priority**: `chains.yaml` validator settings > `config.yml` defaults

### Chain-Specific State Sync Configuration (Optional)

Override state-sync settings for specific chains. If not specified, uses defaults from `config.yml`.

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `state_sync.trust_height_offset` | integer | No | Blocks before latest height to use as trust height | `3000` |
| `state_sync.trust_period` | string | No | Trust period for state-sync | `"336h0m0s"` (14 days) |

### Chain-Specific Consensus Configuration (Optional)

Override consensus settings for specific chains. If not specified, uses defaults from `config.yml`.

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `consensus.timeout_commit` | string | No | Timeout for commit phase | `"6s"` |

### Chain-Specific Telemetry Configuration (Optional)

Override telemetry settings for specific chains. If not specified, uses defaults from `config.yml`.

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `telemetry.prometheus_retention_time` | integer | No | Prometheus retention time in seconds | `120` |

### Chain-Specific Health Check Configuration (Optional)

Override health check settings for specific chains. Useful for slow-starting chains.

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `healthcheck.interval` | string | No | Health check interval | `"60s"` |
| `healthcheck.timeout` | string | No | Health check timeout | `"15s"` |
| `healthcheck.retries` | integer | No | Health check retries | `5` |
| `healthcheck.start_period` | string | No | Health check start period | `"180s"` |

### Chain-Specific Docker Logging Configuration (Optional)

Override logging settings for specific chains. Useful for high-traffic chains that need more log retention.

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `docker.logging.max_size` | string | No | Maximum log file size | `"200m"` |
| `docker.logging.max_files` | integer | No | Maximum number of log files | `5` |

### Chain-Specific Monitoring Configuration (Optional)

Override Prometheus scrape interval for specific chains.

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `monitoring.scrape_interval` | string | No | Prometheus scrape interval for this chain | `"5s"` |

### Chain-Specific Binary URL Template (Optional)

Override binary URL template for chains that don't use the standard GitHub release pattern.

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `binary.url_template` | string | No | URL template for downloading binaries | `"{repo}/releases/download/v{version}/{binary_name}"` |

**Template Variables**: `{repo}`, `{version}`, `{binary_name}`

**Example**: To set a 20% commission for Osmosis while keeping all other defaults:
```yaml
osmosis:
  # ... other chain config ...
  validator:
    commission_rate: 0.20  # Only this field overrides config.yml
```

**Example**: Chain-specific overrides for state-sync, consensus, and monitoring:
```yaml
cosmos:
  # ... other chain config ...
  state_sync:
    trust_height_offset: 3000  # Override default 2000
  consensus:
    timeout_commit: "6s"  # Override default 5s
  healthcheck:
    start_period: "180s"  # Override default 120s for slow-starting chain
  monitoring:
    scrape_interval: "5s"  # More frequent monitoring for this chain
  docker:
    logging:
      max_size: "200m"  # More log retention for high-traffic chain
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
| `monitoring.ports.prometheus` | integer | No | External port for Prometheus | `9091` |
| `monitoring.ports.grafana` | integer | No | External port for Grafana | `3001` |
| `monitoring.ports.alertmanager` | integer | No | External port for Alertmanager | `9093` |
| `monitoring.ports.node_exporter` | integer | No | External port for Node Exporter | `9100` |
| `monitoring.prometheus.global_scrape_interval` | string | No | Global Prometheus scrape interval | `"15s"` |
| `monitoring.prometheus.global_evaluation_interval` | string | No | Global Prometheus evaluation interval | `"15s"` |
| `monitoring.prometheus.chain_scrape_interval` | string | No | Default per-chain scrape interval | `"10s"` |
| `monitoring.grafana.query_timeout` | string | No | Grafana query timeout | `"60s"` |

### Alerting Configuration

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `alerting.slack_webhook_url` | string | No | Slack webhook URL for alerts | `""` |
| `alerting.alert_on_upgrade` | boolean | No | Send alerts for chain upgrades | `true` |
| `alerting.alert_on_sync_issues` | boolean | No | Send alerts for sync problems | `true` |
| `alerting.alert_on_missed_blocks` | boolean | No | Send alerts for missed blocks | `true` |
| `alerting.group_wait` | string | No | Alertmanager group wait time | `"10s"` |
| `alerting.group_interval` | string | No | Alertmanager group interval | `"10s"` |
| `alerting.repeat_interval` | string | No | Alertmanager repeat interval | `"3h"` |

### Upgrade Monitoring

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `upgrade_monitoring.check_interval` | integer | No | How often to check for upgrades (seconds) | `300` |
| `upgrade_monitoring.preparation_hours` | integer | No | Hours before upgrade to prepare binaries | `48` |
| `upgrade_monitoring.api_url` | string | No | Upgrade API URL | `"https://polkachu.com/api/v2/chain_upgrades"` |
| `upgrade_monitoring.api_timeout` | integer | No | API request timeout (seconds) | `30` |
| `upgrade_monitoring.docker_exec_timeout` | integer | No | Docker exec timeout (seconds) | `300` |
| `upgrade_monitoring.python_version` | string | No | Python version for upgrade monitor | `"3.11"` |

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
| `validator_defaults.gas_adjustment` | float | No | Gas adjustment multiplier for transactions | `1.5` |

**Note**: To override validator settings for a specific chain, add a `validator:` section in `chains.yaml`. Only the fields you specify will override the defaults. For example:

```yaml
# In chains.yaml
osmosis:
  # ... other chain config ...
  validator:
    commission_rate: 0.20  # Only override commission, everything else uses config.yml defaults
    gas_adjustment: 2.0     # Override gas adjustment for this chain
```

### State Sync Defaults

Default state-sync settings for all chains. These can be overridden per-chain in `chains.yaml`.

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `state_sync_defaults.trust_height_offset` | integer | No | Blocks before latest height to use as trust height | `2000` |
| `state_sync_defaults.trust_period` | string | No | Trust period for state-sync | `"168h0m0s"` (7 days) |

### Consensus Defaults

Default consensus settings for all chains. These can be overridden per-chain in `chains.yaml`.

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `consensus_defaults.timeout_commit` | string | No | Timeout for commit phase | `"5s"` |

### Telemetry Defaults

Default telemetry settings for all chains. These can be overridden per-chain in `chains.yaml`.

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `telemetry_defaults.prometheus_retention_time` | integer | No | Prometheus retention time in seconds (0 = disabled) | `60` |

### Binary Configuration Defaults

Default binary URL template for upgrade downloads. Most chains use GitHub releases, but can be overridden per-chain.

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `binary_defaults.url_template` | string | No | URL template for downloading binaries (variables: `{repo}`, `{version}`, `{binary_name}`) | `"{repo}/releases/download/{version}/{binary_name}-{version}-linux-amd64"` |

### Docker Configuration

Global Docker settings for all containers.

| Field | Type | Required | Description | Default |
|-------|------|----------|-------------|---------|
| `docker.platform` | string | No | Docker platform/architecture | `"linux/amd64"` |
| `docker.go_version` | string | No | Go version for Cosmovisor build | `"1.23"` |
| `docker.base_image` | string | No | Base Docker image | `"debian:bookworm-slim"` |
| `docker.network_name` | string | No | Docker network name | `"validay-network"` |
| `docker.restart_policy` | string | No | Container restart policy | `"unless-stopped"` |
| `docker.healthcheck_defaults.interval` | string | No | Health check interval | `"30s"` |
| `docker.healthcheck_defaults.timeout` | string | No | Health check timeout | `"10s"` |
| `docker.healthcheck_defaults.retries` | integer | No | Health check retries | `3` |
| `docker.healthcheck_defaults.start_period` | string | No | Health check start period | `"120s"` |
| `docker.logging_defaults.max_size` | string | No | Maximum log file size | `"100m"` |
| `docker.logging_defaults.max_files` | integer | No | Maximum number of log files | `3` |

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
./bin/validay validate

# Generate and test
./bin/validay generate
```

See [Chains Reference](docs/CHAINS_REFERENCE.md) for detailed documentation.

## Documentation

- **[Multi-Chain Setup Guide](docs/MULTI_CHAIN_SETUP.md)** - Complete deployment guide
- **[Chains Reference](docs/CHAINS_REFERENCE.md)** - chains.yaml configuration reference
- **[Operations Manual](docs/OPERATIONS.md)** - Day-to-day operations
- **[Slack Setup](docs/SLACK_SETUP.md)** - Alerting configuration

## Security

- Never commit secrets to Git (`.gitignore` protects `secrets/`)
- Backup private keys in multiple secure locations
- Use firewall to restrict monitoring ports
- Use SSH tunnels for remote monitoring access
- **NEVER run same validator keys on multiple servers** (causes slashing)

## Troubleshooting

```bash
# Check logs
./bin/validay chain logs <chain>

# Check status
./bin/validay chain status <chain>

# Run diagnostics
./bin/validay diagnose

# View container stats
./bin/validay stats
```

## Support

- [Cosmos SDK Docs](https://docs.cosmos.network/)
- [Cosmovisor Guide](https://docs.cosmos.network/main/tooling/cosmovisor)
- [Polkachu Snapshots](https://polkachu.com/tendermint_snapshots)

## License

MIT

## Disclaimer

Running a validator carries financial risks. Always test on testnet first, maintain proper backups, and monitor continuously.

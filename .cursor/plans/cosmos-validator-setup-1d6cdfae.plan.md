<!-- 1d6cdfae-2726-4ae0-913f-47c70bd24fee 99b73211-3ceb-45ff-93a3-364ed4091b24 -->
# Cosmos Hub Validator - Complete Docker Setup

## Architecture Overview

Single-host Docker Compose deployment with:

- Cosmos Hub node (cosmoshub-4 mainnet) with Cosmovisor
- Prometheus for metrics collection
- Grafana for visualization with pre-configured dashboards
- Alertmanager for Slack notifications
- Node Exporter for system metrics
- All keys managed via Docker secrets

## Implementation Steps

### 1. Core Docker Infrastructure

**docker-compose.yml**

- Define services: cosmos-node, prometheus, grafana, alertmanager, node-exporter
- Configure networks and volumes for persistent data
- Set up Docker secrets references for sensitive data
- Configure health checks and restart policies

**Dockerfile for Cosmos Node**

- Multi-stage build: download gaiad, install Cosmovisor
- Use official Go image as base
- Configure Cosmovisor environment variables
- Set up proper user permissions and data directories
- Include initialization scripts

### 2. Cosmos Node Configuration

**scripts/init-node.sh**

- Initialize gaiad home directory
- Download genesis.json for cosmoshub-4
- Configure config.toml (RPC, P2P, timeouts, pruning)
- Configure app.toml (API, gRPC, metrics enabled, min-gas-prices)
- Add persistent peers from trusted sources
- Setup state-sync or snapshot download from Polkachu/QuickSync

**scripts/setup-keys.sh**

- Read mnemonic from Docker secret (or generate new one)
- Import/create validator key
- Create validator operator key
- Output public addresses for funding
- Store keys securely with proper permissions

**scripts/create-validator.sh**

- Check node is synced
- Check account has required balance (>1 ATOM)
- Create validator transaction with 1 ATOM self-delegation
- Set commission rates and validator metadata
- Provide instructions for editing validator details later

### 3. Cosmovisor Configuration

Configure Cosmovisor environment:

- `DAEMON_NAME=gaiad`
- `DAEMON_HOME=/root/.gaia`
- `DAEMON_ALLOW_DOWNLOAD_BINARIES=true`
- `DAEMON_RESTART_AFTER_UPGRADE=true`
- `UNSAFE_SKIP_BACKUP=false`

Directory structure: `/root/.gaia/cosmovisor/{genesis,upgrades}/bin/`

### 4. Monitoring Stack

**prometheus/prometheus.yml**

- Scrape cosmos-node metrics (port 26660)
- Scrape node-exporter for system metrics
- Retention: 15 days
- Include recording rules for common queries

**prometheus/alerts.yml**

Alert rules for:

- Node not syncing / catching up
- Validator missing blocks
- Low account balance (<2 ATOM)
- New delegations detected (query staking metrics)
- High memory/CPU usage
- Disk space low
- Peer count low
- Upgrade proposals active

**alertmanager/alertmanager.yml**

- Slack webhook integration placeholder
- Route different alert severities
- Grouping and throttling rules
- Templates for alert messages

**grafana/provisioning/**

- datasources/prometheus.yml: Auto-configure Prometheus
- dashboards/cosmos-validator.json: Custom dashboard with:
  - Validator status and voting power
  - Block height and sync status
  - Delegation count and total delegated
  - Missed blocks counter
  - System resources (CPU, RAM, disk, network)
  - Alert status panel

### 5. Security & Secrets

**secrets/ directory structure** (gitignored)

- validator_mnemonic.txt
- priv_validator_key.json (after first init)

**Docker secrets configuration**

- Map secrets to /run/secrets/ in containers
- Scripts read from secrets location
- README instructions for secret file creation

### 6. Documentation

**README.md**

- Prerequisites (Docker, Docker Compose, funded account)
- Quick start guide
- How to create Slack webhook URL
- Initial setup steps
- How to fund validator account
- How to create validator
- Monitoring dashboard access
- Backup procedures (CRITICAL: mnemonic + priv_validator_key.json)
- Upgrade handling (automatic via Cosmovisor)
- Common operations and troubleshooting
- Security best practices

**docs/SLACK_SETUP.md**

- Step-by-step Slack app creation
- Webhook URL generation
- Permissions required
- Testing notifications

**docs/OPERATIONS.md**

- Daily maintenance tasks
- How to check validator status
- Handling upgrades
- Disaster recovery
- Key rotation procedures

### 7. Helper Scripts

**scripts/check-status.sh**

- Query validator info
- Check sync status
- Display current height vs network height
- Show delegations

**scripts/backup-keys.sh**

- Safely backup critical files
- Encrypt with password option
- List what needs to be backed up

**Makefile**

- Common commands: start, stop, logs, status
- Key management commands
- Backup commands

## Key Files Structure

```
cosmos-validator/
├── docker-compose.yml
├── Dockerfile
├── Makefile
├── README.md
├── .env.example
├── .gitignore
├── docs/
│   ├── SLACK_SETUP.md
│   └── OPERATIONS.md
├── scripts/
│   ├── init-node.sh
│   ├── setup-keys.sh
│   ├── create-validator.sh
│   ├── check-status.sh
│   └── backup-keys.sh
├── prometheus/
│   ├── prometheus.yml
│   └── alerts.yml
├── alertmanager/
│   └── alertmanager.yml
├── grafana/
│   └── provisioning/
│       ├── datasources/
│       │   └── prometheus.yml
│       └── dashboards/
│           ├── dashboard.yml
│           └── cosmos-validator.json
└── secrets/  (gitignored)
    └── .gitkeep
```

## Critical Configuration Details

- **Ports**: 26656 (P2P), 26657 (RPC), 1317 (API), 9090 (gRPC), 26660 (metrics)
- **Pruning**: custom (100/0/10) for validators
- **Min gas prices**: 0.0025uatom
- **Snapshot source**: Polkachu or QuickSync
- **Persistent peers**: Use from cosmos.directory or chain.json
- **State sync**: Disable after initial sync
- **Prometheus retention**: 15d
- **Grafana port**: 3000
- **Alertmanager port**: 9093

## Security Considerations

- Docker secrets for all sensitive data
- Non-root user in containers where possible
- Network isolation via Docker networks
- Firewall rules documented in README
- Regular backup reminders in alerts
- Mnemonic never logged or exposed

### To-dos

- [ ] Create docker-compose.yml with all services and Dockerfile for Cosmos node with Cosmovisor
- [ ] Create initialization scripts for node setup, key management, and validator creation
- [ ] Configure Prometheus with scrape configs and comprehensive alert rules
- [ ] Setup Alertmanager with Slack integration and alert routing
- [ ] Create Grafana provisioning configs and custom Cosmos validator dashboard
- [ ] Write comprehensive README, Slack setup guide, and operations documentation
- [ ] Create utility scripts for status checking, backups, and Makefile for common commands
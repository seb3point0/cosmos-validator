# Cosmos Hub Validator - Docker Setup

Complete, production-ready Cosmos Hub validator deployment with monitoring, alerting, and automatic upgrades via Cosmovisor.

## Features

- **Fully Dockerized**: Single `docker-compose up` deployment
- **Cosmovisor Integration**: Automatic binary upgrades
- **Comprehensive Monitoring**: Prometheus + Grafana dashboards
- **Smart Alerting**: Slack notifications for critical events, missed blocks, new delegations
- **Secure Key Management**: Docker secrets for sensitive data
- **State Sync/Snapshots**: Fast initial synchronization
- **Best Practices**: Production-grade configuration for mainnet validators

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Cosmos Hub Validator Node (Cosmovisor + gaiad)         │
│  ├─ P2P: 26656                                          │
│  ├─ RPC: 26657                                          │
│  ├─ API: 1317                                           │
│  ├─ gRPC: 9090                                          │
│  └─ Metrics: 26660 ──────────┐                         │
└──────────────────────────────┼──────────────────────────┘
                               │
                               ▼
         ┌────────────────────────────────────┐
         │  Prometheus (Metrics & Alerts)     │
         │  Port: 9090                        │
         └────────┬───────────────────┬───────┘
                  │                   │
                  ▼                   ▼
     ┌────────────────────┐  ┌──────────────────┐
     │  Grafana           │  │  Alertmanager    │
     │  Dashboard: 3000   │  │  Slack: 9093     │
     └────────────────────┘  └──────────────────┘
```

## Prerequisites

- **Docker** and **Docker Compose** installed
- **Minimum 4 CPU cores**, 16GB RAM, 500GB SSD
- **Ubuntu 20.04+** or similar Linux distribution
- **Public IP address** with ports 26656-26657 open
- **At least 2 ATOM** for validator creation + fees

## Quick Start

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd cosmos-validator

# Create secrets directory
mkdir -p secrets
```

### 2. Configure Environment

```bash
cp env.example .env
nano .env
```

Edit the following values:
- `MONIKER`: Your validator name
- `EXTERNAL_IP`: Your server's public IP
- `VALIDATOR_NAME`: Display name for your validator
- `VALIDATOR_WEBSITE`: Your website URL
- `VALIDATOR_SECURITY_CONTACT`: Email for security issues
- `COMMISSION_RATE`: Commission rate (e.g., 0.10 for 10%)
- `GRAFANA_ADMIN_PASSWORD`: Secure password for Grafana

### 3. Setup Validator Keys

**Option A: Generate New Keys** (recommended for new validators)

The keys will be automatically generated on first startup. You'll need to save the mnemonic that gets displayed.

**Option B: Import Existing Keys**

If you have an existing mnemonic:

```bash
echo "your mnemonic phrase here" > secrets/validator_mnemonic.txt
chmod 600 secrets/validator_mnemonic.txt
```

### 4. Start the Validator

```bash
docker-compose up -d
```

This will:
- Build the Cosmos node container with Cosmovisor
- Initialize the node with proper configuration
- Download a recent snapshot from Polkachu (fast sync)
- Start all monitoring services
- Generate or import validator keys

### 5. Monitor Initial Sync

```bash
# Watch logs
docker-compose logs -f cosmos-node

# Check sync status
docker exec cosmos-validator /scripts/check-status.sh
```

Wait until the node is fully synced (can take 30 minutes to several hours depending on snapshot).

### 6. Fund Your Validator

Get your validator address:

```bash
docker exec cosmos-validator gaiad keys show validator -a --keyring-backend test
```

Send at least **2 ATOM** to this address:
- 1 ATOM for self-delegation
- Extra for transaction fees

Verify balance:

```bash
docker exec cosmos-validator /scripts/check-status.sh
```

### 7. Create Validator

Once synced and funded:

```bash
docker exec -it cosmos-validator /scripts/create-validator.sh
```

Follow the prompts to confirm validator creation.

### 8. Setup Slack Notifications

See [docs/SLACK_SETUP.md](docs/SLACK_SETUP.md) for detailed instructions.

Once you have a webhook URL:

```bash
# Add to .env file
echo "SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL" >> .env

# Restart alertmanager
docker-compose restart alertmanager
```

### 9. Access Monitoring

- **Grafana Dashboard**: http://YOUR_IP:3000
  - Username: `admin`
  - Password: (from .env file)
  - Navigate to "Cosmos Hub Validator Dashboard"

- **Prometheus**: http://YOUR_IP:9090
- **Alertmanager**: http://YOUR_IP:9093

## Common Operations

### Check Validator Status

```bash
make status
# or
docker exec cosmos-validator /scripts/check-status.sh
```

### View Logs

```bash
# All services
docker-compose logs -f

# Just validator node
docker-compose logs -f cosmos-node

# Specific number of lines
docker-compose logs --tail=100 cosmos-node
```

### Backup Keys

```bash
make backup
# or
docker exec cosmos-validator /scripts/backup-keys.sh
```

**CRITICAL**: Copy the backup to multiple secure locations!

```bash
docker cp cosmos-validator:/root/.gaia/backup/validator_backup_*.tar.gz ./
```

### Stop/Start Validator

```bash
# Stop all services
docker-compose down

# Start all services
docker-compose up -d

# Restart just the validator
docker-compose restart cosmos-node
```

### Update Configuration

```bash
# Edit .env file
nano .env

# Restart services
docker-compose down
docker-compose up -d
```

### Manual Upgrade (if needed)

Cosmovisor handles upgrades automatically, but if needed:

```bash
# Enter container
docker exec -it cosmos-validator bash

# Check cosmovisor status
cosmovisor version

# Current binary
/root/.gaia/cosmovisor/current/bin/gaiad version
```

## Security Best Practices

### Firewall Configuration

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Allow P2P
sudo ufw allow 26656/tcp

# Allow RPC (optional, only if needed)
sudo ufw allow 26657/tcp

# Restrict monitoring to local only (use SSH tunnel for remote access)
sudo ufw deny 3000/tcp
sudo ufw deny 9090/tcp

# Enable firewall
sudo ufw enable
```

### SSH Tunneling for Remote Monitoring

```bash
# On your local machine
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 user@YOUR_SERVER_IP

# Then access in browser:
# http://localhost:3000 (Grafana)
# http://localhost:9090 (Prometheus)
```

### Key Management

- **Never commit secrets to Git**: The `.gitignore` file protects the `secrets/` directory
- **Backup your mnemonic**: Store in multiple secure locations (encrypted USB, password manager, etc.)
- **Backup priv_validator_key.json**: This file is critical for validator identity
- **Use encrypted backups**: The backup script supports GPG encryption
- **Rotate keys if compromised**: See [docs/OPERATIONS.md](docs/OPERATIONS.md)

### Regular Maintenance

- Monitor Slack alerts daily
- Check Grafana dashboard weekly
- Verify backups monthly
- Update system packages regularly
- Keep Docker and Docker Compose updated

## Monitoring & Alerts

### Grafana Dashboard Panels

- **Sync Status**: Real-time sync state
- **Block Height**: Current block vs network
- **Connected Peers**: P2P network health
- **Missed Blocks**: Validator performance
- **Voting Power**: Delegation tracking
- **System Resources**: CPU, RAM, Disk usage
- **Network Traffic**: Bandwidth monitoring

### Alert Categories

**Critical Alerts** (immediate notification):
- Node not syncing
- Validator missing many blocks (slashing risk)
- No peer connections
- Critical resource usage
- Validator jailed

**Warning Alerts** (grouped notifications):
- Node catching up
- Missing some blocks
- Low peer count
- High resource usage
- Large mempool

**Info Alerts** (daily summary):
- New delegations received
- Voting power changes
- Governance proposals

## Troubleshooting

### Node Won't Start

```bash
# Check logs
docker-compose logs cosmos-node

# Common issue: port already in use
sudo lsof -i :26656
sudo lsof -i :26657

# Reset and restart
docker-compose down
docker-compose up -d
```

### Node Stuck Syncing

```bash
# Check current status
docker exec cosmos-validator curl -s http://localhost:26657/status | jq

# Try downloading a fresh snapshot
docker-compose down
docker volume rm cosmos-validator_cosmos-data
docker-compose up -d
```

### Missed Blocks

```bash
# Check validator signing info
docker exec cosmos-validator gaiad query slashing signing-info \
  $(docker exec cosmos-validator gaiad tendermint show-validator) \
  --node http://localhost:26657
```

### Out of Memory

```bash
# Check current usage
docker stats

# Increase Docker memory limit or add swap
```

### Keys Not Found

```bash
# List keys
docker exec cosmos-validator gaiad keys list --keyring-backend test

# If empty, keys need to be reimported
# Make sure secrets/validator_mnemonic.txt exists
docker-compose restart cosmos-node
```

## Upgrading

### Cosmovisor Automatic Upgrades

Cosmovisor automatically handles chain upgrades:

1. Upgrade proposal passes on-chain
2. Cosmovisor downloads new binary (if `DAEMON_ALLOW_DOWNLOAD_BINARIES=true`)
3. At upgrade height, Cosmovisor stops old binary
4. Creates backup of data directory
5. Starts new binary
6. You receive Slack notification

**Monitor Slack alerts during upgrades!**

### Manual Binary Updates

If you need to manually update:

```bash
# Enter container
docker exec -it cosmos-validator bash

# Download new binary
cd /tmp
wget https://github.com/cosmos/gaia/releases/download/vX.Y.Z/gaiad-vX.Y.Z-linux-amd64

# Copy to cosmovisor upgrades directory
mkdir -p /root/.gaia/cosmovisor/upgrades/vX.Y.Z/bin
mv gaiad-vX.Y.Z-linux-amd64 /root/.gaia/cosmovisor/upgrades/vX.Y.Z/bin/gaiad
chmod +x /root/.gaia/cosmovisor/upgrades/vX.Y.Z/bin/gaiad
```

## Disaster Recovery

### Validator Key Compromise

If your validator key is compromised:

1. **Immediately stop the validator**:
   ```bash
   docker-compose down
   ```

2. **Create new validator** on different machine with new keys

3. **Migrate delegations** (requires governance vote or manual delegation changes)

### System Failure

If your validator host fails:

1. **Prepare new server** with same setup

2. **Restore keys** from backup:
   ```bash
   tar -xzf validator_backup_*.tar.gz -C /path/to/new/validator/
   ```

3. **Start validator**:
   ```bash
   docker-compose up -d
   ```

4. **Verify sync and signing**:
   ```bash
   docker exec cosmos-validator /scripts/check-status.sh
   ```

### Double Signing Prevention

**NEVER run the same validator keys on multiple servers simultaneously!**

This causes double signing and results in **permanent slashing and jailing**.

## Support & Resources

- **Cosmos Hub Documentation**: https://hub.cosmos.network/
- **Cosmos SDK**: https://docs.cosmos.network/
- **Cosmovisor**: https://docs.cosmos.network/main/tooling/cosmovisor
- **Cosmos Discord**: https://discord.gg/cosmosnetwork
- **Cosmos Forum**: https://forum.cosmos.network/

## Makefile Commands

```bash
make start          # Start all services
make stop           # Stop all services
make restart        # Restart all services
make logs           # View all logs
make status         # Check validator status
make backup         # Backup validator keys
make clean          # Stop and remove volumes (DANGER!)
```

## File Structure

```
cosmos-validator/
├── docker-compose.yml       # Main orchestration file
├── Dockerfile              # Cosmos node container
├── Makefile                # Common commands
├── README.md               # This file
├── .env.example            # Environment template
├── .gitignore             # Git ignore rules
├── docs/                  # Documentation
│   ├── SLACK_SETUP.md     # Slack integration guide
│   └── OPERATIONS.md      # Operations manual
├── scripts/               # Utility scripts
│   ├── entrypoint.sh      # Container entrypoint
│   ├── init-node.sh       # Node initialization
│   ├── setup-keys.sh      # Key management
│   ├── create-validator.sh # Validator creation
│   ├── check-status.sh    # Status checker
│   └── backup-keys.sh     # Backup utility
├── prometheus/            # Prometheus config
│   ├── prometheus.yml     # Scrape configuration
│   └── alerts.yml         # Alert rules
├── alertmanager/          # Alertmanager config
│   └── alertmanager.yml   # Notification routing
├── grafana/               # Grafana config
│   └── provisioning/      # Auto-provisioning
│       ├── datasources/   # Prometheus datasource
│       └── dashboards/    # Validator dashboard
└── secrets/               # Sensitive data (gitignored)
    └── validator_mnemonic.txt
```

## License

MIT

## Disclaimer

Running a validator carries financial risks. This setup is provided as-is with no guarantees. Always test on testnet first, maintain proper backups, and monitor your validator continuously.

**You are responsible for:**
- Securing your server and keys
- Monitoring validator performance
- Responding to alerts
- Keeping software updated
- Understanding slashing conditions


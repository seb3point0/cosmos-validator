# Quick Start Guide - Cosmos Hub Validator

Get your validator running in 5 steps!

## Prerequisites

- Docker & Docker Compose installed
- Linux server with 4+ CPU, 16GB+ RAM, 500GB+ SSD
- Public IP with ports 26656-26657 open
- 2+ ATOM for validator creation

## 5-Minute Setup

### 1. Prepare Environment

```bash
# Copy environment template
cp env.example .env

# Or create it directly:
cat > .env << 'EOF'
CHAIN_ID=cosmoshub-4
MONIKER=my-validator
EXTERNAL_IP=YOUR_PUBLIC_IP_HERE
VALIDATOR_NAME="My Validator"
VALIDATOR_WEBSITE="https://example.com"
VALIDATOR_IDENTITY=""
VALIDATOR_DETAILS="A reliable Cosmos Hub validator"
VALIDATOR_SECURITY_CONTACT="security@example.com"
COMMISSION_RATE=0.10
COMMISSION_MAX_RATE=0.20
COMMISSION_MAX_CHANGE_RATE=0.01
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
GRAFANA_ADMIN_PASSWORD=change_me_now
EOF

# Edit with your values
nano .env
```

### 2. Setup Secrets (Optional - for existing keys)

```bash
# If you have existing mnemonic
mkdir -p secrets
echo "your twenty four word mnemonic phrase here" > secrets/validator_mnemonic.txt
chmod 600 secrets/validator_mnemonic.txt
```

If you don't have a mnemonic, one will be generated automatically (SAVE IT!).

### 3. Start Validator

```bash
docker-compose up -d
```

This will:
- Download and build all containers (~5-10 min)
- Initialize node with mainnet genesis
- Download snapshot for fast sync (~30-60 min)
- Start monitoring services

### 4. Monitor Sync Progress

```bash
# Watch logs
docker-compose logs -f cosmos-node

# Check sync status (in another terminal)
make status

# Or watch continuously
watch -n 10 'make sync-status'
```

Wait for `"catching_up": false` before proceeding.

### 5. Fund & Create Validator

```bash
# Get your validator address
make validator-address

# Send 2+ ATOM to that address
# Wait for transaction confirmation

# Create validator
make create-validator
```

## Post-Setup

### Access Monitoring

```bash
# Get URLs
make grafana-url
make prometheus-url
```

Open Grafana, login (admin/your-password), view "Cosmos Hub Validator Dashboard"

### Setup Slack Alerts

See [docs/SLACK_SETUP.md](docs/SLACK_SETUP.md) for complete guide.

Quick version:
1. Create Slack app with incoming webhook
2. Add webhook URL to `.env`
3. `docker-compose restart alertmanager`

### Backup Keys (CRITICAL!)

```bash
make backup

# Copy backup to safe location
docker cp cosmos-validator:/root/.gaia/backup/ ./backups/
```

Store backups in multiple secure locations!

## Verify Everything Works

```bash
# Check validator is signing blocks
make status

# View recent logs
make logs-node

# Check system resources
make stats

# View monitoring dashboards
# Visit Grafana URL from 'make grafana-url'
```

## Common Commands

```bash
make status           # Validator status
make logs             # View all logs
make backup           # Backup keys
make restart          # Restart services
make help             # All commands
```

## Troubleshooting

### Node not syncing?

```bash
# Check logs for errors
make logs-node

# Check peer connections
docker exec cosmos-validator curl -s http://localhost:26657/net_info | jq .result.n_peers

# If stuck, try fresh snapshot
docker-compose down
docker volume rm cosmos-validator_cosmos-data
docker-compose up -d
```

### Out of disk space?

```bash
df -h
make prune-docker
```

### Keys not found?

```bash
# List keys
make keys-list

# If empty, check if mnemonic exists
cat secrets/validator_mnemonic.txt

# Restart to regenerate
docker-compose restart cosmos-node
```

## Next Steps

1. **Join validator communities**:
   - Cosmos Discord: https://discord.gg/cosmosnetwork
   - Cosmos Forum: https://forum.cosmos.network/

2. **Update validator profile**:
   - Add Keybase identity
   - Update website and details
   - Set security contact

3. **Setup monitoring alerts**:
   - Configure Slack webhooks
   - Test alert notifications
   - Add mobile Slack app

4. **Read operations manual**:
   - [docs/OPERATIONS.md](docs/OPERATIONS.md)
   - Daily maintenance tasks
   - Disaster recovery procedures

5. **Test disaster recovery**:
   - Verify backups work
   - Document recovery process
   - Keep emergency contacts handy

## Support

- **Full Documentation**: [README.md](README.md)
- **Slack Setup**: [docs/SLACK_SETUP.md](docs/SLACK_SETUP.md)
- **Operations Manual**: [docs/OPERATIONS.md](docs/OPERATIONS.md)

## Important Warnings

⚠️ **Never run the same validator keys on multiple servers** - This causes double signing and permanent slashing!

⚠️ **Always backup your mnemonic and priv_validator_key.json** - Without these, you cannot recover your validator!

⚠️ **Monitor your validator 24/7** - Use Slack alerts or other monitoring tools!

⚠️ **Test on testnet first** - If this is your first validator, practice on testnet before mainnet!

## Security Checklist

- [ ] Firewall configured (only 26656 open)
- [ ] SSH key authentication enabled
- [ ] Strong passwords set
- [ ] Backups stored securely
- [ ] Monitoring alerts configured
- [ ] Emergency contacts documented
- [ ] Recovery procedure tested

---

**Your validator is now ready! 🎉**

Monitor it closely, especially in the first 24 hours.


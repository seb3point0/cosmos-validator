# Cosmos Validator - Deployment Notes

## ✅ Deployment Complete!

Your Cosmos Hub validator setup is now running with all services operational.

## Actual Port Mappings

Due to port conflicts on your system, the following ports have been adjusted:

- **Cosmos Node**:
  - P2P: `26656`
  - RPC: `26657`
  - API: `1317`
  - gRPC: `9090`
  - Metrics: `26660`

- **Monitoring Stack**:
  - Prometheus: `9091` (changed from 9090 to avoid conflict with gRPC)
  - Grafana: `3001` (changed from 3000 due to port conflict)
  - Alertmanager: `9093`
  - Node Exporter: `9100`

## Access Your Services

### Grafana Dashboard
```
http://localhost:3001
Username: admin
Password: admin (or from your .env file)
```

### Prometheus
```
http://localhost:9091
```

### Alertmanager
```
http://localhost:9093
```

## Current Status

Check the status of all containers:
```bash
docker-compose ps
```

View logs:
```bash
# All services
docker-compose logs -f

# Just validator
docker-compose logs -f cosmos-node
```

## Next Steps

### 1. Wait for Node to Sync

The node is currently downloading the blockchain snapshot and syncing. This can take 30-60 minutes depending on your internet speed.

Monitor sync progress:
```bash
make status
# or
docker exec cosmos-validator /scripts/check-status.sh
```

### 2. Configure Slack Notifications

Follow the guide: `docs/SLACK_SETUP.md`

Quick steps:
1. Create Slack webhook URL
2. Add to `.env` file: `SLACK_WEBHOOK_URL=https://hooks.slack.com/...`
3. Restart alertmanager: `docker-compose restart alertmanager`

### 3. Fund Your Validator

Once synced, get your validator address:
```bash
make validator-address
```

Send **2+ ATOM** to this address (1 for delegation + fees).

### 4. Create Validator

After funding and full sync:
```bash
make create-validator
```

## Important Notes

### Generated Keys

If you didn't provide a mnemonic, new keys were generated automatically. **YOU MUST SAVE THE MNEMONIC!**

View logs to find it:
```bash
docker logs cosmos-validator | grep -A 1 "Important"
```

**Save this mnemonic securely!** Without it, you cannot recover your validator.

### Backup Keys

```bash
make backup
docker cp cosmos-validator:/root/.gaia/backup/ ./backups/
```

Store backups in **multiple secure locations**.

### Configuration

Your current configuration:
- Chain: `cosmoshub-4` (mainnet)
- Gaia Version: `v18.1.0`
- Cosmovisor: `v1.6.0`
- Pruning: Custom (keep-recent=100, interval=10)
- Min Gas Prices: `0.0025uatom`

## Troubleshooting

### Node not syncing?
```bash
# Check logs
make logs-node

# Check peers
docker exec cosmos-validator curl -s http://localhost:26657/net_info | jq .result.n_peers
```

### Prometheus/Grafana not working?
```bash
# Check if services are running
docker-compose ps

# Restart if needed
docker-compose restart prometheus grafana
```

### Need to restart everything?
```bash
docker-compose down
docker-compose up -d
```

## Useful Commands

```bash
make help            # Show all available commands
make status          # Check validator status
make logs            # View all logs
make backup          # Backup validator keys
make ps              # Container status
make stats           # Resource usage
```

## File Locations

- **Configuration**: `./docker-compose.yml`, `./.env`
- **Scripts**: `./scripts/`
- **Monitoring**: `./prometheus/`, `./grafana/`, `./alertmanager/`
- **Secrets**: `./secrets/` (gitignored)
- **Documentation**: `./docs/`, `./README.md`

## Security Checklist

- [ ] Mnemonic saved securely (multiple locations)
- [ ] priv_validator_key.json backed up
- [ ] Firewall configured (only 26656 exposed)
- [ ] Slack alerts configured and tested
- [ ] .env file has strong passwords
- [ ] Backups tested (recovery procedure verified)

## Support & Resources

- **Full Documentation**: [README.md](README.md)
- **Operations Manual**: [docs/OPERATIONS.md](docs/OPERATIONS.md)
- **Slack Setup**: [docs/SLACK_SETUP.md](docs/SLACK_SETUP.md)
- **Security Guide**: [SECURITY.md](SECURITY.md)

- **Cosmos Hub**: https://hub.cosmos.network/
- **Discord**: https://discord.gg/cosmosnetwork
- **Forum**: https://forum.cosmos.network/

---

**Built**: $(date)  
**Status**: ✅ All services running  
**Ready for**: Node sync → Validator creation


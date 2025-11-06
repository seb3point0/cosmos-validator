# Cosmos Hub Validator Deployment Status

## ✅ Deployment Successful

Your Cosmos Hub validator setup has been successfully deployed and is now running!

### Services Running

| Service | Status | Port | Access |
|---------|--------|------|--------|
| Cosmos Validator | ✅ Running | 26656 (P2P), 26657 (RPC), 9090 (gRPC) | Node is syncing via state-sync |
| Prometheus | ✅ Running | 9091 | http://localhost:9091 |
| Grafana | ✅ Running | 3001 | http://localhost:3001 (admin/admin) |
| Alertmanager | ✅ Running | 9093 | http://localhost:9093 |
| Node Exporter | ✅ Running | - | Metrics collector for system stats |

### Current State

**Cosmos Node Status:**
- Chain ID: cosmoshub-4
- Moniker: interop
- Version: v18.1.0
- Cosmovisor: ✅ Enabled for automatic upgrades
- State-sync: ✅ Enabled (syncing from height 28296530)
- Min Gas Prices: 0.0025uatom
- P2P Node ID: b2716e63f34696e99347c5ddd7cd5d6393c0d478

**Initial Sync:**
The node is currently syncing using state-sync, which should complete within 15-30 minutes. You can monitor progress with:

```bash
docker logs cosmos-validator -f
```

### Next Steps

1. **Monitor Sync Progress**
   ```bash
   docker logs cosmos-validator -f | grep "Discovering snapshots"
   ```

2. **Check Node Status**
   ```bash
   docker exec cosmos-validator gaiad status
   ```

3. **Access Monitoring**
   - Grafana: http://localhost:3001 (default credentials: admin/admin)
   - Prometheus: http://localhost:9091

4. **Set Up Validator Keys** (after sync completes)
   The node currently has auto-generated keys. To use your own:
   - Stop the node: `docker-compose down`
   - Place your mnemonic in `secrets/validator_mnemonic.txt`
   - Restart: `docker-compose up -d`

5. **Create Validator Transaction** (after sync completes)
   ```bash
   docker exec -it cosmos-validator gaiad tx staking create-validator \
     --amount=1000000uatom \
     --pubkey=$(docker exec cosmos-validator gaiad tendermint show-validator) \
     --moniker="YourValidatorName" \
     --commission-rate="0.10" \
     --commission-max-rate="0.20" \
     --commission-max-change-rate="0.01" \
     --min-self-delegation="1" \
     --from=validator \
     --chain-id=cosmoshub-4 \
     --gas=auto \
     --gas-adjustment=1.4 \
     --gas-prices=0.0025uatom
   ```

6. **Set Up Slack Notifications**
   - Edit `alertmanager/alertmanager.yml`
   - Add your Slack webhook URL to the `slack_api_url` field
   - Restart: `docker-compose restart alertmanager`

### Useful Commands

**View logs:**
```bash
docker logs cosmos-validator -f
docker logs prometheus -f
docker logs grafana -f
```

**Check sync status:**
```bash
docker exec cosmos-validator gaiad status | jq '.SyncInfo'
```

**Restart services:**
```bash
docker-compose restart cosmos-node
docker-compose restart prometheus
```

**Stop all services:**
```bash
docker-compose down
```

**View resource usage:**
```bash
docker stats
```

### Important Notes

⚠️ **Security Reminders:**
- The `secrets/` directory contains sensitive validator keys
- Never commit the `secrets/` directory to version control
- Ensure proper firewall rules are configured
- Change Grafana admin password after first login

⚠️ **Before Going Live:**
- Wait for full sync to complete
- Set up proper validator keys (if not already done)
- Configure firewall to only allow necessary ports
- Set up proper backup procedures for validator keys
- Test alerting to ensure you receive notifications

### Troubleshooting

**Node won't start:**
```bash
docker logs cosmos-validator --tail 100
```

**Check configuration:**
```bash
docker exec cosmos-validator cat /root/.gaia/config/config.toml
docker exec cosmos-validator cat /root/.gaia/config/app.toml
```

**Reset and start fresh:**
```bash
docker-compose down
docker volume rm cosmos-validator_cosmos-data
docker-compose up -d
```

### File Structure

```
cosmos-validator/
├── docker-compose.yml          # Main orchestration file
├── Dockerfile                  # Cosmos node image
├── .env                        # Environment variables (create from env.example)
├── secrets/                    # Validator keys (NEVER commit!)
├── scripts/                    # Initialization scripts
├── prometheus/                 # Prometheus configuration
├── grafana/                    # Grafana dashboards and datasources
└── alertmanager/              # Alert routing configuration
```

### Support Resources

- Cosmos Hub Documentation: https://hub.cosmos.network/
- Validator Guide: https://hub.cosmos.network/validators/overview.html
- Discord: https://discord.gg/cosmosnetwork
- Forum: https://forum.cosmos.network/

---

**Deployment Date:** November 6, 2025
**Deployed Version:** Gaia v18.1.0 with Cosmovisor v1.6.0


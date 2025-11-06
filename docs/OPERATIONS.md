# Validator Operations Manual

Comprehensive guide for operating and maintaining your Cosmos Hub validator.

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Monitoring](#monitoring)
3. [Handling Upgrades](#handling-upgrades)
4. [Disaster Recovery](#disaster-recovery)
5. [Common Issues](#common-issues)
6. [Security](#security)
7. [Performance Tuning](#performance-tuning)

## Daily Operations

### Morning Checklist

```bash
# 1. Check validator status
make status

# 2. Review missed blocks
docker exec cosmos-validator gaiad query slashing signing-info \
  $(docker exec cosmos-validator gaiad tendermint show-validator) \
  --node http://localhost:26657

# 3. Check system resources
docker stats --no-stream

# 4. Verify peer connections
docker exec cosmos-validator curl -s http://localhost:26657/net_info | jq .result.n_peers

# 5. Check for pending upgrades
curl -s https://cosmos.directory/cosmoshub/chain | jq .current_upgrade
```

### Weekly Tasks

- Review Grafana dashboard trends
- Check disk space growth rate
- Verify backup integrity
- Review and clear resolved alerts
- Check for security updates
- Monitor delegation changes

### Monthly Tasks

- Test disaster recovery procedure
- Rotate monitoring passwords
- Review and update documentation
- Audit firewall rules
- Check for Cosmovisor updates
- Review commission rate and consider adjustments

## Monitoring

### Key Metrics to Watch

#### Validator Health

```bash
# Sync status
curl -s http://localhost:26657/status | jq .result.sync_info.catching_up

# Latest block height
curl -s http://localhost:26657/status | jq .result.sync_info.latest_block_height

# Validator voting power
curl -s http://localhost:26657/status | jq .result.validator_info.voting_power
```

#### System Health

```bash
# CPU usage
top -bn1 | grep "Cpu(s)"

# Memory usage
free -h

# Disk space
df -h

# Network connections
netstat -an | grep :26656 | wc -l
```

#### Application Metrics (via Prometheus)

Access Prometheus at http://YOUR_IP:9090 and query:

- `tendermint_consensus_latest_block_height` - Current height
- `tendermint_consensus_validator_missed_blocks` - Missed blocks counter
- `tendermint_p2p_peers` - Connected peers
- `tendermint_mempool_size` - Pending transactions
- `process_resident_memory_bytes` - Memory usage

### Alert Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Missed blocks (1h) | 5 | 20 | Check sync status, restart if needed |
| Peers | < 5 | < 2 | Check network, add peers manually |
| CPU usage | > 80% | > 95% | Check for runaway processes |
| Memory usage | > 85% | > 95% | Consider adding RAM or enable swap |
| Disk space | < 20% | < 10% | Clean up old data, expand disk |
| Sync lag | > 100 blocks | > 1000 blocks | Check network, consider state sync |

## Handling Upgrades

### Cosmovisor Automatic Upgrades

Cosmovisor handles most upgrades automatically:

1. **Before Upgrade**:
   - Monitor Cosmos governance proposals
   - Join validator Discord/Telegram for coordination
   - Ensure Cosmovisor is configured correctly:
     ```bash
     docker exec cosmos-validator printenv | grep DAEMON
     ```

2. **During Upgrade**:
   - Monitor logs closely:
     ```bash
     docker logs -f cosmos-validator
     ```
   - Cosmovisor will automatically:
     - Download new binary (if enabled)
     - Backup data directory
     - Stop old binary
     - Start new binary

3. **After Upgrade**:
   - Verify new version:
     ```bash
     docker exec cosmos-validator gaiad version
     ```
   - Check validator is signing:
     ```bash
     make status
     ```
   - Monitor for 1-2 hours

### Manual Upgrade (if needed)

If automatic upgrade fails:

```bash
# 1. Stop the validator
docker-compose stop cosmos-node

# 2. Enter container (if needed to prepare binary)
docker exec -it cosmos-validator bash

# 3. Download new binary
cd /tmp
wget https://github.com/cosmos/gaia/releases/download/vX.Y.Z/gaiad-vX.Y.Z-linux-amd64
chmod +x gaiad-vX.Y.Z-linux-amd64

# 4. Install to cosmovisor
mkdir -p /root/.gaia/cosmovisor/upgrades/vX.Y.Z/bin
mv gaiad-vX.Y.Z-linux-amd64 /root/.gaia/cosmovisor/upgrades/vX.Y.Z/bin/gaiad

# 5. Exit and restart
exit
docker-compose start cosmos-node

# 6. Verify
docker exec cosmos-validator gaiad version
```

### Upgrade Preparation Checklist

- [ ] Backup validator keys
- [ ] Backup entire data directory (optional but recommended)
- [ ] Test upgrade on testnet first
- [ ] Verify binary checksums
- [ ] Join validator coordination channel
- [ ] Ensure sufficient disk space (10GB+ free)
- [ ] Be available during upgrade window
- [ ] Have rollback plan ready

## Disaster Recovery

### Scenario 1: Node Crashes

```bash
# Check container status
docker-compose ps

# Check logs for errors
docker-compose logs --tail=100 cosmos-node

# Restart node
docker-compose restart cosmos-node

# If restart fails, full restart
docker-compose down
docker-compose up -d
```

### Scenario 2: Validator Missing Blocks

```bash
# 1. Check if node is synced
make status

# 2. Check if validator key is loaded
docker exec cosmos-validator gaiad keys list --keyring-backend test

# 3. Check for double signing (DANGEROUS!)
# Make absolutely sure validator is not running elsewhere

# 4. Check system resources
docker stats

# 5. If everything looks good but still missing blocks, restart
docker-compose restart cosmos-node
```

### Scenario 3: Server Hardware Failure

**Preparation** (do this NOW):

```bash
# 1. Backup validator keys
make backup

# 2. Copy backup to secure location
docker cp cosmos-validator:/root/.gaia/backup/validator_backup_*.tar.gz ./
scp validator_backup_*.tar.gz user@backup-server:/secure/location/

# 3. Document your setup (save this info securely)
cat > validator-info.txt <<EOF
Validator Address: $(docker exec cosmos-validator gaiad keys show validator -a --keyring-backend test)
Operator Address: $(docker exec cosmos-validator gaiad keys show validator --bech val -a --keyring-backend test)
Server IP: $(curl -s ifconfig.me)
Chain ID: cosmoshub-4
EOF
```

**Recovery** (when disaster strikes):

```bash
# 1. Prepare new server
# Install Docker and Docker Compose

# 2. Clone validator setup
git clone <your-repo> cosmos-validator
cd cosmos-validator

# 3. Restore secrets
tar -xzf validator_backup_TIMESTAMP.tar.gz

# Copy extracted files to correct locations
cp root/.gaia/config/priv_validator_key.json secrets/
cp root/.gaia/data/priv_validator_state.json secrets/

# 4. Update configuration
cp .env.example .env
nano .env  # Update with your settings

# 5. Start validator
docker-compose up -d

# 6. Monitor sync status
watch docker exec cosmos-validator /scripts/check-status.sh

# 7. Once synced, verify validator is signing
make status
```

### Scenario 4: Validator Jailed

If your validator gets jailed:

```bash
# 1. Check why you were jailed
docker exec cosmos-validator gaiad query slashing signing-info \
  $(docker exec cosmos-validator gaiad tendermint show-validator) \
  --node http://localhost:26657

# 2. Ensure node is now healthy
make status

# 3. Unjail validator
docker exec cosmos-validator gaiad tx slashing unjail \
  --from validator \
  --chain-id cosmoshub-4 \
  --gas auto \
  --gas-adjustment 1.5 \
  --gas-prices 0.0025uatom \
  --keyring-backend test \
  --node http://localhost:26657 \
  --yes

# 4. Verify validator is active again
make status
```

### Scenario 5: Forgot to Backup Keys

**If you still have access to the server:**

```bash
# IMMEDIATELY backup keys
make backup

# Copy to multiple locations
docker cp cosmos-validator:/root/.gaia/backup/validator_backup_*.tar.gz ./
# Copy to USB drive, cloud storage, etc.
```

**If server is lost and no backup exists:**

Unfortunately, without the `priv_validator_key.json` and mnemonic, you cannot recover the validator. You'll need to:

1. Create a new validator with new keys
2. Contact delegators to redelegate
3. Stake may be lost due to downtime/jailing

**Prevention**: Always maintain multiple backups in different locations!

## Common Issues

### Issue: High Memory Usage

**Symptoms**: Memory usage > 90%, OOM kills

**Solution**:

```bash
# 1. Check current usage
free -h
docker stats

# 2. Enable swap (if not already)
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 3. Adjust pruning (more aggressive)
# Edit docker-compose.yml to mount custom app.toml
# Set pruning-keep-recent = "50" (from 100)

# 4. Restart with changes
docker-compose restart cosmos-node
```

### Issue: Disk Full

**Symptoms**: Disk usage > 95%, node stops

**Solution**:

```bash
# 1. Check disk usage
df -h
du -sh /var/lib/docker/volumes/*

# 2. Clean Docker system
docker system prune -a --volumes

# 3. Check validator data size
du -sh /var/lib/docker/volumes/cosmos-validator_cosmos-data

# 4. If data is too large, consider state sync from scratch
docker-compose down
docker volume rm cosmos-validator_cosmos-data
docker-compose up -d

# 5. Long term: expand disk or enable more aggressive pruning
```

### Issue: Peer Connection Problems

**Symptoms**: Low peer count, not syncing

**Solution**:

```bash
# 1. Check current peers
docker exec cosmos-validator curl -s http://localhost:26657/net_info | jq .result.n_peers

# 2. Add peers manually
# Edit docker-compose.yml or use environment variable
# Add to config: persistent_peers="peer1@ip1:26656,peer2@ip2:26656"

# 3. Get fresh peer list
curl -s https://cosmos.directory/cosmoshub/nodes | jq -r '.nodes[] | select(.type == "peer") | "\(.moniker)@\(.address)"' | head -10

# 4. Restart with new peers
docker-compose restart cosmos-node
```

### Issue: Cosmovisor Not Auto-Upgrading

**Symptoms**: Validator stops at upgrade height

**Solution**:

```bash
# 1. Check Cosmovisor environment
docker exec cosmos-validator printenv | grep DAEMON

# 2. Verify upgrade info exists
docker exec cosmos-validator ls -la /root/.gaia/cosmovisor/upgrades/

# 3. If binary missing, download manually
# (see Manual Upgrade section above)

# 4. Ensure DAEMON_ALLOW_DOWNLOAD_BINARIES=true
# Check docker-compose.yml or Dockerfile
```

## Security

### Key Security Best Practices

1. **Never expose validator keys**:
   - Keep `priv_validator_key.json` secure
   - Never commit to git
   - Encrypt backups

2. **Firewall configuration**:
   ```bash
   sudo ufw allow 22/tcp      # SSH
   sudo ufw allow 26656/tcp   # P2P
   sudo ufw deny 26657/tcp    # RPC (use SSH tunnel instead)
   sudo ufw deny 1317/tcp     # API
   sudo ufw deny 9090/tcp     # gRPC
   sudo ufw enable
   ```

3. **SSH hardening**:
   ```bash
   # Disable password auth
   sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
   sudo systemctl restart sshd

   # Use SSH keys only
   # Optionally: Set up fail2ban
   sudo apt install fail2ban
   ```

4. **Regular security updates**:
   ```bash
   # Enable automatic security updates
   sudo apt install unattended-upgrades
   sudo dpkg-reconfigure -plow unattended-upgrades
   ```

### Sentry Node Architecture (Advanced)

For production validators, consider sentry nodes:

```
Internet
   │
   ├── Sentry Node 1 (Public)
   ├── Sentry Node 2 (Public)
   │       │
   └───────┴──── Validator (Private)
```

Benefits:
- Validator hidden from public internet
- DDoS protection
- Better security

Setup requires:
- Multiple servers
- Private network configuration
- Modified P2P settings

See: https://hub.cosmos.network/main/validators/validator-faq.html#how-can-validators-protect-themselves-from-denial-of-service-attacks

## Performance Tuning

### Optimize Node Performance

1. **Database backend** (default is goleveldb, consider cleveldb):
   ```bash
   # In config.toml
   db_backend = "cleveldb"  # Faster but needs C libraries
   ```

2. **Adjust cache sizes**:
   ```bash
   # In app.toml
   [state-sync]
   snapshot-interval = 1000
   snapshot-keep-recent = 2
   ```

3. **Optimize pruning**:
   ```bash
   # Balance between disk usage and performance
   pruning = "custom"
   pruning-keep-recent = "100"    # Lower = less disk, more I/O
   pruning-keep-every = "0"
   pruning-interval = "10"
   ```

4. **System tuning**:
   ```bash
   # Increase file descriptors
   ulimit -n 65536
   
   # Add to /etc/security/limits.conf:
   * soft nofile 65536
   * hard nofile 65536
   ```

### Monitor Performance

```bash
# I/O performance
iostat -x 1

# Network throughput
iftop

# Process performance
htop
```

## Support Resources

- **Cosmos Hub**: https://hub.cosmos.network/
- **Discord**: https://discord.gg/cosmosnetwork
- **Forum**: https://forum.cosmos.network/
- **Telegram**: https://t.me/cosmosproject
- **GitHub**: https://github.com/cosmos/gaia

## Emergency Contacts

Keep this information readily available:

- Server provider support number
- Backup server credentials
- Key backup locations
- Delegator communication channels
- Validator coordination channels

## Changelog

Keep track of changes to your validator:

```
[YYYY-MM-DD] Initial validator setup
[YYYY-MM-DD] Upgraded to gaiad vX.Y.Z
[YYYY-MM-DD] Increased commission rate to X%
[YYYY-MM-DD] Migrated to new hardware
```


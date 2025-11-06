# Security Guidelines

## Critical Security Measures

### 1. Key Management

**Your validator keys are the most critical assets. Lose them = lose control of your validator.**

#### Backup Strategy

✅ **DO**:
- Backup immediately after key generation
- Store encrypted backups in multiple locations
- Test recovery process regularly
- Use hardware wallets when possible
- Keep paper backups in secure physical locations

❌ **DON'T**:
- Store keys unencrypted
- Commit keys to version control
- Share keys via email/chat
- Store only in cloud without encryption
- Keep only one backup

#### Key Files to Protect

1. `secrets/validator_mnemonic.txt` - Recovers all keys
2. `priv_validator_key.json` - Validator signing key
3. `priv_validator_state.json` - Prevents double signing

### 2. Server Hardening

#### Firewall Configuration

```bash
# Essential: Only expose P2P port
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 26656/tcp comment 'Cosmos P2P'
sudo ufw enable

# DO NOT expose these ports to internet:
# 26657 - RPC
# 1317  - API
# 9090  - gRPC
# 3000  - Grafana
# 9090  - Prometheus
```

#### SSH Hardening

```bash
# Disable password authentication
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Disable root login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Use only SSH keys
# Change default SSH port (optional but recommended)
sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config

sudo systemctl restart sshd
```

#### Fail2Ban

```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

#### Automatic Security Updates

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 3. Monitoring Access

#### Use SSH Tunnels

Don't expose monitoring ports. Instead, use SSH tunnels:

```bash
# On your local machine
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 user@validator-ip

# Then access locally:
# http://localhost:3000 (Grafana)
# http://localhost:9090 (Prometheus)
```

#### Grafana Security

```bash
# Change default password immediately
# Set in .env file:
GRAFANA_ADMIN_PASSWORD=VeryStrongPasswordHere123!

# Consider enabling HTTPS
# Consider enabling OAuth (GitHub, Google, etc.)
```

### 4. Docker Security

#### Don't Run as Root (where possible)

The current setup runs gaiad as root in the container for simplicity. For production, consider:

```dockerfile
# In Dockerfile, add:
RUN adduser --disabled-password --gecos '' cosmos
USER cosmos
```

#### Use Docker Secrets

Already implemented for mnemonic. Keep it that way.

#### Regular Updates

```bash
# Update Docker
sudo apt update && sudo apt upgrade docker-ce

# Rebuild containers periodically
docker-compose build --no-cache
docker-compose up -d
```

### 5. Network Security

#### DDoS Protection

Consider using:
- Sentry node architecture (validator hidden behind public sentries)
- Cloudflare for public-facing services
- Rate limiting on P2P connections

#### Sentry Node Architecture (Advanced)

```
Internet → Sentry1 (Public) ┐
       → Sentry2 (Public) ├→ Validator (Private)
       → Sentry3 (Public) ┘
```

Benefits:
- Validator IP never exposed
- DDoS attacks hit sentries, not validator
- Can quickly spin up new sentries if attacked

Setup requires multiple servers. See: https://docs.cosmos.network/main/validators/validator-faq.html#how-can-validators-protect-themselves-from-denial-of-service-attacks

### 6. Double Signing Prevention

**CRITICAL**: Running validator keys on multiple servers simultaneously = permanent slashing!

✅ **DO**:
- Run validator on ONE machine only
- Completely shut down old validator before starting new one
- Use `priv_validator_state.json` to track last signed block
- Wait several minutes between stopping old and starting new

❌ **DON'T**:
- Run same keys on multiple servers
- Start new validator immediately after old one crashes
- Delete `priv_validator_state.json`

### 7. Operational Security

#### Access Control

- Limit who has SSH access
- Use separate accounts (no shared accounts)
- Implement 2FA for SSH (Google Authenticator + PAM)
- Log all access (use auditd)
- Regular access audits

#### Monitoring

- Enable alerts for SSH logins
- Monitor validator signing status 24/7
- Alert on unauthorized container restarts
- Track all configuration changes

#### Incident Response Plan

1. **Key Compromise**:
   - Immediately stop validator
   - Assess what was accessed
   - Create new validator with new keys
   - Notify delegators
   - Post-mortem analysis

2. **Server Compromise**:
   - Isolate server from network
   - Analyze logs for attack vector
   - Rebuild from clean backup
   - Rotate all credentials
   - Security audit

3. **Validator Jailed**:
   - Identify cause
   - Fix underlying issue
   - Unjail validator
   - Monitor for recurrence
   - Document in runbook

### 8. Secrets Management

#### Environment Variables

```bash
# Ensure .env has proper permissions
chmod 600 .env

# Never log environment variables
# Check docker-compose logs don't expose secrets
```

#### Docker Secrets

Already implemented for validator mnemonic. Consider adding:
- Grafana admin password
- Slack webhook URL (though less critical)

#### Keyring Backend

Using `--keyring-backend test` for Docker simplicity. For production, consider:
- `--keyring-backend file` with strong passphrase
- Hardware wallet integration (Ledger)
- Remote signer (Horcrux, tmkms)

### 9. Compliance & Auditing

#### Logging

```bash
# Enable audit logging
sudo apt install auditd
sudo systemctl enable auditd

# Log all commands
echo 'PROMPT_COMMAND="history -a; logger -p local1.notice -t bash -i -- \$USER: \$(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//")"' >> ~/.bashrc
```

#### Regular Audits

- Weekly: Check for unauthorized access attempts
- Monthly: Review and test backups
- Quarterly: Full security audit
- Yearly: Penetration testing

### 10. Update Strategy

#### Monitoring for Updates

```bash
# Check for Gaia updates
make check-upgrades

# Subscribe to:
# - Cosmos GitHub releases
# - Validator Discord/Telegram
# - Cosmos Forum announcements
```

#### Safe Update Process

1. Test on testnet first
2. Announce downtime to delegators (if needed)
3. Backup before upgrade
4. Let Cosmovisor handle it automatically
5. Monitor closely for 24h after upgrade

## Security Checklist

### Initial Setup
- [ ] Strong passwords set for all accounts
- [ ] SSH key authentication enabled
- [ ] Password authentication disabled
- [ ] Firewall configured (only 26656 open)
- [ ] Fail2ban installed and configured
- [ ] Automatic security updates enabled
- [ ] Docker secrets configured
- [ ] Monitoring alerts configured

### Key Management
- [ ] Mnemonic backed up (3+ locations)
- [ ] priv_validator_key.json backed up
- [ ] Backups encrypted
- [ ] Backups tested (recovery process verified)
- [ ] Paper backup stored in safe location
- [ ] Emergency access documented

### Operational
- [ ] Monitoring dashboard accessible
- [ ] Slack alerts working
- [ ] Emergency contacts documented
- [ ] Incident response plan created
- [ ] Regular backup schedule established
- [ ] Update notification channels subscribed

### Advanced (Optional)
- [ ] Sentry node architecture implemented
- [ ] Hardware wallet integration
- [ ] Remote signing setup (tmkms/Horcrux)
- [ ] DDoS protection configured
- [ ] Full security audit completed

## Reporting Security Issues

If you discover a security vulnerability in this setup:

1. **DO NOT** open a public issue
2. Contact the Cosmos security team: security@cosmos.network
3. Document: What, Where, How, Impact
4. Provide time for fix before disclosure

## Resources

- Cosmos Security Best Practices: https://docs.cosmos.network/main/validators/security
- Cosmos Validator FAQ: https://hub.cosmos.network/main/validators/validator-faq.html
- CIS Docker Benchmark: https://www.cisecurity.org/benchmark/docker
- OWASP Docker Security: https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html

## Disclaimer

Security is an ongoing process, not a one-time setup. Stay vigilant, keep systems updated, and always assume you could be a target.

**No setup is 100% secure. This guide provides a strong foundation, but you must adapt to your specific threat model and requirements.**


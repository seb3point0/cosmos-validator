# How to Start Your Cosmos Validator

## Current Situation

The snapshot you applied was from an older version (v18.1.0) that's incompatible with the current version (v25.1.0). Here are your options:

## Option 1: Start Fresh (Recommended for Testing)

This will sync from the network, which takes time but ensures compatibility:

```bash
cd /Users/seb3point0/dev/cosmos-validator

# Remove the old data
docker-compose down
docker volume rm cosmos-validator_cosmos-data

# Start fresh
docker-compose up -d

# Monitor - it will sync from peers
docker logs cosmos-validator -f
```

**Pros:** Clean, compatible
**Cons:** Will take several hours/days to sync

## Option 2: Use a Fresh v25.1.0 Snapshot

Get a current snapshot from Polkachu for v25.1.0:

```bash
cd /Users/seb3point0/dev/cosmos-validator

# Stop services
docker-compose down

# Check Polkachu for the latest v25 snapshot
# Visit: https://polkachu.com/tendermint_snapshots/cosmos

# Download and apply (you'll need the latest snapshot URL)
docker run --rm \
  -v cosmos-validator_cosmos-data:/root/.gaia \
  -v "$(pwd)/scripts:/scripts:ro" \
  --entrypoint /bin/bash \
  cosmos-validator-cosmos-node \
  -c "apt-get update && apt-get install -y wget lz4 && bash /scripts/apply-snapshot.sh <NEW_SNAPSHOT_URL>"

# Start services
docker-compose up -d
```

## Option 3: Go Back to v18.1.0 (If You Want To Use That Snapshot)

```bash
cd /Users/seb3point0/dev/cosmos-validator

# Update docker-compose.yml to use v18.1.0
sed -i '' 's/GAIA_VERSION: v25.1.0/GAIA_VERSION: v18.1.0/' docker-compose.yml

# Update Dockerfile Go versions back to 1.22
sed -i '' 's/golang:1.23/golang:1.22/g' Dockerfile
sed -i '' 's/cosmovisor@latest/cosmovisor@v1.6.0/g' Dockerfile
sed -i '' 's/wasmvm\/v2@v2.2.4/wasmvm@v1.5.0/g' Dockerfile

# Rebuild
docker-compose build cosmos-node

# Remove the entrypoint flag that skips wasmvm check
# Edit scripts/entrypoint.sh and remove --wasm.skip_wasmvm_version_check

# Start
docker-compose up -d
```

## My Recommendation

**For testing/learning:** Use Option 1 (start fresh)  
**For production:** Use Option 2 (get a current snapshot)

The node will work either way, but Option 2 is faster for mainnet.

## After the Node is Synced

Once your node is fully synced (`catching_up: false`), you can create your validator:

### 1. Check Sync Status

```bash
docker exec cosmos-validator gaiad status | jq '.SyncInfo.catching_up'
```

Wait until this returns `false`.

### 2. Create Validator Keys (if needed)

```bash
# Create a new validator key
docker exec -it cosmos-validator gaiad keys add validator

# OR import existing mnemonic
echo "your twelve or twenty-four word mnemonic" > secrets/validator_mnemonic.txt
docker-compose restart cosmos-node
```

### 3. Fund Your Validator

You need ATOM tokens to create a validator. Transfer at least 1 ATOM (plus gas) to your validator address:

```bash
# Get your validator address
docker exec cosmos-validator gaiad keys show validator -a
```

### 4. Create the Validator

```bash
docker exec -it cosmos-validator gaiad tx staking create-validator \
  --amount=1000000uatom \
  --pubkey=$(docker exec cosmos-validator gaiad tendermint show-validator) \
  --moniker="YOUR_VALIDATOR_NAME" \
  --details="YOUR_DESCRIPTION" \
  --website="https://yourwebsite.com" \
  --identity="YOUR_KEYBASE_ID" \
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

## Monitoring

- **Grafana:** http://localhost:3001 (admin/admin)
- **Prometheus:** http://localhost:9091
- **Logs:** `docker logs cosmos-validator -f`

## Need Help?

Check these resources:
- Discord: https://discord.gg/cosmosnetwork
- Docs: https://hub.cosmos.network/validators
- Snapshots: https://polkachu.com/tendermint_snapshots/cosmos


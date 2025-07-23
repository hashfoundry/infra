# HashFoundry Blockchain - Polkadot Substrate

Complete Kubernetes deployment for HashFoundry blockchain infrastructure using Polkadot Substrate.

## Overview

This Helm chart deploys a High Availability Polkadot Substrate blockchain with:
- **2 Validator nodes**: Alice (primary) and Bob (secondary)
- **1M HF tokens** initial balance for each validator
- **External RPC/WebSocket access** via NGINX Ingress
- **Prometheus monitoring** integration
- **Persistent storage** for blockchain data

## Architecture

```
                    NGINX Ingress Load Balancer
                           |
        ┌──────────────────┼──────────────────┐
        │                  │                  │
    Alice RPC          Bob RPC              
  (Port 9944)        (Port 9944)            
        │                  │                  
  ┌─────────────┐    ┌─────────────┐         
  │   Alice     │    │    Bob      │         
  │ Validator   │◄──►│ Validator   │         
  │             │    │             │         
  │ - 1M HF     │    │ - 1M HF     │         
  │ - 50Gi SSD  │    │ - 50Gi SSD  │         
  │ - Prometheus│    │ - Prometheus│         
  └─────────────┘    └─────────────┘         
```

## Blockchain Specifications

| Parameter | Value |
|-----------|-------|
| **Chain Name** | HashFoundry Local Testnet |
| **Chain ID** | hashfoundry_local |
| **Token Symbol** | HF |
| **Token Decimals** | 12 |
| **Block Time** | 6 seconds |
| **Consensus** | Aura + GRANDPA |

## Account Configuration

### Alice Validator
- **Address**: `5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY`
- **Initial Balance**: 1,000,000 HF tokens
- **Role**: Primary validator, sudo account
- **RPC Endpoint**: `blockchain-rpc-1.hashfoundry.local`

### Bob Validator  
- **Address**: `5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty`
- **Initial Balance**: 1,000,000 HF tokens
- **Role**: Secondary validator
- **RPC Endpoint**: `blockchain-rpc-2.hashfoundry.local`

## Quick Start

### Prerequisites
- Kubernetes cluster with NGINX Ingress Controller
- Helm 3.x installed
- `kubectl` configured

### Installation

```bash
# Install blockchain
helm install hashfoundry-blockchain . -n blockchain --create-namespace

# Check deployment status
helm status hashfoundry-blockchain -n blockchain

# View pods
kubectl get pods -n blockchain
```

### Using Makefile

```bash
# Install with development workflow
make dev-install

# Check status
make status

# View logs
make logs-alice
make logs-bob

# Port forward for local access
make port-forward-alice  # localhost:9933
make port-forward-bob    # localhost:9934
```

## External Access

### RPC Endpoints (via Ingress)
- **Alice**: `https://blockchain-rpc-1.hashfoundry.local`
- **Bob**: `https://blockchain-rpc-2.hashfoundry.local`

### Add to /etc/hosts
```bash
<INGRESS_IP> blockchain-rpc-1.hashfoundry.local
<INGRESS_IP> blockchain-rpc-2.hashfoundry.local
```

### CLI Testing

```bash
# Check node info via Alice
curl -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "system_name", "params":[]}' \
     https://blockchain-rpc-1.hashfoundry.local

# Check account balance
curl -H "Content-Type: application/json" \
     -d '{"id":1, "jsonrpc":"2.0", "method": "system_accountInfo", "params":["5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"]}' \
     https://blockchain-rpc-1.hashfoundry.local
```

## Monitoring

### Prometheus Metrics
- **Alice metrics**: `http://blockchain-alice:9615/metrics`
- **Bob metrics**: `http://blockchain-bob:9615/metrics`

### Available Metrics
- `substrate_block_height` - Current block height
- `substrate_ready_transactions_number` - Transaction pool size
- `substrate_peers` - Connected peers count
- `substrate_is_syncing` - Sync status

### Grafana Dashboard
The deployment includes ServiceMonitor for automatic Prometheus discovery. 
Import Substrate dashboard in Grafana to visualize blockchain metrics.

## Configuration

### Values.yaml Structure
```yaml
blockchain:
  chainName: "HashFoundry Local Testnet"
  tokenSymbol: "HF"
  tokenDecimals: 12

validatorAlice:
  enabled: true
  account:
    address: "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"
    initialBalance: "1000000000000000"

validatorBob:
  enabled: true
  account:
    address: "5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"
    initialBalance: "1000000000000000"
```

### Resource Requirements
```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "4Gi" 
    cpu: "2000m"

persistence:
  size: "50Gi"
  storageClass: "do-block-storage"
```

## Development

### Helm Commands
```bash
# Template generation
helm template hashfoundry-blockchain . -n blockchain

# Lint chart
helm lint .

# Dry run
helm install hashfoundry-blockchain . -n blockchain --dry-run

# Upgrade
helm upgrade hashfoundry-blockchain . -n blockchain
```

### Troubleshooting
```bash
# Check pod status
kubectl get pods -n blockchain -o wide

# View logs
kubectl logs -f statefulset/hashfoundry-blockchain-alice -n blockchain
kubectl logs -f statefulset/hashfoundry-blockchain-bob -n blockchain

# Debug pod
kubectl describe pod -n blockchain -l app.kubernetes.io/component=validator-alice

# Check storage
kubectl get pvc -n blockchain
```

## Security

### Node Keys
- **Alice**: Ed25519 key stored in Secret `hashfoundry-blockchain-alice-key`
- **Bob**: Ed25519 key stored in Secret `hashfoundry-blockchain-bob-key`

### Security Context
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
```

### Network Policies
The chart includes NetworkPolicy to restrict traffic to:
- NGINX Ingress → RPC ports (9933, 9944)
- Inter-validator P2P communication (30333)
- Prometheus scraping (9615)

## Backup & Recovery

### Data Backup
```bash
# Create backup of blockchain data
kubectl exec -n blockchain hashfoundry-blockchain-alice-0 -- tar czf /backup/alice-$(date +%Y%m%d).tar.gz -C /data .

# Copy backup locally  
kubectl cp blockchain/hashfoundry-blockchain-alice-0:/backup/alice-$(date +%Y%m%d).tar.gz ./alice-backup.tar.gz
```

### Disaster Recovery
```bash
# Restore from backup
kubectl cp ./alice-backup.tar.gz blockchain/hashfoundry-blockchain-alice-0:/backup/restore.tar.gz
kubectl exec -n blockchain hashfoundry-blockchain-alice-0 -- tar xzf /backup/restore.tar.gz -C /data
```

## Maintenance

### Scaling
```bash
# Scale validators (if needed)
helm upgrade hashfoundry-blockchain . -n blockchain --set validatorAlice.replicaCount=1 --set validatorBob.replicaCount=1
```

### Updates
```bash
# Update Substrate version
helm upgrade hashfoundry-blockchain . -n blockchain --set validatorAlice.image.tag=v0.9.43
```

### Clean Uninstall
```bash
# Remove deployment
helm uninstall hashfoundry-blockchain -n blockchain

# Remove PVCs (WARNING: This deletes blockchain data!)
kubectl delete pvc -n blockchain -l app.kubernetes.io/name=blockchain

# Remove namespace
kubectl delete namespace blockchain
```

## Support

For issues and questions:
- **Repository**: https://github.com/hashfoundry/infra
- **Documentation**: [blockchain/high-level-design-doc.md](../../../blockchain/high-level-design-doc.md)
- **Contact**: infrastructure@hashfoundry.com

## License

MIT License - see repository for details.

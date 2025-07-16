# HashFoundry Infrastructure Template

Enterprise-grade High Availability Kubernetes infrastructure template for DigitalOcean.

## 🚀 Quick Deployment (3 Commands)

```bash
# 1. Initialize and check dependencies
./init.sh

# 2. Configure your DigitalOcean token
nano .env  # Set DO_TOKEN

# 3. Deploy everything
./deploy-terraform.sh && ./deploy-k8s.sh
```

## 🎯 What You Get

### **Infrastructure**
- ✅ **HA Kubernetes Cluster** (3+ nodes with auto-scaling)
- ✅ **DigitalOcean Load Balancer** (managed automatically)
- ✅ **Persistent Storage** (Block + NFS for ReadWriteMany)
- ✅ **Auto-scaling** (3-6 nodes based on demand)

### **Applications & Services**
- ✅ **ArgoCD** (GitOps with HA configuration)
- ✅ **NGINX Ingress** (External access with SSL/TLS)
- ✅ **Monitoring Stack** (Prometheus + Grafana + NFS Exporter)
- ✅ **NFS Provisioner** (Shared storage for applications)
- ✅ **Sample React App** (HashFoundry demo application)

### **Monitoring & Observability**
- ✅ **Prometheus** (Metrics collection and alerting)
- ✅ **Grafana** (Dashboards and visualization)
- ✅ **NFS Exporter** (Filesystem monitoring)
- ✅ **15-panel NFS Dashboard** (Professional monitoring)
- ✅ **Infrastructure Metrics** (CPU, Memory, Disk, Network)

## 📊 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DigitalOcean Cloud                      │
├─────────────────────────────────────────────────────────────┤
│  Load Balancer (External Access)                           │
│  ├── NGINX Ingress Controller                              │
│  │   ├── ArgoCD UI (https://argocd.hashfoundry.local)     │
│  │   ├── Grafana (https://grafana.hashfoundry.local)      │
│  │   ├── Prometheus (https://prometheus.hashfoundry.local)│
│  │   └── React App (https://app-dev.hashfoundry.local)    │
├─────────────────────────────────────────────────────────────┤
│  Kubernetes Cluster (HA)                                   │
│  ├── Control Plane (Managed HA)                            │
│  ├── Worker Nodes (3-6 nodes, auto-scaling)               │
│  │   ├── ArgoCD (HA: 2 controllers, 3 servers)            │
│  │   ├── Monitoring (Prometheus HA + Grafana)              │
│  │   ├── NFS Provisioner (ReadWriteMany storage)          │
│  │   └── Applications (React, etc.)                        │
│  └── Storage                                               │
│      ├── Block Storage (Prometheus + Grafana data)        │
│      └── NFS Storage (Shared volumes)                      │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Requirements

- **DigitalOcean API Token** (with Kubernetes permissions)
- **CLI Tools**: `terraform`, `kubectl`, `helm`, `doctl`, `envsubst`, `htpasswd`

> **Note**: All scripts automatically check dependencies and provide installation instructions.

## 📋 Scripts Overview

| Script | Purpose | What it does |
|--------|---------|--------------|
| `./init.sh` | Initialize | Check dependencies, create .env file |
| `./deploy-terraform.sh` | Infrastructure | Deploy HA Kubernetes cluster |
| `./deploy-k8s.sh` | Applications | Deploy ArgoCD + monitoring + apps |
| `./status.sh` | Status Check | Check cluster and application status |
| `./cleanup.sh` | Cleanup | Destroy all infrastructure |

## 🌐 Access URLs

After deployment, access your services:

```bash
# ArgoCD UI (GitOps Management)
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Then: http://localhost:8080 (admin / your_password)

# Or via Ingress (add to /etc/hosts):
# <LOAD_BALANCER_IP> argocd.hashfoundry.local
# <LOAD_BALANCER_IP> grafana.hashfoundry.local  
# <LOAD_BALANCER_IP> prometheus.hashfoundry.local
```

## 💰 Cost Estimation

- **Minimal HA**: ~$48/month (3x s-1vcpu-2gb + Load Balancer)
- **Production HA**: ~$96/month (4x s-2vcpu-4gb + Load Balancer)
- **Auto-scaling**: Costs adjust automatically based on load

## 🔒 Security Features

- ✅ **Pod Security Standards** (restricted security contexts)
- ✅ **Network Policies** (traffic isolation)
- ✅ **RBAC** (role-based access control)
- ✅ **TLS/SSL** (encrypted communication)
- ✅ **Non-root containers** (security best practices)

## 📚 Documentation

- [`QUICKSTART.md`](QUICKSTART.md) - Detailed deployment guide
- [`TEMPLATE_READINESS_ANALYSIS.md`](TEMPLATE_READINESS_ANALYSIS.md) - Template analysis
- [`MONITORING_STACK_FINAL_SUCCESS.md`](MONITORING_STACK_FINAL_SUCCESS.md) - Monitoring details
- [`GRAFANA_ALERTING_SETUP_GUIDE.md`](GRAFANA_ALERTING_SETUP_GUIDE.md) - Alerting setup

## 🚨 Troubleshooting

### Common Issues

1. **CLI tools missing**: Run `./init.sh` for installation instructions
2. **DO_TOKEN not set**: Edit `.env` file with your DigitalOcean API token
3. **Cluster not found**: Run `./deploy-terraform.sh` first
4. **Applications not syncing**: Check ArgoCD UI for sync status

### Status Commands

```bash
# Check everything
./status.sh

# Check cluster nodes
kubectl get nodes

# Check ArgoCD applications  
kubectl get applications -n argocd

# Check monitoring pods
kubectl get pods -n monitoring
```

## 🎯 Use Cases

- **Development Teams**: GitOps workflow with monitoring
- **Staging Environments**: Production-like setup for testing
- **Small Production**: Cost-effective HA infrastructure
- **Learning**: Enterprise Kubernetes patterns and tools
- **Templates**: Base for custom infrastructure

## 🔄 Maintenance

### Updates
```bash
# Update applications via ArgoCD (GitOps)
git commit -m "Update app version"
git push  # ArgoCD auto-syncs

# Update infrastructure
./deploy-terraform.sh  # Re-run to apply changes
```

### Monitoring
```bash
# Check cluster health
./status.sh

# Access Grafana dashboards
# https://grafana.hashfoundry.local

# View Prometheus metrics
# https://prometheus.hashfoundry.local
```

### Cleanup
```bash
# Destroy everything
./cleanup.sh
```

## 🤝 Contributing

This template is designed to be:
- **Modular**: Easy to customize components
- **Documented**: Comprehensive guides and examples
- **Production-ready**: Security and HA best practices
- **Cost-optimized**: Efficient resource usage

## 📄 License

MIT License - Feel free to use and modify for your projects.

---

**Ready to deploy enterprise-grade infrastructure in 3 commands? Start with `./init.sh`!**

# NFS Provisioner for ArgoCD HA

Platform-agnostic NFS storage provisioner for ArgoCD High Availability setup.

## Features

- ✅ Platform-independent storage solution
- ✅ ReadWriteMany support for shared storage
- ✅ Automatic PVC provisioning
- ✅ Cost-effective (single backing volume)
- ✅ Easy backup and restore

## Installation

```bash
# Install NFS Provisioner
make install

# Check status
make status
```

## Usage

Create PVC using NFS storage:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 10Gi
```

## Configuration

See `values.yaml` for all configuration options.

## Troubleshooting

```bash
# Check logs
make logs

# Test provisioning
make test

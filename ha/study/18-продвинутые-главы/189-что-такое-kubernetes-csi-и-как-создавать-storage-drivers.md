# 189. Что такое Kubernetes CSI и как создавать storage drivers?

## 🎯 Вопрос
Что такое Kubernetes CSI и как создавать storage drivers?

## 💡 Ответ

Container Storage Interface (CSI) - это стандартный интерфейс для подключения внешних систем хранения к Kubernetes. CSI позволяет разработчикам создавать storage drivers, которые работают с любой совместимой системой оркестрации контейнеров, обеспечивая единообразный способ управления хранилищем.

### 🏗️ Архитектура CSI

#### 1. **Схема CSI Architecture**
```
┌─────────────────────────────────────────────────────────────┐
│                    CSI Architecture                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                 Kubernetes Layer                       │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │   kubelet   │    │ Controller  │    │   API       │ │ │
│  │  │             │───▶│  Manager    │───▶│  Server     │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                   CSI Interface                        │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │  Identity   │    │ Controller  │    │    Node     │ │ │
│  │  │   Service   │───▶│   Service   │───▶│   Service   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  CSI Driver                            │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │ Controller  │    │    Node     │    │   Storage   │ │ │
│  │  │   Plugin    │───▶│   Plugin    │───▶│   Backend   │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                              │
│                              ▼                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                Storage System                          │ │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐ │ │
│  │  │    NFS      │    │    iSCSI    │    │   Cloud     │ │ │
│  │  │             │───▶│             │───▶│  Storage    │ │ │
│  │  │             │    │             │    │             │ │ │
│  │  └─────────────┘    └─────────────┘    └─────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### 2. **CSI компоненты и их роли**
```yaml
# CSI Components Overview
csi_architecture:
  kubernetes_components:
    kubelet:
      responsibilities:
        - "Mount/unmount volumes"
        - "Node service calls"
        - "Volume staging/publishing"
        - "Health monitoring"
      
      interactions:
        - "CSI Node Plugin"
        - "Volume Manager"
        - "Device Manager"
    
    controller_manager:
      responsibilities:
        - "Volume provisioning"
        - "Volume attachment/detachment"
        - "Snapshot management"
        - "Volume expansion"
      
      interactions:
        - "CSI Controller Plugin"
        - "External Provisioner"
        - "External Attacher"
        - "External Snapshotter"
    
    api_server:
      responsibilities:
        - "CSI object management"
        - "Volume binding"
        - "Storage class handling"
        - "PVC/PV lifecycle"

  csi_interface:
    identity_service:
      purpose: "Plugin identification and capabilities"
      methods:
        - "GetPluginInfo"
        - "GetPluginCapabilities"
        - "Probe"
    
    controller_service:
      purpose: "Volume lifecycle management"
      methods:
        - "CreateVolume"
        - "DeleteVolume"
        - "ControllerPublishVolume"
        - "ControllerUnpublishVolume"
        - "ValidateVolumeCapabilities"
        - "ListVolumes"
        - "GetCapacity"
        - "CreateSnapshot"
        - "DeleteSnapshot"
        - "ExpandVolume"
    
    node_service:
      purpose: "Node-level volume operations"
      methods:
        - "NodeStageVolume"
        - "NodeUnstageVolume"
        - "NodePublishVolume"
        - "NodeUnpublishVolume"
        - "NodeGetVolumeStats"
        - "NodeExpandVolume"
        - "NodeGetCapabilities"
        - "NodeGetInfo"

  csi_driver_components:
    controller_plugin:
      deployment: "StatefulSet or Deployment"
      location: "Any node (usually master)"
      responsibilities:
        - "Volume provisioning"
        - "Snapshot management"
        - "Volume attachment"
        - "Capacity management"
    
    node_plugin:
      deployment: "DaemonSet"
      location: "Every node"
      responsibilities:
        - "Volume mounting"
        - "Local volume operations"
        - "Node registration"
        - "Health monitoring"
    
    sidecar_containers:
      external_provisioner:
        purpose: "Dynamic volume provisioning"
        watches: "PersistentVolumeClaims"
      
      external_attacher:
        purpose: "Volume attachment/detachment"
        watches: "VolumeAttachment objects"
      
      external_snapshotter:
        purpose: "Snapshot lifecycle management"
        watches: "VolumeSnapshot objects"
      
      external_resizer:
        purpose: "Volume expansion"
        watches: "PersistentVolumeClaims"
      
      node_driver_registrar:
        purpose: "Node plugin registration"
        location: "Each node"
      
      livenessprobe:
        purpose: "Health monitoring"
        function: "Plugin availability check"
```

### 📊 Примеры из нашего кластера

#### Проверка CSI драйверов:
```bash
# Проверка установленных CSI драйверов
kubectl get csidriver

# Проверка CSI nodes
kubectl get csinodes

# Проверка storage classes
kubectl get storageclass

# Проверка CSI pods
kubectl get pods --all-namespaces | grep csi

# Проверка volume attachments
kubectl get volumeattachments
```

### 🛠️ Создание CSI Driver

#### 1. **Базовая структура CSI Driver**
```go
// main.go - Entry point for CSI driver
package main

import (
    "context"
    "flag"
    "fmt"
    "os"
    "os/signal"
    "syscall"

    "github.com/container-storage-interface/spec/lib/go/csi"
    "google.golang.org/grpc"
    "k8s.io/klog/v2"
)

var (
    endpoint   = flag.String("endpoint", "unix:///var/lib/kubelet/plugins/example.csi.driver/csi.sock", "CSI endpoint")
    driverName = flag.String("drivername", "example.csi.driver", "name of the driver")
    nodeID     = flag.String("nodeid", "", "node id")
    version    = flag.String("version", "1.0.0", "driver version")
)

func main() {
    flag.Parse()
    
    if *nodeID == "" {
        klog.Error("nodeID must be provided")
        os.Exit(1)
    }

    // Create CSI driver
    driver := NewDriver(*driverName, *version, *nodeID)
    
    // Start server
    server := NewNonBlockingGRPCServer()
    server.Start(*endpoint, driver, driver, driver)
    server.Wait()
}

// Driver represents the CSI driver
type Driver struct {
    name    string
    version string
    nodeID  string
    
    // Add your storage backend client here
    // storageClient StorageClient
}

func NewDriver(name, version, nodeID string) *Driver {
    return &Driver{
        name:    name,
        version: version,
        nodeID:  nodeID,
    }
}

// Identity Service Implementation
func (d *Driver) GetPluginInfo(ctx context.Context, req *csi.GetPluginInfoRequest) (*csi.GetPluginInfoResponse, error) {
    return &csi.GetPluginInfoResponse{
        Name:          d.name,
        VendorVersion: d.version,
    }, nil
}

func (d *Driver) GetPluginCapabilities(ctx context.Context, req *csi.GetPluginCapabilitiesRequest) (*csi.GetPluginCapabilitiesResponse, error) {
    return &csi.GetPluginCapabilitiesResponse{
        Capabilities: []*csi.PluginCapability{
            {
                Type: &csi.PluginCapability_Service_{
                    Service: &csi.PluginCapability_Service{
                        Type: csi.PluginCapability_Service_CONTROLLER_SERVICE,
                    },
                },
            },
            {
                Type: &csi.PluginCapability_Service_{
                    Service: &csi.PluginCapability_Service{
                        Type: csi.PluginCapability_Service_VOLUME_ACCESSIBILITY_CONSTRAINTS,
                    },
                },
            },
        },
    }, nil
}

func (d *Driver) Probe(ctx context.Context, req *csi.ProbeRequest) (*csi.ProbeResponse, error) {
    return &csi.ProbeResponse{}, nil
}

// Controller Service Implementation
func (d *Driver) CreateVolume(ctx context.Context, req *csi.CreateVolumeRequest) (*csi.CreateVolumeResponse, error) {
    // Validate request
    if len(req.GetName()) == 0 {
        return nil, status.Error(codes.InvalidArgument, "Volume name missing in request")
    }
    
    if req.GetCapacityRange() == nil {
        return nil, status.Error(codes.InvalidArgument, "Capacity range missing in request")
    }

    // Create volume in your storage backend
    volumeID := fmt.Sprintf("vol-%s", req.GetName())
    size := req.GetCapacityRange().GetRequiredBytes()
    
    // Implementation specific: create volume in storage backend
    // err := d.storageClient.CreateVolume(volumeID, size)
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to create volume: %v", err)
    // }

    return &csi.CreateVolumeResponse{
        Volume: &csi.Volume{
            VolumeId:      volumeID,
            CapacityBytes: size,
            VolumeContext: req.GetParameters(),
        },
    }, nil
}

func (d *Driver) DeleteVolume(ctx context.Context, req *csi.DeleteVolumeRequest) (*csi.DeleteVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    if len(volumeID) == 0 {
        return nil, status.Error(codes.InvalidArgument, "Volume ID missing in request")
    }

    // Implementation specific: delete volume from storage backend
    // err := d.storageClient.DeleteVolume(volumeID)
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to delete volume: %v", err)
    // }

    return &csi.DeleteVolumeResponse{}, nil
}

func (d *Driver) ControllerPublishVolume(ctx context.Context, req *csi.ControllerPublishVolumeRequest) (*csi.ControllerPublishVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    nodeID := req.GetNodeId()
    
    if len(volumeID) == 0 {
        return nil, status.Error(codes.InvalidArgument, "Volume ID missing in request")
    }
    
    if len(nodeID) == 0 {
        return nil, status.Error(codes.InvalidArgument, "Node ID missing in request")
    }

    // Implementation specific: attach volume to node
    // publishContext, err := d.storageClient.AttachVolume(volumeID, nodeID)
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to attach volume: %v", err)
    // }

    return &csi.ControllerPublishVolumeResponse{
        PublishContext: map[string]string{
            "devicePath": "/dev/disk/by-id/example-" + volumeID,
        },
    }, nil
}

func (d *Driver) ControllerUnpublishVolume(ctx context.Context, req *csi.ControllerUnpublishVolumeRequest) (*csi.ControllerUnpublishVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    nodeID := req.GetNodeId()
    
    // Implementation specific: detach volume from node
    // err := d.storageClient.DetachVolume(volumeID, nodeID)
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to detach volume: %v", err)
    // }

    return &csi.ControllerUnpublishVolumeResponse{}, nil
}

// Node Service Implementation
func (d *Driver) NodeStageVolume(ctx context.Context, req *csi.NodeStageVolumeRequest) (*csi.NodeStageVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    stagingTargetPath := req.GetStagingTargetPath()
    
    if len(volumeID) == 0 {
        return nil, status.Error(codes.InvalidArgument, "Volume ID missing in request")
    }
    
    if len(stagingTargetPath) == 0 {
        return nil, status.Error(codes.InvalidArgument, "Staging target path missing in request")
    }

    // Implementation specific: stage volume (format, mount to staging path)
    devicePath := req.GetPublishContext()["devicePath"]
    
    // Format device if needed
    // err := d.formatDevice(devicePath, req.GetVolumeCapability().GetMount().GetFsType())
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to format device: %v", err)
    // }
    
    // Mount to staging path
    // err = d.mount(devicePath, stagingTargetPath, req.GetVolumeCapability().GetMount())
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to mount volume: %v", err)
    // }

    return &csi.NodeStageVolumeResponse{}, nil
}

func (d *Driver) NodeUnstageVolume(ctx context.Context, req *csi.NodeUnstageVolumeRequest) (*csi.NodeUnstageVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    stagingTargetPath := req.GetStagingTargetPath()
    
    // Implementation specific: unmount from staging path
    // err := d.unmount(stagingTargetPath)
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to unmount volume: %v", err)
    // }

    return &csi.NodeUnstageVolumeResponse{}, nil
}

func (d *Driver) NodePublishVolume(ctx context.Context, req *csi.NodePublishVolumeRequest) (*csi.NodePublishVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    targetPath := req.GetTargetPath()
    stagingTargetPath := req.GetStagingTargetPath()
    
    // Implementation specific: bind mount from staging to target path
    // err := d.bindMount(stagingTargetPath, targetPath, req.GetVolumeCapability().GetMount())
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to bind mount: %v", err)
    // }

    return &csi.NodePublishVolumeResponse{}, nil
}

func (d *Driver) NodeUnpublishVolume(ctx context.Context, req *csi.NodeUnpublishVolumeRequest) (*csi.NodeUnpublishVolumeResponse, error) {
    targetPath := req.GetTargetPath()
    
    // Implementation specific: unmount from target path
    // err := d.unmount(targetPath)
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to unmount: %v", err)
    // }

    return &csi.NodeUnpublishVolumeResponse{}, nil
}

func (d *Driver) NodeGetCapabilities(ctx context.Context, req *csi.NodeGetCapabilitiesRequest) (*csi.NodeGetCapabilitiesResponse, error) {
    return &csi.NodeGetCapabilitiesResponse{
        Capabilities: []*csi.NodeServiceCapability{
            {
                Type: &csi.NodeServiceCapability_Rpc{
                    Rpc: &csi.NodeServiceCapability_RPC{
                        Type: csi.NodeServiceCapability_RPC_STAGE_UNSTAGE_VOLUME,
                    },
                },
            },
            {
                Type: &csi.NodeServiceCapability_Rpc{
                    Rpc: &csi.NodeServiceCapability_RPC{
                        Type: csi.NodeServiceCapability_RPC_GET_VOLUME_STATS,
                    },
                },
            },
        },
    }, nil
}

func (d *Driver) NodeGetInfo(ctx context.Context, req *csi.NodeGetInfoRequest) (*csi.NodeGetInfoResponse, error) {
    return &csi.NodeGetInfoResponse{
        NodeId: d.nodeID,
    }, nil
}
```

#### 2. **Deployment манифесты**
```yaml
# csi-driver.yaml
apiVersion: storage.k8s.io/v1
kind: CSIDriver
metadata:
  name: example.csi.driver
spec:
  attachRequired: true
  podInfoOnMount: false
  volumeLifecycleModes:
  - Persistent
  - Ephemeral

---
# Controller Plugin Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: csi-controller
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: csi-controller
  template:
    metadata:
      labels:
        app: csi-controller
    spec:
      serviceAccountName: csi-controller-sa
      containers:
      - name: csi-provisioner
        image: k8s.gcr.io/sig-storage/csi-provisioner:v3.4.0
        args:
        - "--csi-address=$(ADDRESS)"
        - "--v=2"
        - "--feature-gates=Topology=true"
        - "--leader-election"
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        volumeMounts:
        - name: socket-dir
          mountPath: /var/lib/csi/sockets/pluginproxy/
      
      - name: csi-attacher
        image: k8s.gcr.io/sig-storage/csi-attacher:v4.1.0
        args:
        - "--v=2"
        - "--csi-address=$(ADDRESS)"
        - "--leader-election"
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        volumeMounts:
        - name: socket-dir
          mountPath: /var/lib/csi/sockets/pluginproxy/
      
      - name: csi-snapshotter
        image: k8s.gcr.io/sig-storage/csi-snapshotter:v6.2.1
        args:
        - "--v=2"
        - "--csi-address=$(ADDRESS)"
        - "--leader-election"
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        volumeMounts:
        - name: socket-dir
          mountPath: /var/lib/csi/sockets/pluginproxy/
      
      - name: csi-resizer
        image: k8s.gcr.io/sig-storage/csi-resizer:v1.7.0
        args:
        - "--v=2"
        - "--csi-address=$(ADDRESS)"
        - "--leader-election"
        env:
        - name: ADDRESS
          value: /var/lib/csi/sockets/pluginproxy/csi.sock
        volumeMounts:
        - name: socket-dir
          mountPath: /var/lib/csi/sockets/pluginproxy/
      
      - name: example-csi-driver
        image: example/csi-driver:v1.0.0
        args:
        - "--endpoint=$(CSI_ENDPOINT)"
        - "--nodeid=$(NODE_ID)"
        - "--drivername=example.csi.driver"
        env:
        - name: CSI_ENDPOINT
          value: unix:///var/lib/csi/sockets/pluginproxy/csi.sock
        - name: NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        volumeMounts:
        - name: socket-dir
          mountPath: /var/lib/csi/sockets/pluginproxy/
        securityContext:
          privileged: true
          capabilities:
            add: ["SYS_ADMIN"]
          allowPrivilegeEscalation: true
      
      volumes:
      - name: socket-dir
        emptyDir: {}

---
# Node Plugin DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: csi-node
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: csi-node
  template:
    metadata:
      labels:
        app: csi-node
    spec:
      serviceAccountName: csi-node-sa
      hostNetwork: true
      containers:
      - name: node-driver-registrar
        image: k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.7.0
        args:
        - "--v=2"
        - "--csi-address=$(ADDRESS)"
        - "--kubelet-registration-path=$(DRIVER_REG_SOCK_PATH)"
        env:
        - name: ADDRESS
          value: /csi/csi.sock
        - name: DRIVER_REG_SOCK_PATH
          value: /var/lib/kubelet/plugins/example.csi.driver/csi.sock
        - name: KUBE_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        volumeMounts:
        - name: plugin-dir
          mountPath: /csi/
        - name: registration-dir
          mountPath: /registration/
      
      - name: liveness-probe
        image: k8s.gcr.io/sig-storage/livenessprobe:v2.9.0
        args:
        - "--csi-address=$(ADDRESS)"
        env:
        - name: ADDRESS
          value: /csi/csi.sock
        volumeMounts:
        - name: plugin-dir
          mountPath: /csi/
      
      - name: example-csi-driver
        image: example/csi-driver:v1.0.0
        args:
        - "--endpoint=$(CSI_ENDPOINT)"
        - "--nodeid=$(NODE_ID)"
        - "--drivername=example.csi.driver"
        env:
        - name: CSI_ENDPOINT
          value: unix:///csi/csi.sock
        - name: NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        securityContext:
          privileged: true
          capabilities:
            add: ["SYS_ADMIN"]
          allowPrivilegeEscalation: true
        volumeMounts:
        - name: plugin-dir
          mountPath: /csi/
        - name: pods-mount-dir
          mountPath: /var/lib/kubelet
          mountPropagation: "Bidirectional"
        - name: device-dir
          mountPath: /dev
      
      volumes:
      - name: registration-dir
        hostPath:
          path: /var/lib/kubelet/plugins_registry/
          type: DirectoryOrCreate
      - name: plugin-dir
        hostPath:
          path: /var/lib/kubelet/plugins/example.csi.driver
          type: DirectoryOrCreate
      - name: pods-mount-dir
        hostPath:
          path: /var/lib/kubelet
          type: Directory
      - name: device-dir
        hostPath:
          path: /dev

---
# Storage Class
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: example-csi
provisioner: example.csi.driver
parameters:
  type: "fast"
  replication: "3"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete

---
# RBAC for Controller
apiVersion: v1
kind: ServiceAccount
metadata:
  name: csi-controller-sa
  namespace: kube-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: csi-controller-role
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["list", "watch", "create", "update", "patch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["volumeattachments"]
  verbs: ["get", "list", "watch", "update", "patch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["volumeattachments/status"]
  verbs: ["patch"]
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshots"]
  verbs: ["get", "list"]
- apiGroups: ["snapshot.storage.k8s.io"]
  resources: ["volumesnapshotcontents"]
  verbs: ["get", "list", "watch", "create", "delete", "update"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: csi-controller-binding
subjects:
- kind: ServiceAccount
  name: csi-controller-sa
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: csi-controller-role
  apiGroup: rbac.authorization.k8s.io

---
# RBAC for Node
apiVersion: v1
kind: ServiceAccount
metadata:
  name: csi-node-sa
  namespace: kube-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: csi-node-role
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: csi-node-binding
subjects:
- kind: ServiceAccount
  name: csi-node-sa
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: csi-node-role
  apiGroup: rbac.authorization.k8s.io
```

#### 3. **Тестирование CSI Driver**
```yaml
# test-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: example-csi

---
# test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test-container
    image: nginx
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: test-pvc
```

### 📈 Продвинутые возможности CSI

#### 1. **Volume Snapshots**
```yaml
# volume-snapshot-class.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: example-snapclass
driver: example.csi.driver
deletionPolicy: Delete
parameters:
  compression: "true"

---
# volume-snapshot.yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: test-snapshot
spec:
  volumeSnapshotClassName: example-snapclass
  source:
    persistentVolumeClaimName: test-pvc

---
# restore-from-snapshot.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: example-csi
  dataSource:
    name: test-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

#### 2. **Volume Cloning**
```yaml
# volume-clone.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cloned-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: example-csi
  dataSource:
    name: test-pvc
    kind: PersistentVolumeClaim
```

#### 3. **Volume Expansion**
```go
// Volume expansion implementation in CSI driver
func (d *Driver) ControllerExpandVolume(ctx context.Context, req *csi.ControllerExpandVolumeRequest) (*csi.ControllerExpandVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    if len(volumeID) == 0 {
        return nil, status.Error(codes.InvalidArgument, "Volume ID missing in request")
    }

    requiredBytes := req.GetCapacityRange().GetRequiredBytes()
    
    // Implementation specific: expand volume in storage backend
    // newSize, err := d.storageClient.ExpandVolume(volumeID, requiredBytes)
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to expand volume: %v", err)
    // }

    return &csi.ControllerExpandVolumeResponse{
        CapacityBytes:         requiredBytes,
        NodeExpansionRequired: true, // Set to true if filesystem expansion is needed
    }, nil
}

func (d *Driver) NodeExpandVolume(ctx context.Context, req *csi.NodeExpandVolumeRequest) (*csi.NodeExpandVolumeResponse, error) {
    volumeID := req.GetVolumeId()
    volumePath := req.GetVolumePath()
    
    // Implementation specific: expand filesystem
    // err := d.expandFilesystem(volumePath, req.GetVolumeCapability().GetMount().GetFsType())
    // if err != nil {
    //     return nil, status.Errorf(codes.Internal, "Failed to expand filesystem: %v", err)
    // }

    return &csi.NodeExpandVolumeResponse{
        CapacityBytes: req.GetCapacityRange().GetRequiredBytes(),
    }, nil
}
```

### 🔧 Утилиты для разработки CSI

#### Скрипт для тестирования CSI Driver:
```bash
#!/bin/bash
# csi-driver-test.sh

echo "🧪 CSI Driver Testing Suite"

# Test CSI driver functionality
test_csi_driver() {
    local driver_name=$1
    
    echo "=== Testing CSI Driver: $driver_name ==="
    
    # Check if driver is registered
    echo "--- Driver Registration ---"
    if kubectl get csidriver $driver_name >/dev/null 2>&1; then
        echo "✅ Driver registered"
        kubectl get csidriver $driver_name -o yaml
    else
        echo "❌ Driver not registered"
        return 1
    fi
    
    # Check controller plugin
    echo ""
    echo "--- Controller Plugin ---"
    controller_pods=$(kubectl get pods -n kube-system -l app=csi-controller --no-headers | wc -l)
    if [ "$controller_pods" -gt 0 ]; then
        echo "✅ Controller plugin running ($controller_pods pods)"
        kubectl get pods -n kube-system -l app=csi-controller
    else
        echo "❌ Controller plugin not running"
    fi
    
    # Check node plugin
    echo ""
    echo "--- Node Plugin ---"
    node_pods=$(kubectl get pods -n kube-system -l app=csi-node --no-headers | wc -l)
    expected_nodes=$(kubectl get nodes --no-headers | wc -l)
    if [ "$node_pods" -eq "$expected_nodes" ]; then
        echo "✅ Node plugin running on all nodes ($node_pods/$expected_nodes)"
    else
        echo "⚠️  Node plugin not running on all nodes ($node_pods/$expected_nodes)"
    fi
    
    # Check storage class
    echo ""
    echo "--- Storage Class ---"
    if kubectl get storageclass | grep $driver_name >/dev/null 2>&1; then
        echo "✅ Storage class available"
        kubectl get storageclass | grep $driver_name
    else
        echo "❌ Storage class not found"
    fi
}

# Test volume operations
test_volume_operations() {
    local storage_class=$1
    
    echo "=== Testing Volume Operations ==="
    
    # Create test PVC
    echo "--- Creating Test PVC ---"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-test-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: $storage_class
EOF

    # Wait for PVC to be bound
    echo "Waiting for PVC to be bound..."
    kubectl wait --for=condition=Bound pvc/csi-test-pvc --timeout=60s
    
    if [ $? -eq 0 ]; then
        echo "✅ PVC bound successfully"
        kubectl get pvc csi-test-pvc
    else
        echo "❌ PVC binding failed"
        kubectl describe pvc csi-test-pvc
        return 1
    fi
    
    # Create test pod
    echo ""
    echo "--- Creating Test Pod ---"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: csi-test-pod
spec:
  containers:
  - name: test-container
    image: busybox
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo \$(date) >> /data/test.log; sleep 30; done"]
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: csi-test-pvc
EOF

    # Wait for pod to be running
    echo "Waiting for pod to be running..."
    kubectl wait --for=condition=Ready pod/csi-test-pod --timeout=60s
    
    if [ $? -eq 0 ]; then
        echo "✅ Pod running successfully"
        kubectl get pod csi-test-pod
        
        # Test file operations
        echo ""
        echo "--- Testing File Operations ---"
        kubectl exec csi-test-pod -- ls -la /data/
        kubectl exec csi-test-pod -- cat /data/test.log | head -3
    else
        echo "❌ Pod failed to start"
        kubectl describe pod csi-test-pod
    fi
}

# Test snapshot operations
test_snapshot_operations() {
    local snapshot_class=$1
    
    echo "=== Testing Snapshot Operations ==="
    
    # Create volume snapshot
    echo "--- Creating Volume Snapshot ---"
    cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: csi-test-snapshot
spec:
  volumeSnapshotClassName: $snapshot_class
  source:
    persistentVolumeClaimName: csi-test-pvc
EOF

    # Wait for snapshot to be ready
    echo "Waiting for snapshot to be ready..."
    sleep 10
    
    snapshot_status=$(kubectl get volumesnapshot csi-test-snapshot -o jsonpath='{.status.readyToUse}')
    if [ "$snapshot_status" = "true" ]; then
        echo "✅ Snapshot created successfully"
        kubectl get volumesnapshot csi-test-snapshot
    else
        echo "❌ Snapshot creation failed"
        kubectl describe volumesnapshot csi-test-snapshot
    fi
}

# Test volume expansion
test_volume_expansion() {
    echo "=== Testing Volume Expansion ==="
    
    # Expand PVC
    echo "--- Expanding PVC ---"
    kubectl patch pvc csi-test-pvc -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
    
    # Wait for expansion
    echo "Waiting for volume expansion..."
    sleep 30
    
    # Check if expansion succeeded
    new_size=$(kubectl get pvc csi-test-pvc -o jsonpath='{.status.capacity.storage}')
    if [ "$new_size" = "2Gi" ]; then
        echo "✅ Volume expanded successfully to $new_size"
    else
        echo "❌ Volume expansion failed (current size: $new_size)"
    fi
}

# Cleanup test resources
cleanup_test_resources() {
    echo "=== Cleaning up Test Resources ==="
    
    kubectl delete pod csi-test-pod --ignore-not-found=true
    kubectl delete volumesnapshot csi-test-snapshot --ignore-not-found=true
    kubectl delete pvc csi-test-pvc --ignore-not-found=true
    
    echo "✅ Cleanup completed"
}

# Performance testing
performance_test() {
    local storage_class=$1
    
    echo "=== Performance Testing ==="
    
    # Create performance test pod
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: csi-perf-test
spec:
  containers:
  - name: fio
    image: ljishen/fio
    command: ["/bin/sh"]
    args: ["-c", "fio --name=test --ioengine=libaio --rw=randwrite --bs=4k --size=100M --numjobs=1 --runtime=60 --group_reporting --filename=/data/testfile"]
    volumeMounts:
    - name: test-volume
      mountPath: /data
  volumes:
  - name: test-volume
    persistentVolumeClaim:
      claimName: csi-perf-pvc
  restartPolicy: Never
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-perf-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: $storage_class
EOF

    # Wait for test completion
    echo "Running performance test..."
    kubectl wait --for=condition=Complete pod/csi-perf-test --timeout=120s
    
    if [ $? -eq 0 ]; then
        echo "✅ Performance test completed"
        kubectl logs csi-perf-test
    else
        echo "❌ Performance test failed"
    fi
    
    # Cleanup
    kubectl delete pod csi-perf-test --ignore-not-found=true
    kubectl delete pvc csi-perf-pvc --ignore-not-found=true
}

# Main execution
main() {
    local driver_name=${1:-"example.csi.driver"}
    local storage_class=${2:-"example-csi"}
    local snapshot_class=${3:-"example-snapclass"}
    
    echo "Testing CSI Driver: $driver_name"
    echo "Storage Class: $storage_class"
    echo "Snapshot Class: $snapshot_class"
    echo ""
    
    # Run tests
    test_csi_driver $driver_name
    echo ""
    
    test_volume_operations $storage_class
    echo ""
    
    if kubectl get volumesnapshotclass $snapshot_class >/dev/null 2>&1; then
        test_snapshot_operations $snapshot_class
        echo ""
    else
        echo "Skipping snapshot tests (snapshot class not found)"
        echo ""
    fi
    
    test_volume_expansion
    echo ""
    
    read -p "Run performance test? (y/n): " run_perf
    if [ "$run_perf" = "y" ]; then
        performance_test $storage_class
        echo ""
    fi
    
    read -p "Cleanup test resources? (y/n): " cleanup
    if [ "$cleanup" = "y" ]; then
        cleanup_test_resources
    fi
}

# Check if arguments provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <driver-name> [storage-class] [snapshot-class]"
    echo "Example: $0 example.csi.driver example-csi example-snapclass"
    echo ""
    echo "Running with default values..."
    main
else
    main "$@"
fi
```

### 🎯 Заключение

CSI (Container Storage Interface) обеспечивает стандартизированный способ интеграции систем хранения с Kubernetes:

**Ключевые компоненты:**
1. **Identity Service** - идентификация и возможности драйвера
2. **Controller Service** - управление жизненным циклом томов
3. **Node Service** - операции на уровне узлов

**Архитектура развертывания:**
1. **Controller Plugin** - централизованное управление (Deployment)
2. **Node Plugin** - локальные операции (DaemonSet)
3. **Sidecar Containers** - интеграция с Kubernetes API

**Продвинутые возможности:**
1. **Volume Snapshots** - создание снимков томов
2. **Volume Cloning** - клонирование существующих томов
3. **Volume Expansion** - динамическое расширение томов
4. **Topology Awareness** - учет топологии при размещении

**Преимущества CSI:**
- **Стандартизация** - единый интерфейс для всех систем хранения
- **Портабельность** - драйверы работают с любой CSI-совместимой системой
- **Расширяемость** - легкое добавление новых возможностей
- **Изоляция** - независимая разработка и обновление драйверов

CSI значительно упрощает интеграцию систем хранения с Kubernetes и обеспечивает богатую функциональность для управления данными в контейнерных средах.

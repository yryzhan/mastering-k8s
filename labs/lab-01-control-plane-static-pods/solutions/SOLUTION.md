# Lab 01 Solution Guide

## The Nginx Deployment Actually Works

When you deploy the nginx deployment after setting up the control plane with static pods, **it works successfully**! All 3 pods are running and have IP addresses assigned.

## Why It Works

### CNI Plugin Already Configured

The `setup-lab01.sh` script automatically configured a **basic CNI plugin** during the setup process:

**Configuration File**: `/etc/cni/net.d/10-mynet.conf`

```json
{
    "cniVersion": "0.3.1",
    "name": "mynet",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "subnet": "10.22.0.0/16",
        "routes": [
            { "dst": "0.0.0.0/0" }
        ]
    }
}
```

### What This Configuration Provides

1. **Bridge CNI Plugin**
   - Creates a Linux bridge (`cni0`) on the host
   - Connects pod network namespaces to the bridge
   - Enables pod-to-pod communication on the same node

2. **IPAM (IP Address Management)**
   - Uses `host-local` plugin for IP allocation
   - Assigns IPs from subnet `10.22.0.0/16`
   - Your nginx pods get IPs: `10.22.0.4`, `10.22.0.5`, `10.22.0.6`

3. **Network Features**
   - `isGateway: true` - Bridge acts as default gateway for pods
   - `ipMasq: true` - Enables IP masquerading (NAT) for external traffic
   - Default route configured for outbound connectivity

### Verification

```bash
# Check CNI configuration
$ ls /etc/cni/net.d/
10-mynet.conf

# Check bridge interface
$ ip a show cni0
5: cni0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    inet 10.22.0.1/16 brd 10.22.255.255 scope global cni0

# Check pod IPs
$ kubectl get pods -o wide
NAME                          READY   STATUS    RESTARTS   AGE   IP
nginx-demo-7b6574896c-d5gc7   1/1     Running   0          4m    10.22.0.6
nginx-demo-7b6574896c-vl8lv   1/1     Running   0          4m    10.22.0.5
nginx-demo-7b6574896c-vqcrx   1/1     Running   0          4m    10.22.0.4

# Test connectivity
$ curl http://10.22.0.6
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

## What's Still Missing (Optional Components)

While the basic networking works, you might want to add:

### 1. **kube-proxy** (For Service Load Balancing)
   - Not installed by default
   - Required for ClusterIP service routing
   - Needed for service discovery via iptables/IPVS rules

### 2. **CoreDNS** (For DNS Resolution)
   - Not installed by default
   - Required for service discovery by name
   - Pods cannot resolve `service-name.namespace.svc.cluster.local`

### 3. **Advanced CNI** (For Multi-Node Clusters)
   - Current setup works for single-node
   - For multi-node clusters, consider:
     - **Calico** - for network policies
     - **Flannel** - for overlay networking
     - **Weave** - for mesh networking

## How The Setup Script Configured Networking

The `setup-lab01.sh` script automatically configured basic networking through these steps:

### 1. **Downloaded CNI Plugins**

```bash
# Script downloads and installs CNI plugins to /opt/cni/bin/
wget https://github.com/containernetworking/plugins/releases/download/v1.6.2/cni-plugins-linux-amd64-v1.6.2.tgz
tar zxf cni-plugins.tgz -C /opt/cni/bin/
```

**Available plugins**:
- `bridge` - Creates L2 bridge for pod connectivity
- `host-local` - IPAM for IP address allocation
- `loopback` - Loopback interface for containers
- `portmap` - Port forwarding
- And more...

### 2. **Created CNI Configuration**

```bash
# Script creates /etc/cni/net.d/10-mynet.conf
cat <<EOF > /etc/cni/net.d/10-mynet.conf
{
    "cniVersion": "0.3.1",
    "name": "mynet",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "subnet": "10.22.0.0/16",
        "routes": [
            { "dst": "0.0.0.0/0" }
        ]
    }
}
EOF
```

### 3. **Configured Kubelet for CNI**

```bash
# In kubelet config, the script specifies CNI paths:
kubelet \
  --network-plugin=cni \
  --cni-conf-dir=/etc/cni/net.d \
  --cni-bin-dir=/opt/cni/bin \
  ...
```

### 4. **Result: Automatic Pod Networking**

When a pod is created:
1. Kubelet calls CNI plugin with pod info
2. Bridge plugin creates veth pair
3. One end goes to pod namespace, other to cni0 bridge
4. IPAM plugin assigns IP from 10.22.0.0/16
5. Pod gets network connectivity automatically!

## Key Learnings

1. **CNI is Essential for Pod Networking**
   - Without CNI, pods remain in `ContainerCreating` state
   - Basic bridge CNI is sufficient for single-node clusters
   - Production clusters typically use more sophisticated CNI solutions

2. **Component Roles**:
   - **Control plane components** use host networking (`hostNetwork: true`)
   - **Application pods** need CNI for isolated network namespaces
   - **kube-proxy** is optional if you don't use Services
   - **CoreDNS** is optional if you don't need DNS resolution

3. **Network Architecture**:
   ```
   ┌─────────────────────────────────────────┐
   │ Host Network (10.0.12.103)              │
   ├─────────────────────────────────────────┤
   │ cni0 Bridge (10.22.0.1/16)              │
   │   ├── veth-pod1 ← → Pod1 (10.22.0.4)    │
   │   ├── veth-pod2 ← → Pod2 (10.22.0.5)    │
   │   └── veth-pod3 ← → Pod3 (10.22.0.6)    │
   └─────────────────────────────────────────┘
   ```

4. **Bootstrap Order in This Lab**:
   - Control plane components first (with hostNetwork)
   - CNI configuration automatically included in setup
   - Application workloads work immediately!

## Verification Commands

```bash
# Check all pods are running
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                                        READY   STATUS    RESTARTS   AGE
default       nginx-demo-7b6574896c-d5gc7                 1/1     Running   0          5m
default       nginx-demo-7b6574896c-vl8lv                 1/1     Running   0          5m
default       nginx-demo-7b6574896c-vqcrx                 1/1     Running   0          5m
kube-system   etcd-codespaces-3ef4e8                      1/1     Running   0          15m
kube-system   kube-apiserver-codespaces-3ef4e8            1/1     Running   0          15m
kube-system   kube-controller-manager-codespaces-3ef4e8   1/1     Running   0          15m
kube-system   kube-scheduler-codespaces-3ef4e8            1/1     Running   0          15m

# Check node is Ready
$ kubectl get nodes
NAME                STATUS   ROLES    AGE   VERSION
codespaces-3ef4e8   Ready    <none>   16m   v1.30.0

# Verify CNI configuration exists
$ ls /etc/cni/net.d/
10-mynet.conf

# Check CNI bridge interface
$ ip a show cni0
5: cni0: <BROADCAST,MULTICAST,UP,LOWER_UP>
    inet 10.22.0.1/16 scope global cni0

# Test pod connectivity directly
$ POD_IP=$(kubectl get pod -o jsonpath='{.items[0].status.podIP}')
$ curl http://$POD_IP
<!DOCTYPE html>
<html>
<head><title>Welcome to nginx!</title>

# Check pod can reach other pods
$ kubectl exec nginx-demo-7b6574896c-d5gc7 -- ping -c 1 10.22.0.5
PING 10.22.0.5 (10.22.0.5): 56 data bytes
64 bytes from 10.22.0.5: seq=0 ttl=64 time=0.123 ms

# Verify CNI plugins are available
$ ls /opt/cni/bin/
bandwidth  bridge  dhcp  firewall  host-device  host-local  ipvlan  loopback  macvlan  portmap  ...
```

## Enabling Service Networking with kube-proxy

### Why Services Don't Work Initially

After deploying nginx, you can create a Service, but it won't route traffic:

```bash
# Create a service
$ kubectl expose deployment nginx-demo --port=80 --type=ClusterIP
service/nginx-demo created

# Check the service (gets a ClusterIP but won't route without kube-proxy)
$ kubectl get svc nginx-demo
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
nginx-demo   ClusterIP   10.0.0.165   <none>        80/TCP    5s

# This won't work because kube-proxy is not running:
$ curl http://10.0.0.165
# Connection timeout (iptables rules don't exist)

# But direct pod IP works:
$ curl http://10.22.0.6
<!DOCTYPE html><html>... ✅ Works!
```

### Solution: Deploy kube-proxy

Deploy kube-proxy as a DaemonSet to create iptables rules for service routing:

```bash
# Deploy kube-proxy
$ kubectl apply -f labs/lab-01-control-plane-static-pods/manifests/kube-proxy-daemonset.yaml
serviceaccount/kube-proxy created
clusterrolebinding.rbac.authorization.k8s.io/kube-proxy created
configmap/kube-proxy created
daemonset.apps/kube-proxy created

# Verify kube-proxy is running
$ kubectl get pods -n kube-system -l k8s-app=kube-proxy
NAME               READY   STATUS    RESTARTS   AGE
kube-proxy-vpwc8   1/1     Running   0          30s

# Check iptables rules were created
$ sudo iptables -t nat -L KUBE-SERVICES
Chain KUBE-SERVICES (2 references)
target     prot opt source               destination         
KUBE-SVC-NPX46M4PTMTKRN6Y  tcp  --  anywhere  10.0.0.1      /* default/kubernetes:https */
KUBE-SVC-2ZZBI6IPY23MEJHC  tcp  --  anywhere  10.0.0.165    /* default/nginx-demo */

# Now service ClusterIP works!
$ curl http://10.0.0.165
<!DOCTYPE html><html>... ✅ Works!
```

### What kube-proxy Provides

1. **Service Load Balancing**
   - Routes ClusterIP traffic to backend pods
   - Distributes requests across all replicas
   - Updates iptables rules automatically

2. **iptables Rules Management**
   ```
   ClusterIP (10.0.0.165:80)
        ↓ (iptables DNAT)
        ├─→ Pod 1 (10.22.0.4:80)  33% traffic
        ├─→ Pod 2 (10.22.0.5:80)  33% traffic
        └─→ Pod 3 (10.22.0.6:80)  33% traffic
   ```

3. **Service Discovery Integration**
   - Watches API server for Service changes
   - Automatically updates routing rules
   - Enables service-to-service communication

### Verification After kube-proxy

```bash
# Test service is working
$ kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
nginx-demo   ClusterIP   10.0.0.165   <none>        80/TCP    5m

# Access via ClusterIP (load balanced across all pods)
$ for i in {1..10}; do curl -s http://10.0.0.165 | grep title; done
<title>Welcome to nginx!</title>
<title>Welcome to nginx!</title>
... (requests distributed across all 3 pods)

# All components now working:
$ kubectl get pods -A
NAMESPACE     NAME                                        READY   STATUS    RESTARTS   AGE
default       nginx-demo-7b6574896c-d5gc7                 1/1     Running   0          10m
default       nginx-demo-7b6574896c-vl8lv                 1/1     Running   0          10m
default       nginx-demo-7b6574896c-vqcrx                 1/1     Running   0          10m
kube-system   etcd-codespaces-3ef4e8                      1/1     Running   0          20m
kube-system   kube-apiserver-codespaces-3ef4e8            1/1     Running   0          20m
kube-system   kube-controller-manager-codespaces-3ef4e8   1/1     Running   0          20m
kube-system   kube-proxy-vpwc8                            1/1     Running   0          2m
kube-system   kube-scheduler-codespaces-3ef4e8            1/1     Running   0          20m
```

## Common Pitfalls to Avoid

1. **Forgetting CNI plugins directory**
   - Kubelet needs `--cni-bin-dir=/opt/cni/bin`
   - Without it, kubelet can't invoke CNI plugins

2. **Missing CNI configuration**
   - At least one config file must exist in `/etc/cni/net.d/`
   - File must be valid JSON with proper CNI version

3. **Using wrong subnet**
   - Ensure pod CIDR doesn't conflict with host network
   - In this lab: Host is 10.0.x.x, Pods are 10.22.x.x ✓

4. **Assuming DNS works**
   - Basic CNI doesn't include DNS
   - Pods can communicate by IP but not by service name
   - Need CoreDNS for DNS resolution

## Complete Architecture Overview

### Final System Components

After completing all steps, your cluster has:

```
┌─────────────────────────────────────────────────────────┐
│                    Control Plane                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Static Pods (hostNetwork: true)                   │  │
│  │  • etcd (data store)                              │  │
│  │  • kube-apiserver (API server)                    │  │
│  │  • kube-scheduler (pod scheduling)                │  │
│  │  • kube-controller-manager (controllers)          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                  Networking Layer                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │ CNI (Container Network Interface)                 │  │
│  │  • bridge plugin → cni0 bridge                    │  │
│  │  • host-local IPAM → 10.22.0.0/16                 │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │ kube-proxy DaemonSet                              │  │
│  │  • iptables rules for Services                    │  │
│  │  • ClusterIP load balancing                       │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│                 Application Layer                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │ nginx-demo Deployment (3 replicas)                │  │
│  │  • Pod 1: 10.22.0.4                               │  │
│  │  • Pod 2: 10.22.0.5                               │  │
│  │  • Pod 3: 10.22.0.6                               │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │ nginx-demo Service                                 │  │
│  │  • ClusterIP: 10.0.0.165:80                       │  │
│  │  • Load balances to all 3 pods                    │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### What Each Component Does

| Component | Purpose | Network Mode | Required? |
|-----------|---------|--------------|-----------|
| **etcd** | Key-value store for cluster data | Host network | ✅ Essential |
| **kube-apiserver** | API server, central hub | Host network | ✅ Essential |
| **kube-scheduler** | Schedules pods to nodes | Host network | ✅ Essential |
| **kube-controller-manager** | Runs controllers | Host network | ✅ Essential |
| **CNI (bridge)** | Pod-to-pod networking | N/A | ✅ Essential for app pods |
| **kube-proxy** | Service load balancing | Host network | ⚠️ Optional (needed for Services) |
| **CoreDNS** | DNS resolution | Pod network | ⚠️ Optional (needed for DNS) |

### Traffic Flow Examples

#### Pod-to-Pod Communication (via CNI)
```
nginx-pod-1 (10.22.0.4)
    ↓ (veth pair)
cni0 bridge (10.22.0.1)
    ↓ (veth pair)
nginx-pod-2 (10.22.0.5)
```

#### Service Communication (via kube-proxy)
```
Client Request → ClusterIP (10.0.0.165:80)
    ↓ (iptables DNAT rule)
Random Pod Selection (10.22.0.4 OR 10.22.0.5 OR 10.22.0.6)
    ↓ (direct connection)
Response from selected pod
```

## Summary: Complete Kubernetes Cluster

You've successfully built a **fully functional Kubernetes cluster** with:

✅ **Control Plane**: All components running as static pods  
✅ **Pod Networking**: CNI bridge plugin for pod-to-pod communication  
✅ **Service Networking**: kube-proxy for ClusterIP load balancing  
✅ **Working Application**: nginx deployment with 3 replicas  
✅ **Service Discovery**: ClusterIP service routing traffic to pods  

### What's Still Optional

- **CoreDNS**: For DNS-based service discovery (`nginx-demo.default.svc.cluster.local`)
- **Ingress Controller**: For external HTTP/HTTPS access
- **Network Policies**: For pod-to-pod traffic restrictions (requires CNI support)
- **Storage Plugins**: For persistent volume management

This lab demonstrates the **minimal working Kubernetes cluster** - everything you need to run containerized applications with networking and service discovery!

## Additional Resources

- [Kubernetes Networking Model](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [CNI Specification](https://github.com/containernetworking/cni)
- [kube-proxy Reference](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

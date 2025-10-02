# Lab 01 Solution Guide

## Problem Analysis

When you deploy the nginx deployment after setting up the control plane with static pods, it doesn't work because:

### Missing Components

1. **No CNI (Container Network Interface) Plugin**
   - Pods cannot communicate with each other
   - No pod networking is configured
   - Pods remain in `ContainerCreating` or `Pending` state

2. **No kube-proxy**
   - Service networking doesn't work
   - ClusterIP services cannot route traffic
   - No iptables rules for service discovery

3. **No CoreDNS**
   - DNS resolution inside pods fails
   - Service discovery by name doesn't work

## Solution

To fix the deployment, you need to install:

### 1. Install CNI Plugin

Choose one of the following:

**Option A: Calico**

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

**Option B: Flannel**

```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

**Option C: Weave Net**

```bash
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```

### 2. Deploy kube-proxy

kube-proxy can be deployed as a DaemonSet:

```bash
kubectl apply -f kube-proxy-daemonset.yaml
```

### 3. Deploy CoreDNS

```bash
kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns-1.8.yaml
```

## Step-by-Step Fix

1. **Verify control plane is running:**

   ```bash
   kubectl get pods -n kube-system
   kubectl get cs  # Check component status
   ```

2. **Install CNI plugin first:**

   ```bash
   kubectl apply -f <your-chosen-cni-plugin>
   ```

3. **Verify CNI is working:**

   ```bash
   kubectl get pods -n kube-system
   # Check that CNI pods are running
   ```

4. **Deploy your application:**

   ```bash
   kubectl apply -f nginx-deployment.yaml
   ```

5. **Verify pods are now running:**

   ```bash
   kubectl get pods
   kubectl describe pod <nginx-pod-name>
   ```

## Key Learnings

1. **Static Pods Limitation**: Static pods are great for control plane components but require additional networking setup for application workloads

2. **Component Dependencies**:
   - Control plane components can run without CNI
   - Application pods require CNI for networking
   - Services require kube-proxy for routing

3. **Bootstrap Order**:
   - Control plane first
   - CNI plugin second
   - Application workloads last

## Verification Commands

```bash
# Check all pods
kubectl get pods --all-namespaces

# Check node status
kubectl get nodes

# Verify CNI configuration
ls /etc/cni/net.d/

# Test pod networking
kubectl run test --image=busybox --command -- sleep 3600
kubectl exec -it test -- ping <another-pod-ip>

# Test DNS
kubectl exec -it test -- nslookup kubernetes.default
```

## Common Mistakes

1. Deploying applications before CNI
2. Forgetting to configure pod CIDR
3. Not deploying kube-proxy
4. Missing CoreDNS for service discovery

## Additional Resources

- [Kubernetes Networking Model](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- [CNI Specification](https://github.com/containernetworking/cni)
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)


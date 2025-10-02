# Lab 02 Manifests

This directory contains Kubernetes manifest files for Lab 02: Profiling kube-apiserver.

## Contents

### `debug-profiler.yaml`

A privileged pod for profiling the kube-apiserver using `perf` tools.

**Features:**
- Privileged access to host processes (`hostPID: true`)
- Host network access for direct API server access
- Mounted `/sys` and `/sys/kernel/debug` for perf profiling
- Pre-installed profiling tools (perf, FlameGraph scripts)
- Results directory mounted at `/results` (maps to `/tmp/profiling-results` on host)

**Usage:**

```bash
# Deploy the debug profiler
sudo kubebuilder/bin/kubectl apply -f manifests/debug-profiler.yaml

# Wait for pod to be ready
sudo kubebuilder/bin/kubectl wait --for=condition=Ready pod/debug-profiler --timeout=60s

# Exec into the pod
sudo kubebuilder/bin/kubectl exec -it debug-profiler -- /bin/sh

# Inside the pod, find kube-apiserver PID
ps aux | grep kube-apiserver | grep -v grep

# Start profiling (replace <PID> with actual PID)
/app/perf record -F 99 -g -p <PID> -o /results/perf.data sleep 30

# Generate flame graph
cd /results
/app/perf script -i perf.data | /app/FlameGraph/stackcollapse-perf.pl | /app/FlameGraph/flamegraph.pl > flame.svg

# Exit the pod
exit

# Results are available on the host at /tmp/profiling-results/
# (The /results directory in the container is mounted to /tmp/profiling-results on the host)
ls -la /tmp/profiling-results/
```

### `static-pods/`

Contains static pod manifests for the control plane components:
- `etcd.yaml` - etcd data store
- `kube-apiserver.yaml` - Kubernetes API server
- `kube-scheduler.yaml` - Pod scheduler
- `kube-controller-manager.yaml` - Controller manager

These are automatically deployed by the `setup-lab02.sh` script.

## Security Considerations

⚠️ **Warning**: The debug-profiler pod runs in **privileged mode** and has access to:
- All host processes (`hostPID: true`)
- Host network (`hostNetwork: true`)
- System debugging interfaces (`/sys/kernel/debug`)

This is intentional for profiling purposes but should **NEVER** be used in production environments.

## Cleanup

```bash
# Delete the debug profiler pod
sudo kubebuilder/bin/kubectl delete pod debug-profiler

# Clean up results directory
sudo rm -rf /tmp/profiling-results
```


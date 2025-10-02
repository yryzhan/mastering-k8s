# Lab 02 Solution Guide

## Complete Step-by-Step Solution

### Step 1: Verify Control Plane

```bash
# Check that kube-apiserver is running
kubectl get pods -n kube-system | grep apiserver

# Or if using static pods
ps aux | grep kube-apiserver
```

### Step 2: Deploy Debug Container

Create a privileged debug container:

```bash
kubectl run debug-profiler \
  --image=verizondigital/kubectl-flame:v0.2.4-perf \
  --privileged=true \
  --restart=Never \
  --overrides='
{
  "spec": {
    "hostPID": true,
    "hostNetwork": true,
    "containers": [{
      "name": "debug-profiler",
      "image": "verizondigital/kubectl-flame:v0.2.4-perf",
      "command": ["sleep", "infinity"],
      "securityContext": {
        "privileged": true
      },
      "volumeMounts": [{
        "name": "sys",
        "mountPath": "/sys"
      }]
    }],
    "volumes": [{
      "name": "sys",
      "hostPath": {
        "path": "/sys"
      }
    }]
  }
}'
```

### Step 3: Find API Server PID

```bash
# Exec into the debug container (note: use /bin/sh not /bin/bash)
kubectl exec -it debug-profiler -- /bin/sh

# Inside container, find kube-apiserver PID
ps aux | grep kube-apiserver | grep -v grep

# Alternative method using pgrep
APISERVER_PID=$(pgrep -f kube-apiserver)
echo $APISERVER_PID
```

### Step 4: Generate Load (Optional but Recommended)

Before profiling, generate some load to make the results more interesting:

```bash
# In a separate terminal, generate API load
for i in {1..100}; do
  kubectl get pods --all-namespaces &
  kubectl get nodes &
  kubectl get services --all-namespaces &
done

# Or use a continuous load generator
while true; do
  kubectl get pods --all-namespaces > /dev/null 2>&1
  kubectl get nodes > /dev/null 2>&1
  sleep 0.1
done
```

### Step 5: Collect Performance Samples

```bash
# Inside the debug container
# Record for 30 seconds with 99 samples per second
/app/perf record -F 99 -g -p $APISERVER_PID -o /results/out.perf sleep 30

# The output file will be saved as /results/out.perf (accessible on host at /tmp/profiling-results/)
```

**Note**: If you see "Permission denied", ensure:

- Container is running with `privileged: true`
- `hostPID: true` is set
- You have access to `/sys` filesystem

### Step 6: Generate Flame Graph

```bash
# Still inside the debug container
# Install FlameGraph if not already present
if [ ! -d "/FlameGraph" ]; then
  git clone https://github.com/brendangregg/FlameGraph.git /FlameGraph
fi

# Generate the flame graph
/app/perf script -i /results/out.perf | \
  /app/FlameGraph/stackcollapse-perf.pl | \
  /app/FlameGraph/flamegraph.pl > /results/flame.svg

# Verify the file was created
ls -lh /results/flame.svg

# Files are accessible on the host at:
# /tmp/profiling-results/out.perf
# /tmp/profiling-results/flame.svg
```

### Step 7: Copy Flame Graph to Local Machine

```bash
# Exit the container
exit

# The flame graph is already accessible on the host at /tmp/profiling-results/
# Copy it to your lab results directory
sudo cp /tmp/profiling-results/flame.svg ./labs/lab-02-profiling-apiserver/results/

# Verify the file
ls -lh ./labs/lab-02-profiling-apiserver/results/flame.svg
```

### Step 8: View and Analyze

Open `flame.svg` in a web browser:

```bash
# On Linux
xdg-open ./labs/lab-02-profiling-apiserver/results/flame.svg

# On macOS
open ./labs/lab-02-profiling-apiserver/results/flame.svg

# On Windows
start ./labs/lab-02-profiling-apiserver/results/flame.svg

# Or view directly from the host directory
xdg-open /tmp/profiling-results/flame.svg
```

## Understanding the Flame Graph

### How to Read It

- **Width**: CPU time (wider = more CPU time)
- **Height**: Stack depth (call stack)
- **Color**: Usually random (helps distinguish adjacent frames)
- **Bottom to Top**: Call stack from parent to child functions

### What to Look For

1. **Wide Towers**: Functions consuming the most CPU time
2. **Authentication/Authorization**: Usually visible in API server profiles
3. **JSON Encoding/Decoding**: Common hot path
4. **Watch Operations**: Can be expensive
5. **Admission Controllers**: Add overhead to requests

### Common Patterns in kube-apiserver

- **`*authentication*`**: Time spent authenticating requests
- **`*authorization*`**: RBAC checks
- **`*json*` or `*proto*`**: Serialization/deserialization
- **`*etcd*`**: Time spent communicating with etcd
- **`*http*`**: HTTP request processing

## Analysis Questions and Answers

### Q1: What are the hottest code paths?

Look for the widest sections at the top of the graph. Common hot paths include:

- HTTP request handling
- JSON marshaling/unmarshaling
- RBAC authorization checks
- etcd operations

### Q2: What percentage is spent on auth?

Search for authentication and authorization frames. Typically:

- Authentication: 5-15% of CPU time
- Authorization: 10-20% of CPU time
- Can be higher with complex RBAC policies

### Q3: Are there optimization opportunities?

Look for:

- Repeated operations that could be cached
- Expensive operations in hot paths
- Inefficient algorithms (wide, flat sections)

## Troubleshooting

### Problem: "perf: Permission denied"

**Solution:**

```bash
# Ensure container has proper permissions
kubectl delete pod debug-profiler
kubectl run debug-profiler \
  --image=verizondigital/kubectl-flame:v0.2.4-perf \
  --privileged=true \
  --restart=Never \
  --overrides='{"spec":{"hostPID":true,"hostNetwork":true}}'
```

### Problem: "perf not found"

**Solution:**

```bash
# Install perf inside container
apt-get update && apt-get install -y linux-tools-generic

# Or use a different base image with perf pre-installed
```

### Problem: "Cannot find kube-apiserver PID"

**Solution:**

```bash
# Ensure hostPID is enabled
# Check if running in host PID namespace
ps aux | grep apiserver

# If still not visible, try
docker ps | grep apiserver
# Then docker inspect to find PID
```

### Problem: "Empty or corrupted flame.svg"

**Solution:**

```bash
# Check if perf data was collected
perf report -i /tmp/out.perf

# Verify FlameGraph scripts are executable
chmod +x /FlameGraph/*.pl

# Try generating again step by step
/app/perf script -i /results/out.perf > /results/out.stacks
/app/FlameGraph/stackcollapse-perf.pl /results/out.stacks > /results/out.folded
/app/FlameGraph/flamegraph.pl /results/out.folded > /results/flame.svg
```

## Advanced Options

### Higher Resolution Profiling

```bash
# Increase sampling frequency to 999 Hz
/app/perf record -F 999 -g -p $APISERVER_PID -o /results/out.perf sleep 30
```

### Profile Specific Events

```bash
# Profile CPU cycles
/app/perf record -e cycles -g -p $APISERVER_PID -o /results/cycles.perf sleep 30

# Profile cache misses
/app/perf record -e cache-misses -g -p $APISERVER_PID -o /results/cache.perf sleep 30

# Profile context switches
/app/perf record -e context-switches -g -p $APISERVER_PID -o /results/cs.perf sleep 30
```

### Differential Profiling

```bash
# Profile under no load
/app/perf record -F 99 -g -p $APISERVER_PID -o /results/idle.perf sleep 30

# Profile under high load
# (start load generator first)
/app/perf record -F 99 -g -p $APISERVER_PID -o /results/load.perf sleep 30

# Compare the two flame graphs
# All files accessible on host at /tmp/profiling-results/
```

## Cleanup

```bash
# Delete the debug container
kubectl delete pod debug-profiler

# Remove temporary files if needed
sudo rm -rf /tmp/profiling-results/
```

## Additional Resources

- [Linux perf Tutorial](http://www.brendangregg.com/perf.html)
- [Flame Graph Documentation](http://www.brendangregg.com/flamegraphs.html)
- [Kubernetes Profiling](https://kubernetes.io/blog/2019/05/14/Kubernetes-1.15-Profiling-Kubernetes/)
- [kubectl-flame GitHub](https://github.com/VerizonMedia/kubectl-flame)

## Key Takeaways

1. **Privileged Access Required**: System-level profiling requires privileged containers
2. **Host PID Namespace**: Essential for seeing host processes from container
3. **Load Matters**: Profiling under load gives more interesting results
4. **Flame Graphs**: Excellent tool for visualizing CPU performance
5. **API Server Optimization**: Understanding hot paths helps with optimization


# Lab 02: Profiling kube-apiserver

**Difficulty Level:** Advanced

## Lab Agenda & Task Checklist

### ⏰ **Estimated Time:** 3-4 hours

### 📋 **Task Overview:**
> **Goal:** Profile the kube-apiserver using performance analysis tools and generate flame graphs to identify performance bottlenecks

#### **🎯 Tasks to Complete:**

- [ ] **Step 1: Deploy Control Plane**
  - [ ] Ensure working Kubernetes control plane (Lab 01, kubeadm, kind, or minikube)
  - [ ] Verify API server is running and accessible
  - [ ] Test `kubectl` connectivity

- [ ] **Step 2: Create Debug Container**
  - [ ] Deploy privileged debug container with kubectl-flame image
  - [ ] Verify container has host access and perf tools
  - [ ] Test perf command availability

- [ ] **Step 3: Profile kube-apiserver**
  - [ ] **🔍 FIND:** Identify kube-apiserver PID on host
  - [ ] **📊 COLLECT:** Run perf record for 30 seconds (`perf record -F 99 -g -p <PID>`)
  - [ ] **⚡ GENERATE LOAD:** Run API calls during profiling
  - [ ] Verify perf data was collected successfully

- [ ] **Step 4: Generate Flame Graph**
  - [ ] **🔄 PROCESS:** Convert perf data using stackcollapse-perf.pl
  - [ ] **🔥 GENERATE:** Create flame.svg using flamegraph.pl
  - [ ] **📤 EXPORT:** Copy flame.svg from container to local repository
  - [ ] Save in `results/` directory

- [ ] **Step 5: Analysis & Interpretation**
  - [ ] **📈 ANALYZE:** Identify hottest code paths in flame graph
  - [ ] **🎯 IDENTIFY:** Functions consuming most CPU time
  - [ ] **🕵️ INVESTIGATE:** Look for unexpected performance patterns
  - [ ] **📝 DOCUMENT:** Write analysis findings

#### **🎯 Bonus Challenges:**
- [ ] Compare flame graphs under different load patterns
- [ ] Profile with and without authentication load
- [ ] Identify optimization opportunities

#### **❓ Key Questions to Answer:**
- What percentage of CPU time is spent on authentication/authorization?
- Which API calls are most expensive?
- How does the flame graph change under load?
- Can you identify optimization opportunities?

---

## Overview

In this lab, you will learn how to profile the kube-apiserver using performance analysis tools. You'll create flame graphs to visualize CPU usage and identify performance bottlenecks in the Kubernetes API server.

## Learning Objectives

- Deploy a functional Kubernetes control plane
- Use privileged containers for debugging
- Profile running processes using `perf` tools
- Generate and interpret flame graphs
- Understand API server performance characteristics

## Prerequisites

- Completed Lab 01 or have a working control plane
- Docker installed
- kubectl configured
- Basic understanding of Linux performance tools
- Familiarity with CPU profiling concepts

## Task Description

### Step 1: Deploy Control Plane

Ensure you have a working Kubernetes control plane deployed. You can use:

- Static pods (from Lab 01)
- kubeadm
- kind
- minikube

### Step 2: Create Debug Container

Create a debug privileged container with the kubectl-flame image:

```bash
kubectl run debug-profiler \
  --image=verizondigital/kubectl-flame:v0.2.4-perf \
  --privileged=true \
  --restart=Never \
  -- sleep infinity
```

### Step 3: Profile kube-apiserver

Inside the debug container:

1. Find the kube-apiserver PID
2. Collect performance samples:

   ```bash
   perf record -F 99 -g -p <APISERVER_PID> -o /tmp/out sleep 30
   ```

3. This will collect samples for 30 seconds

### Step 4: Generate Flame Graph

1. Process the perf data:

   ```bash
   perf script -i /tmp/out | FlameGraph/stackcollapse-perf.pl | FlameGraph/flamegraph.pl > flame.svg
   ```

2. Copy the flame.svg from the container:

   ```bash
   kubectl cp debug-profiler:/tmp/flame.svg ./flame.svg
   ```

3. Save flame.svg in your repository

### Step 5: Analysis

Analyze the flame graph:

- What are the hottest code paths?
- Which functions consume the most CPU?
- Are there any unexpected performance patterns?

## Directory Structure

```text
lab-02-profiling-apiserver/
├── README.md                    # This file
├── manifests/
│   └── debug-profiler.yaml
├── scripts/
│   ├── profile-apiserver.sh
│   └── generate-flamegraph.sh
├── results/
│   └── flame.svg               # Your generated flame graph
└── solutions/
    ├── SOLUTION.md
    └── example-flame.svg
```

## Tools Required

- **perf**: Linux profiling tool
- **FlameGraph**: Visualization scripts by Brendan Gregg
- **kubectl-flame**: Kubernetes-aware profiling tool

## Success Criteria

- [ ] Debug container is running with proper privileges
- [ ] Successfully collected perf samples from kube-apiserver
- [ ] Generated flame.svg file
- [ ] Copied flame.svg to local repository
- [ ] Can interpret the flame graph results
- [ ] (Bonus) Generated load on API server and compared flame graphs

## Important Notes

### Security Considerations

- Privileged containers have full access to the host
- Only use in development/testing environments
- Be aware of the security implications

### Performance Impact

- Profiling adds overhead to the profiled process
- The `-F 99` flag means 99 samples per second
- Adjust sampling frequency based on your needs

## Generating API Server Load

To make the profiling more interesting, generate some load:

```bash
# Run multiple kubectl commands in parallel
for i in {1..10}; do
  kubectl get pods --all-namespaces &
done

# Or use a load testing tool
kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://kubernetes.default.svc.cluster.local; done"
```

## Resources

- [Linux perf Examples](http://www.brendangregg.com/perf.html)
- [Flame Graphs](http://www.brendangregg.com/flamegraphs.html)
- [kubectl-flame GitHub](https://github.com/VerizonMedia/kubectl-flame)
- [Profiling Kubernetes](https://kubernetes.io/blog/2019/05/14/Kubernetes-1.15-Profiling-Kubernetes/)

## Troubleshooting

Common issues:

- **Permission denied**: Ensure container is running as privileged
- **perf not found**: The kubectl-flame image should include perf tools
- **FlameGraph scripts missing**: Clone from GitHub if needed
- **Cannot find PID**: Use `ps aux | grep kube-apiserver` or check process tree

## Challenge Questions

1. What percentage of CPU time is spent on authentication/authorization?
2. Which API calls are most expensive?
3. How does the flame graph change under different load patterns?
4. Can you identify any optimization opportunities?

## Next Steps

After completing this lab, proceed to [Lab 03: Cloud Controller Manager](../lab-03-cloud-controller-manager/) to learn about cloud provider integration.


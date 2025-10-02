# Lab 01: Control Plane with Static Pods

**Difficulty Level:** Beginner

## Lab Agenda & Task Checklist

### ⏰ **Estimated Time:** 2-3 hours

### 📋 **Task Overview:**
> **Goal:** Deploy a Kubernetes control plane using kubelet static pods and understand why a basic deployment fails

#### **🎯 Tasks to Complete:**

- [ ] **Step 1: Generate Manifests**
  - [ ] Create `etcd.yaml` static pod manifest
  - [ ] Create `kube-apiserver.yaml` static pod manifest  
  - [ ] Create `kube-scheduler.yaml` static pod manifest
  - [ ] Create `kube-controller-manager.yaml` static pod manifest

- [ ] **Step 2: Deploy Control Plane**
  - [ ] Configure kubelet to use static pod path (`/etc/kubernetes/manifests/`)
  - [ ] Deploy control plane components using kubelet static pods
  - [ ] Verify all components are running with `kubectl get pods -n kube-system`

- [ ] **Step 3: Deploy Application**
  - [ ] Create nginx deployment manifest (3 replicas)
  - [ ] Apply the deployment using `kubectl apply`
  - [ ] Observe deployment status

- [ ] **Step 4: Critical Analysis**
  - [ ] **🔍 INVESTIGATE:** Why doesn't the deployment work?
  - [ ] **💡 IDENTIFY:** What components are missing?
  - [ ] **🛠️ SOLUTION:** How to fix the issue?

#### **❓ Key Questions to Answer:**
- Why are pods stuck in `Pending` state?
- What component is missing for pod networking?
- What is needed for DNS resolution?
- How do pods get scheduled without a network plugin?

---

## Overview

In this lab, you will deploy a Kubernetes control plane using kubelet static pods. This approach helps you understand the core components of Kubernetes and how they interact with each other.

## Learning Objectives

- Understand Kubernetes control plane components
- Learn how kubelet manages static pods
- Troubleshoot deployment issues
- Understand pod networking and service discovery

## Prerequisites

- Docker installed
- kubelet binary installed
- Basic understanding of Kubernetes architecture

## Task Description

Based on the experience from the first task, complete the following:

### Step 1: Generate Manifests

Create 4 manifests for the following control plane components:

1. **etcd** - Key-value store for cluster data
2. **kube-apiserver** - API server for Kubernetes
3. **kube-scheduler** - Schedules pods to nodes
4. **kube-controller-manager** - Manages controllers

### Step 2: Deploy Control Plane

- Configure kubelet to use static pod path
- Deploy control plane components using kubelet static pods
- Verify all components are running

### Step 3: Deploy Application

- Create a custom deployment manifest (e.g., nginx)
- Configure the deployment for 3 replicas
- Apply the deployment

### Critical Question

**Why doesn't it work? How to fix it?**

Think about:

- What component is missing for pod networking?
- What is needed for DNS resolution?
- How do pods get scheduled without a network plugin?

## Directory Structure

```text
lab-01-control-plane-static-pods/
├── README.md                    # This file
├── manifests/
│   ├── static-pods/             # Static pod manifests for kubelet
│   │   ├── etcd.yaml
│   │   ├── kube-apiserver.yaml
│   │   ├── kube-scheduler.yaml
│   │   └── kube-controller-manager.yaml
│   └── nginx-deployment.yaml   # Regular deployment (will fail initially)
├── scripts/
│   └── setup-lab01.sh          # Lab setup script
└── solutions/
    └── SOLUTION.md
```

## Hints

1. **Static pods** are managed directly by kubelet without API server intervention
2. The **static pod manifests** (in `manifests/static-pods/`) should be placed in kubelet's static pod directory (`/etc/kubernetes/manifests/`)
3. The **nginx deployment** (in `manifests/`) will be applied via kubectl and should initially fail
4. Pay attention to component communication - each component needs to know how to reach others
5. Consider certificate generation for secure communication

## Success Criteria

- [ ] All control plane components are running
- [ ] kubectl can communicate with the API server
- [ ] You can identify why the deployment doesn't work
- [ ] You can explain the solution to fix the issue
- [ ] (Bonus) You successfully deploy the nginx application

## Resources

- [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)
- [Static Pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)
- [kubelet Configuration](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)

## Troubleshooting

Common issues you might encounter:

- **Kubelet not starting**: Check configuration file and paths
- **API server not accessible**: Verify certificates and port bindings
- **Pods stuck in Pending**: This is expected - investigate why!

## Next Steps

After completing this lab, proceed to [Lab 02: Profiling kube-apiserver](../lab-02-profiling-apiserver/) to learn about performance analysis.


# Kubernetes Manifests

This directory contains Kubernetes manifest files used for demo applications and testing the control plane setup.

## nginx-demo-deployment.yaml

A demo nginx deployment that demonstrates proper scheduling on a single-node cluster with taints.

**Key features:**
- **Tolerations**: Allows scheduling on nodes with the `node.cloudprovider.kubernetes.io/uninitialized:NoSchedule` taint
- **Node Selector**: Targets nodes labeled with `node-role.kubernetes.io/master=""`
- **Resource Limits**: Includes proper resource requests and limits for production-like behavior

**Usage:**
```bash
sudo kubebuilder/bin/kubectl apply -f manifests/nginx-demo-deployment.yaml
```

**Educational Value:**
This manifest teaches essential Kubernetes concepts:
- Taint and toleration mechanisms
- Node selection and scheduling
- Resource management best practices
- Proper deployment structure

Use this manifest to verify your control plane is working correctly after following the manual setup steps.

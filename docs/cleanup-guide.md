# Kubernetes Cleanup Guide

This document provides commands to clean up Kubernetes components running on your system, useful when switching between different lab setups or starting fresh.

## Automated Cleanup Script

The repository includes a comprehensive cleanup script that handles all cleanup operations safely and efficiently.

### Basic Usage

From the repository root directory:

```bash
# Standard cleanup (recommended for most cases)
sudo ./cleanup.sh

# Full cleanup including network interfaces (when switching CNI plugins)
sudo ./cleanup.sh --clean-network

# Skip confirmation prompt (for automation)
sudo ./cleanup.sh --force

# Check current state without cleaning up
./cleanup.sh --verify-only

# Get help and see all options
./cleanup.sh --help
```

### Script Options

The cleanup script supports several options:

- `--help, -h` - Show help message and usage examples
- `--verify-only` - Only run verification checks (no cleanup)
- `--force` - Skip confirmation prompt for automated use
- `--clean-network` - Also clean up network interfaces (optional)

### What the Script Does

**Standard Cleanup (`./cleanup.sh`):**
- ✅ Stops all Kubernetes processes gracefully
- ✅ Cleans up data directories (`./etcd`, `/var/lib/kubelet/*`, etc.)
- ✅ Removes certificates and configuration files
- ✅ Cleans up CNI configuration files
- ❌ **Preserves network interfaces** (safer approach)

**Full Cleanup (`./cleanup.sh --clean-network`):**
- ✅ Everything from standard cleanup
- ✅ **Also removes CNI network interfaces** (`cni0`, `flannel.1`, etc.)

### Why Network Cleanup Is Optional

By default, the script **does not** remove network interfaces because:
- CNI plugins often expect interfaces to persist across restarts
- Network interfaces are usually managed automatically
- Removing interfaces can cause connectivity issues
- Docker interfaces should be managed by Docker daemon

Use `--clean-network` only when:
- Switching between different CNI plugins
- Troubleshooting network-related issues
- Performing complete environment reset

## Manual Cleanup Commands

If you prefer to run commands manually or need to clean up specific components:

### Stop Kubernetes Components

```bash
# Stop in proper order to avoid dependency issues
sudo pkill -f "kube-controller-manager"
sudo pkill -f "kubelet" 
sudo pkill -f "kube-scheduler"
sudo pkill -f "kube-apiserver"
sudo pkill -f "containerd"
sudo pkill -f "etcd"
```

### Clean Up Data Directories

```bash
# Remove data directories
sudo rm -rf ./etcd
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /run/containerd/*

# Remove static pod manifests
sudo rm -rf /etc/kubernetes/manifests/*.yaml
```

### Clean Up Certificates and Configuration

```bash
# Remove temporary certificates and tokens
sudo rm -f /tmp/sa.key /tmp/sa.pub /tmp/token.csv /tmp/ca.key /tmp/ca.crt

# Remove Kubernetes configuration
sudo rm -f /etc/kubernetes/pki/*
sudo rm -f /etc/kubernetes/kubeconfig

# Remove CNI configuration
sudo rm -f /etc/cni/net.d/*.conf
```

### Reset Network Configuration (Optional)

⚠️ **Use with caution** - Only needed when switching CNI plugins or troubleshooting network issues:

```bash
# Remove CNI network interfaces (only if needed)
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true

# Note: docker0 is managed by Docker daemon - usually don't remove it
# sudo ip link delete docker0 2>/dev/null || true
```

## Verification Commands

Use these commands to verify the cleanup was successful:

```bash
# Check for running Kubernetes processes
pgrep -f "kube-|etcd|containerd" || echo "No Kubernetes processes running"

# Check for kubelet mounts
mount | grep kubelet || echo "No kubelet mounts found"

# Check network interfaces
ip link show | grep -E "(cni|flannel|docker)" || echo "No CNI interfaces found"

# Check listening ports (common Kubernetes ports)
netstat -tulpn | grep -E ":6443|:2379|:2380|:10250|:10251|:10252|:10259|:10257" || echo "No Kubernetes ports listening"
```

## When to Use This Cleanup

Use this cleanup in the following scenarios:

- **Before starting a new lab**: Ensure clean environment
- **Switching between setups**: Remove previous configurations
- **Troubleshooting**: Start fresh when components are misbehaving
- **Lab completion**: Clean up after finishing exercises

## Lab-Specific Cleanup

### Using the Main Cleanup Script

```bash
# Standard cleanup (recommended)
cd /workspaces/mastering-k8s
sudo ./cleanup.sh

# Full cleanup including network interfaces
sudo ./cleanup.sh --clean-network

# Automated cleanup (no confirmation)
sudo ./cleanup.sh --force
```

### Lab-Specific Scripts

Some labs may have their own cleanup commands:

```bash
# Lab 01 specific cleanup
cd /workspaces/mastering-k8s
labs/lab-01-control-plane-static-pods/scripts/setup-lab01.sh cleanup

# Main setup script cleanup
./setup.sh cleanup
```

## Common Usage Examples

### Before Starting a New Lab

```bash
cd /workspaces/mastering-k8s
sudo ./cleanup.sh --force
```

### Switching Between Different CNI Setups

```bash
cd /workspaces/mastering-k8s
sudo ./cleanup.sh --clean-network --force
```

### Troubleshooting Lab Issues

```bash
cd /workspaces/mastering-k8s
# First, check what's running
./cleanup.sh --verify-only

# Then clean up if needed
sudo ./cleanup.sh
```

### Quick Environment Check

```bash
cd /workspaces/mastering-k8s
./cleanup.sh --verify-only
```

## Important Notes

⚠️ **Warning**: This cleanup will remove ALL Kubernetes data and configurations. Make sure you don't have important data in:
- `/var/lib/kubelet/`
- `/etc/kubernetes/`
- `./etcd/`

💡 **Tip**: Always run cleanup commands from the `/workspaces/mastering-k8s` directory to ensure relative paths work correctly.

🔒 **Security**: In production environments, be very careful with iptables cleanup commands as they can affect network connectivity.

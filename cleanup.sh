#!/bin/bash

# Kubernetes Cleanup Script
# This script stops all Kubernetes components and cleans up the environment

set -e

echo "🧹 Kubernetes Environment Cleanup"
echo "=================================="
echo ""

# Function to check if running as root for certain operations
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ This script requires sudo privileges for cleanup operations."
        echo "Please run: sudo ./cleanup.sh"
        exit 1
    fi
}

# Function to stop processes gracefully
stop_processes() {
    echo "🛑 Stopping Kubernetes components..."
    
    # Stop in proper order to avoid dependency issues
    echo "  - Stopping kube-controller-manager..."
    pkill -f "kube-controller-manager" 2>/dev/null || true
    
    echo "  - Stopping kubelet..."
    pkill -f "kubelet" 2>/dev/null || true
    
    echo "  - Stopping kube-scheduler..."
    pkill -f "kube-scheduler" 2>/dev/null || true
    
    echo "  - Stopping kube-apiserver..."
    pkill -f "kube-apiserver" 2>/dev/null || true
    
    echo "  - Stopping containerd..."
    pkill -f "containerd" 2>/dev/null || true
    
    echo "  - Stopping etcd..."
    pkill -f "etcd" 2>/dev/null || true
    
    # Wait for graceful shutdown
    echo "  - Waiting for processes to stop gracefully..."
    sleep 5
    
    # Force kill any remaining processes
    echo "  - Force stopping any remaining processes..."
    pkill -9 -f "kube-controller-manager" 2>/dev/null || true
    pkill -9 -f "kubelet" 2>/dev/null || true
    pkill -9 -f "kube-scheduler" 2>/dev/null || true
    pkill -9 -f "kube-apiserver" 2>/dev/null || true
    pkill -9 -f "containerd" 2>/dev/null || true
    pkill -9 -f "etcd" 2>/dev/null || true
    
    echo "✅ All Kubernetes processes stopped"
}

# Function to clean up data directories
cleanup_data() {
    echo ""
    echo "🗂️  Cleaning up data directories..."
    
    # Remove data directories
    echo "  - Removing etcd data..."
    rm -rf ./etcd 2>/dev/null || true
    
    echo "  - Removing kubelet data..."
    rm -rf /var/lib/kubelet/* 2>/dev/null || true
    
    echo "  - Removing containerd runtime data..."
    rm -rf /run/containerd/* 2>/dev/null || true
    
    echo "  - Removing containerd data..."
    rm -rf /var/lib/containerd/* 2>/dev/null || true
    
    echo "  - Removing static pod manifests..."
    rm -rf /etc/kubernetes/manifests/*.yaml 2>/dev/null || true
    
    echo "✅ Data directories cleaned"
}

# Function to clean up certificates and configuration
cleanup_config() {
    echo ""
    echo "🔐 Cleaning up certificates and configuration..."
    
    # Remove temporary certificates and tokens
    echo "  - Removing temporary certificates..."
    rm -f /tmp/sa.key /tmp/sa.pub /tmp/token.csv /tmp/ca.key /tmp/ca.crt 2>/dev/null || true
    
    echo "  - Removing Kubernetes PKI..."
    rm -f /etc/kubernetes/pki/* 2>/dev/null || true
    
    echo "  - Removing kubeconfig..."
    rm -f /etc/kubernetes/kubeconfig 2>/dev/null || true
    
    echo "  - Removing CNI configuration..."
    rm -f /etc/cni/net.d/*.conf 2>/dev/null || true
    
    echo "✅ Configuration files cleaned"
}

# Function to reset network configuration
cleanup_network() {
    echo ""
    echo "🌐 Cleaning up network interfaces..."
    
    # Check which interfaces exist before trying to delete them
    echo "  - Checking for CNI interfaces..."
    
    # Remove cni0 interface if it exists
    if ip link show cni0 >/dev/null 2>&1; then
        echo "  - Removing cni0 interface..."
        ip link delete cni0 2>/dev/null || true
    else
        echo "  - cni0 interface not found (already clean)"
    fi
    
    # Remove flannel interface if it exists
    if ip link show flannel.1 >/dev/null 2>&1; then
        echo "  - Removing flannel.1 interface..."
        ip link delete flannel.1 2>/dev/null || true
    else
        echo "  - flannel.1 interface not found (already clean)"
    fi
    
    # Note: docker0 is typically managed by Docker daemon, so we'll leave it alone
    # unless specifically requested to remove it
    if ip link show docker0 >/dev/null 2>&1; then
        echo "  - docker0 interface found (leaving it managed by Docker)"
    fi
    
    # Remove other common CNI interfaces
    for iface in weave vxlan.calico califb0a1234 veth-bridge; do
        if ip link show "$iface" >/dev/null 2>&1; then
            echo "  - Removing $iface interface..."
            ip link delete "$iface" 2>/dev/null || true
        fi
    done
    
    echo "✅ Network interfaces cleaned"
}

# Function to verify cleanup
verify_cleanup() {
    echo ""
    echo "🔍 Verifying cleanup..."
    echo "===================="
    
    # Check for running processes
    RUNNING_PROCS=$(pgrep -f "kube-|etcd|containerd" 2>/dev/null || true)
    if [ -z "$RUNNING_PROCS" ]; then
        echo "✅ No Kubernetes processes running"
    else
        echo "⚠️  Some processes are still running:"
        pgrep -f "kube-|etcd|containerd" | xargs ps -p 2>/dev/null || true
    fi
    
    # Check for mounted volumes
    MOUNTS=$(mount | grep kubelet 2>/dev/null || true)
    if [ -z "$MOUNTS" ]; then
        echo "✅ No kubelet mounts remaining"
    else
        echo "⚠️  Some kubelet mounts still exist:"
        echo "$MOUNTS"
        echo "  (These may need manual unmounting)"
    fi
    
    # Check for listening Kubernetes ports
    K8S_PORTS=$(netstat -tulpn 2>/dev/null | grep -E ":6443|:2379|:2380|:10250|:10251|:10252|:10259|:10257" || true)
    if [ -z "$K8S_PORTS" ]; then
        echo "✅ No Kubernetes ports listening"
    else
        echo "⚠️  Some Kubernetes ports are still listening:"
        echo "$K8S_PORTS"
    fi
    
    # Check for CNI interfaces
    CNI_INTERFACES=$(ip link show 2>/dev/null | grep -E "(cni|flannel|docker)" || true)
    if [ -z "$CNI_INTERFACES" ]; then
        echo "✅ No CNI interfaces found"
    else
        echo "⚠️  Some CNI interfaces still exist:"
        echo "$CNI_INTERFACES"
    fi
}

# Function to show help
show_help() {
    echo "Kubernetes Environment Cleanup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h        Show this help message"
    echo "  --verify-only     Only run verification checks (no cleanup)"
    echo "  --force          Skip confirmation prompt"
    echo "  --clean-network  Also clean up network interfaces (optional)"
    echo ""
    echo "This script will:"
    echo "  • Stop all Kubernetes processes"
    echo "  • Clean up data directories"
    echo "  • Remove certificates and configuration"
    echo "  • Reset network interfaces (only with --clean-network)"
    echo "  • Verify cleanup completion"
    echo ""
    echo "⚠️  WARNING: This will remove ALL Kubernetes data and configurations!"
    echo ""
    echo "Examples:"
    echo "  $0                    # Standard cleanup (no network changes)"
    echo "  $0 --clean-network   # Full cleanup including network interfaces"
    echo "  $0 --force           # Skip confirmation prompt"
    echo "  $0 --verify-only     # Just check current state"
}

# Parse command line arguments
VERIFY_ONLY=false
FORCE=false
CLEAN_NETWORK=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_help
            exit 0
            ;;
        --verify-only)
            VERIFY_ONLY=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --clean-network)
            CLEAN_NETWORK=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    # Show help if no sudo and not verify-only
    if [ "$VERIFY_ONLY" = false ]; then
        check_sudo
    fi
    
    # If verify-only, just run verification
    if [ "$VERIFY_ONLY" = true ]; then
        verify_cleanup
        exit 0
    fi
    
    # Confirmation prompt (unless forced)
    if [ "$FORCE" = false ]; then
        echo "⚠️  WARNING: This will remove ALL Kubernetes data and configurations!"
        echo ""
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Cleanup cancelled."
            exit 1
        fi
        echo ""
    fi
    
    # Run cleanup steps
    stop_processes
    cleanup_data
    cleanup_config
    
    # Only clean network if specifically requested
    if [ "$CLEAN_NETWORK" = true ]; then
        cleanup_network
    else
        echo ""
        echo "🌐 Skipping network interface cleanup (use --clean-network to include)"
        echo "  Network interfaces like cni0, docker0 will be left as-is"
    fi
    
    verify_cleanup
    
    echo ""
    echo "🎉 Cleanup completed successfully!"
    echo ""
    echo "You can now run any lab setup script with a clean environment."
    echo ""
    echo "Examples:"
    echo "  • Main setup: ./setup.sh"
    echo "  • Lab 01: ./labs/lab-01-control-plane-static-pods/scripts/setup-lab01.sh"

}

# Run main function
main "$@"

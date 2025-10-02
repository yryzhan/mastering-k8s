#!/bin/bash

# Lab 02: Profiling kube-apiserver Setup Script
# This script sets up kubelet to run Kubernetes control plane components as static pods
# Same as Lab 01 but prepared for profiling the API server

set -e

# Component deployment mode
DEPLOY_MODE=${1:-"all"}  # Options: etcd, apiserver, scheduler, controller-manager, all

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up Lab 02: Control Plane for API Server Profiling...${NC}"
echo -e "${YELLOW}Deploy mode: $DEPLOY_MODE${NC}"

# Function to check if a process is running
is_running() {
    pgrep -f "$1" >/dev/null
}

# Function to stop process if running
stop_process() {
    if is_running "$1"; then
        echo "Stopping $1..."
        sudo pkill -f "$1" || true
        while is_running "$1"; do
            sleep 1
        done
    fi
}

download_dependencies() {
    echo "Downloading required components..."
    
    # Create necessary directories
    sudo mkdir -p ./kubebuilder/bin
    sudo mkdir -p /etc/cni/net.d
    sudo mkdir -p /var/lib/kubelet
    sudo mkdir -p /var/lib/kubelet/pki
    sudo mkdir -p /etc/kubernetes/manifests
    sudo mkdir -p /etc/kubernetes/pki
    sudo mkdir -p /var/log/kubernetes
    sudo mkdir -p /etc/containerd/
    sudo mkdir -p /run/containerd
    sudo mkdir -p /opt/cni

    # Download kubebuilder tools if not present
    if [ ! -f "kubebuilder/bin/kubectl" ]; then
        echo "Downloading kubebuilder tools..."
        curl -L https://storage.googleapis.com/kubebuilder-tools/kubebuilder-tools-1.30.0-linux-amd64.tar.gz -o /tmp/kubebuilder-tools.tar.gz
        sudo tar -C ./kubebuilder --strip-components=1 -zxf /tmp/kubebuilder-tools.tar.gz
        rm /tmp/kubebuilder-tools.tar.gz
        sudo chmod -R 755 ./kubebuilder/bin
    fi

    # Download kubelet if not present
    if [ ! -f "kubebuilder/bin/kubelet" ]; then
        echo "Downloading kubelet..."
        sudo curl -L "https://dl.k8s.io/v1.30.0/bin/linux/amd64/kubelet" -o kubebuilder/bin/kubelet
        sudo chmod 755 kubebuilder/bin/kubelet
    fi

    # Install container runtime components
    if [ ! -d "/opt/cni/bin" ]; then
        echo "Installing containerd..."
        wget https://github.com/containerd/containerd/releases/download/v2.0.5/containerd-static-2.0.5-linux-amd64.tar.gz -O /tmp/containerd.tar.gz
        sudo tar zxf /tmp/containerd.tar.gz -C /opt/cni/
        rm /tmp/containerd.tar.gz

        echo "Installing runc..."
        sudo curl -L "https://github.com/opencontainers/runc/releases/download/v1.2.6/runc.amd64" -o /opt/cni/bin/runc

        echo "Installing CNI plugins..."
        wget https://github.com/containernetworking/plugins/releases/download/v1.6.2/cni-plugins-linux-amd64-v1.6.2.tgz -O /tmp/cni-plugins.tgz
        sudo tar zxf /tmp/cni-plugins.tgz -C /opt/cni/bin/
        rm /tmp/cni-plugins.tgz

        sudo chmod -R 755 /opt/cni
    fi
}

setup_certificates_and_configs() {
    echo "Setting up certificates and configurations..."
    
    export HOST_IP=$(hostname -I | awk '{print $1}')
    
    # Create PKI directory with proper permissions first
    sudo mkdir -p /etc/kubernetes/pki
    sudo chmod 755 /etc/kubernetes/pki
    
    # Generate service account key pair
    if [ ! -f "/etc/kubernetes/pki/sa.key" ]; then
        sudo openssl genrsa -out /etc/kubernetes/pki/sa.key 2048
        sudo openssl rsa -in /etc/kubernetes/pki/sa.key -pubout -out /etc/kubernetes/pki/sa.pub
    fi

    # Generate token file  
    if [ ! -f "/etc/kubernetes/pki/token.csv" ]; then
        export TOKEN="1234567890"
        echo "${TOKEN},admin,admin,system:masters" | sudo tee /etc/kubernetes/pki/token.csv > /dev/null
    fi

    # Generate CA certificate
    if [ ! -f "/etc/kubernetes/pki/ca.crt" ]; then
        sudo openssl genrsa -out /etc/kubernetes/pki/ca.key 2048
        sudo openssl req -x509 -new -nodes -key /etc/kubernetes/pki/ca.key -subj "/CN=kubernetes-ca" -days 365 -out /etc/kubernetes/pki/ca.crt
        sudo cp /etc/kubernetes/pki/ca.crt /var/lib/kubelet/ca.crt
        sudo cp /etc/kubernetes/pki/ca.crt /var/lib/kubelet/pki/ca.crt
    fi

    # Set proper permissions
    sudo chmod 644 /etc/kubernetes/pki/ca.crt
    sudo chmod 600 /etc/kubernetes/pki/ca.key
    sudo chmod 644 /etc/kubernetes/pki/sa.pub
    sudo chmod 600 /etc/kubernetes/pki/sa.key
    sudo chmod 644 /etc/kubernetes/pki/token.csv

    # Configure kubectl
    if ! sudo kubebuilder/bin/kubectl config current-context 2>/dev/null | grep -q "test-context"; then
        sudo kubebuilder/bin/kubectl config set-credentials test-user --token=1234567890
        sudo kubebuilder/bin/kubectl config set-cluster test-env --server=https://127.0.0.1:6443 --insecure-skip-tls-verify
        sudo kubebuilder/bin/kubectl config set-context test-context --cluster=test-env --user=test-user --namespace=default 
        sudo kubebuilder/bin/kubectl config use-context test-context
    fi

    # Create kubeconfig for components
    cat <<EOF | sudo tee /etc/kubernetes/kubeconfig > /dev/null
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://127.0.0.1:6443
  name: local
contexts:
- context:
    cluster: local
    user: admin
  name: local
current-context: local
users:
- name: admin
  user:
    token: "1234567890"
EOF

    # Configure CNI
    cat <<EOF | sudo tee /etc/cni/net.d/10-mynet.conf > /dev/null
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

    # Configure containerd
    cat <<EOF | sudo tee /etc/containerd/config.toml > /dev/null
version = 2

[grpc]
  address = "/run/containerd/containerd.sock"

[plugins.'io.containerd.cri.v1.runtime']
  enable_selinux = false
  enable_unprivileged_ports = true
  enable_unprivileged_icmp = true
  device_ownership_from_security_context = false

[plugins.'io.containerd.cri.v1.images']
  snapshotter = "native"
  disable_snapshot_annotations = true

[plugins.'io.containerd.cri.v1.runtime'.cni]
  bin_dir = "/opt/cni/bin"
  conf_dir = "/etc/cni/net.d"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
  runtime_type = "io.containerd.runc.v2"

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = false
EOF

    # Configure kubelet
    cat <<EOF | sudo tee /var/lib/kubelet/config.yaml > /dev/null
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: false
authorization:
  mode: AlwaysAllow
clusterDomain: "cluster.local"
clusterDNS:
  - "10.0.0.10"
resolvConf: "/etc/resolv.conf"
runtimeRequestTimeout: "15m"
failSwapOn: false
seccompDefault: true
serverTLSBootstrap: false
containerRuntimeEndpoint: "unix:///run/containerd/containerd.sock"
staticPodPath: "/etc/kubernetes/manifests"
EOF

    # Set proper permissions
    sudo mkdir -p /var/lib/kubelet/pods
    sudo chmod 750 /var/lib/kubelet/pods
    sudo chmod 644 /var/lib/kubelet/config.yaml
}

prepare_static_pod_manifests() {
    echo -e "${BLUE}Preparing static pod manifests...${NC}"
    
    export HOST_IP=$(hostname -I | awk '{print $1}')
    
    # Get the absolute path to the lab directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    LAB_DIR="$(dirname "$SCRIPT_DIR")"
    MANIFESTS_DIR="$LAB_DIR/manifests/static-pods"
    
    echo "Looking for manifests in: $MANIFESTS_DIR"
    
    # Define which manifests to deploy based on mode
    case $DEPLOY_MODE in
        "etcd")
            MANIFESTS_TO_DEPLOY="etcd.yaml"
            echo -e "${YELLOW}Deploying only etcd${NC}"
            ;;
        "apiserver")
            MANIFESTS_TO_DEPLOY="etcd.yaml kube-apiserver.yaml"
            echo -e "${YELLOW}Deploying etcd and kube-apiserver${NC}"
            ;;
        "scheduler")
            MANIFESTS_TO_DEPLOY="etcd.yaml kube-apiserver.yaml kube-scheduler.yaml"
            echo -e "${YELLOW}Deploying etcd, kube-apiserver, and kube-scheduler${NC}"
            ;;
        "controller-manager")
            MANIFESTS_TO_DEPLOY="etcd.yaml kube-apiserver.yaml kube-scheduler.yaml kube-controller-manager.yaml"
            echo -e "${YELLOW}Deploying all components${NC}"
            ;;
        "all")
            MANIFESTS_TO_DEPLOY="etcd.yaml kube-apiserver.yaml kube-scheduler.yaml kube-controller-manager.yaml"
            echo -e "${YELLOW}Deploying all components${NC}"
            ;;
        *)
            echo -e "${RED}Invalid deploy mode: $DEPLOY_MODE${NC}"
            echo "Valid options: etcd, apiserver, scheduler, controller-manager, all"
            exit 1
            ;;
    esac
    
    # Copy static pod manifests and replace HOST_IP placeholder
    for manifest in $MANIFESTS_TO_DEPLOY; do
        if [ -f "$MANIFESTS_DIR/$manifest" ]; then
            echo -e "${GREEN}Processing $manifest...${NC}"
            sudo cp "$MANIFESTS_DIR/$manifest" "/etc/kubernetes/manifests/"
            sudo sed -i "s/HOST_IP/$HOST_IP/g" "/etc/kubernetes/manifests/$manifest"
        else
            echo -e "${RED}Warning: $manifest not found in $MANIFESTS_DIR${NC}"
        fi
    done
    
    # List what was copied
    echo -e "${BLUE}Static pod manifests in /etc/kubernetes/manifests/:${NC}"
    ls -la /etc/kubernetes/manifests/ || true
}

start_runtime_and_kubelet() {
    echo "Starting container runtime and kubelet..."
    
    # Start containerd if not running
    if ! is_running "containerd"; then
        echo "Starting containerd..."
        export PATH=$PATH:/opt/cni/bin:kubebuilder/bin
        sudo PATH=$PATH:/opt/cni/bin:/usr/sbin /opt/cni/bin/containerd -c /etc/containerd/config.toml &
        sleep 5
    fi

    # Restart kubelet to pick up new manifests
    if is_running "kubelet"; then
        echo -e "${YELLOW}Restarting kubelet to pick up new manifests...${NC}"
        sudo pkill -f kubelet
        sleep 3
    fi
    
    echo "Starting kubelet..."
    sudo PATH=$PATH:/opt/cni/bin:/usr/sbin kubebuilder/bin/kubelet \
        --kubeconfig=/etc/kubernetes/kubeconfig \
        --config=/var/lib/kubelet/config.yaml \
        --root-dir=/var/lib/kubelet \
        --cert-dir=/var/lib/kubelet/pki \
        --hostname-override=$(hostname) \
        --pod-infra-container-image=registry.k8s.io/pause:3.10 \
        --node-ip=$(hostname -I | awk '{print $1}') \
        --cgroup-driver=cgroupfs \
        --max-pods=10 \
        --v=2 &
    sleep 10
}

verify_setup() {
    echo -e "${BLUE}Verifying setup...${NC}"
    echo "Waiting for static pods to start..."
    sleep 30
    
    echo -e "${BLUE}Checking static pods status:${NC}"
    
    case $DEPLOY_MODE in
        "etcd")
            echo -e "${YELLOW}Checking etcd container...${NC}"
            if sudo ctr -n k8s.io containers ls 2>/dev/null | grep -q etcd; then
                echo -e "${GREEN}✅ etcd container created${NC}"
                sudo ctr -n k8s.io containers ls | grep etcd
            else
                echo -e "${RED}❌ etcd container not found${NC}"
            fi
            
            # Test etcd directly via HTTP
            echo ""
            echo -e "${YELLOW}Testing etcd connectivity...${NC}"
            sleep 5  # Give etcd a bit more time to start
            if curl -s http://$(hostname -I | awk '{print $1}'):2379/health 2>/dev/null | grep -q "true"; then
                echo -e "${GREEN}✅ etcd is healthy${NC}"
                curl -s http://$(hostname -I | awk '{print $1}'):2379/health
            else
                echo -e "${RED}❌ etcd health check failed${NC}"
                echo "Checking if etcd is listening on port 2379..."
                netstat -tlnp 2>/dev/null | grep 2379 || echo "Port 2379 not listening"
            fi
            ;;
        "apiserver")
            echo -e "${YELLOW}Checking etcd and API server...${NC}"
            sudo kubebuilder/bin/kubectl get pods -n kube-system | grep -E "(etcd|kube-apiserver)" || echo "Some pods may not be ready yet"
            
            echo -e "${YELLOW}Checking API server health:${NC}"
            if sudo kubebuilder/bin/kubectl get --raw='/readyz?verbose' 2>/dev/null; then
                echo -e "${GREEN}✅ API server is ready${NC}"
            else
                echo -e "${RED}❌ API server not ready${NC}"
            fi
            ;;
        "scheduler")
            echo -e "${YELLOW}Checking etcd, API server, and scheduler...${NC}"
            sudo kubebuilder/bin/kubectl get pods -n kube-system | grep -E "(etcd|kube-apiserver|kube-scheduler)" || echo "Some pods may not be ready yet"
            ;;
        "controller-manager"|"all")
            echo -e "${YELLOW}Checking all components...${NC}"
            sudo kubebuilder/bin/kubectl get pods -n kube-system || echo "API server may not be ready yet"
            
            echo -e "${YELLOW}Checking API server health:${NC}"
            sudo kubebuilder/bin/kubectl get --raw='/readyz?verbose' || echo "API server not ready"
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}Lab 02 Setup Complete for mode: $DEPLOY_MODE!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    
    case $DEPLOY_MODE in
        "etcd")
            echo "1. Verify etcd is working:"
            echo "   curl http://$(hostname -I | awk '{print $1}'):2379/health"
            echo ""
            echo "2. Check etcd container status:"
            echo "   sudo ctr -n k8s.io containers ls | grep etcd"
            echo ""
            echo "3. To proceed with API server:"
            echo "   sudo labs/lab-02-profiling-apiserver/scripts/setup-lab02.sh apiserver"
            ;;
        "apiserver")
            echo "1. Test API server connectivity:"
            echo "   sudo kubebuilder/bin/kubectl get --raw='/readyz'"
            echo ""
            echo "2. Check pods:"
            echo "   sudo kubebuilder/bin/kubectl get pods -n kube-system"
            echo ""
            echo "3. To proceed with scheduler:"
            echo "   sudo labs/lab-02-profiling-apiserver/scripts/setup-lab02.sh scheduler"
            ;;
        "scheduler")
            echo "1. Check scheduler status:"
            echo "   sudo kubebuilder/bin/kubectl get pods -n kube-system"
            echo ""
            echo "2. To proceed with controller-manager:"
            echo "   sudo labs/lab-02-profiling-apiserver/scripts/setup-lab02.sh controller-manager"
            ;;
        "controller-manager"|"all")
            echo "1. Find the kube-apiserver PID for profiling:"
            echo "   ps aux | grep kube-apiserver | grep -v grep"
            echo ""
            echo "2. Start profiling the API server:"
            echo "   Follow the instructions in README.md for Lab 02"
            echo ""
            echo "3. Generate load on the API server:"
            echo "   kubectl get pods --all-namespaces"
            echo "   kubectl get nodes"
            ;;
    esac
}

stop() {
    echo "Stopping Lab 02 components..."
    stop_process "kubelet"
    stop_process "containerd"
    
    # Remove static pod manifests
    sudo rm -f /etc/kubernetes/manifests/*.yaml
    echo "Lab 02 components stopped"
}

cleanup() {
    stop
    echo -e "${BLUE}Cleaning up Lab 02...${NC}"
    
    # Remove leftover containers and tasks
    echo -e "${YELLOW}Removing containerd containers...${NC}"
    if command -v ctr >/dev/null 2>&1; then
        # Remove all containers in k8s.io namespace
        CONTAINERS=$(sudo ctr -n k8s.io containers ls -q 2>/dev/null || true)
        if [ -n "$CONTAINERS" ]; then
            echo "$CONTAINERS" | while read -r container; do
                echo "  • Removing container: $container"
                sudo ctr -n k8s.io containers rm "$container" 2>/dev/null || true
            done
        fi
        
        # Remove all tasks
        TASKS=$(sudo ctr -n k8s.io tasks ls -q 2>/dev/null || true)
        if [ -n "$TASKS" ]; then
            echo "$TASKS" | while read -r task; do
                echo "  • Killing task: $task"
                sudo ctr -n k8s.io tasks kill "$task" 2>/dev/null || true
                sudo ctr -n k8s.io tasks rm "$task" 2>/dev/null || true
            done
        fi
    fi
    
    # Unmount any remaining volume mounts
    echo -e "${YELLOW}Unmounting kubelet volumes...${NC}"
    if [ -d "/var/lib/kubelet/pods" ]; then
        # Find and unmount all mounts under /var/lib/kubelet/pods
        sudo find /var/lib/kubelet/pods -type d -name "volumes" 2>/dev/null | while read -r vol_dir; do
            sudo find "$vol_dir" -type d 2>/dev/null | while read -r mount_dir; do
                if sudo mountpoint -q "$mount_dir" 2>/dev/null; then
                    echo "  • Unmounting: $mount_dir"
                    sudo umount "$mount_dir" 2>/dev/null || true
                fi
            done
        done
    fi
    
    # Remove data directories
    echo -e "${YELLOW}Cleaning up data directories...${NC}"
    sudo rm -rf /var/lib/kubelet/* 2>/dev/null || true
    sudo rm -rf /run/containerd/* 2>/dev/null || true
    sudo rm -rf /var/lib/containerd/* 2>/dev/null || true
    sudo rm -rf ./etcd 2>/dev/null || true
    
    # Remove certificates and configs
    echo -e "${YELLOW}Removing certificates and configuration...${NC}"
    sudo rm -rf /etc/kubernetes/pki/*
    sudo rm -f /etc/kubernetes/kubeconfig
    sudo rm -f /etc/cni/net.d/*.conf
    
    # Remove static pod manifests
    echo -e "${YELLOW}Removing static pod manifests...${NC}"
    sudo rm -f /etc/kubernetes/manifests/*.yaml
    
    echo -e "${GREEN}✅ Lab 02 cleanup complete${NC}"
    echo ""
    echo "All Lab 02 resources have been cleaned up:"
    echo "  • Processes stopped"
    echo "  • Containers removed"
    echo "  • Data directories cleared"
    echo "  • Configuration files removed"
}

case "${1:-all}" in
    etcd|apiserver|scheduler|controller-manager|all)
        download_dependencies
        setup_certificates_and_configs
        prepare_static_pod_manifests
        start_runtime_and_kubelet
        verify_setup
        ;;
    start)
        # Backward compatibility - default to all components
        DEPLOY_MODE="all"
        download_dependencies
        setup_certificates_and_configs
        prepare_static_pod_manifests
        start_runtime_and_kubelet
        verify_setup
        ;;
    stop)
        stop
        ;;
    cleanup)
        cleanup
        ;;
    *)
        echo "Usage: $0 {etcd|apiserver|scheduler|controller-manager|all|start|stop|cleanup}"
        echo ""
        echo "Component modes:"
        echo "  etcd              - Deploy only etcd"
        echo "  apiserver         - Deploy etcd + kube-apiserver"
        echo "  scheduler         - Deploy etcd + kube-apiserver + kube-scheduler"
        echo "  controller-manager- Deploy all components"
        echo "  all               - Deploy all components (default)"
        echo ""
        echo "Legacy modes:"
        echo "  start             - Set up and start Lab 01 environment (all components)"
        echo "  stop              - Stop Lab 01 components"
        echo "  cleanup           - Stop and clean up all Lab 01 data"
        exit 1
        ;;
esac

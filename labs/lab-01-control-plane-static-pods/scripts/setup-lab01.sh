#!/bin/bash

# Lab 01: Control Plane with Static Pods Setup Script
# This script sets up kubelet to run Kubernetes control plane components as static pods

set -e

echo "Setting up Lab 01: Control Plane with Static Pods..."

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
    
    # Generate service account key pair
    if [ ! -f "/etc/kubernetes/pki/sa.key" ]; then
        openssl genrsa -out /etc/kubernetes/pki/sa.key 2048
        openssl rsa -in /etc/kubernetes/pki/sa.key -pubout -out /etc/kubernetes/pki/sa.pub
    fi

    # Generate token file  
    if [ ! -f "/etc/kubernetes/pki/token.csv" ]; then
        export TOKEN="1234567890"
        echo "${TOKEN},admin,admin,system:masters" | sudo tee /etc/kubernetes/pki/token.csv
    fi

    # Generate CA certificate
    if [ ! -f "/etc/kubernetes/pki/ca.crt" ]; then
        openssl genrsa -out /etc/kubernetes/pki/ca.key 2048
        openssl req -x509 -new -nodes -key /etc/kubernetes/pki/ca.key -subj "/CN=kubernetes-ca" -days 365 -out /etc/kubernetes/pki/ca.crt
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
    cat <<EOF | sudo tee /etc/kubernetes/kubeconfig
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
    token: 1234567890
EOF

    # Configure CNI
    cat <<EOF | sudo tee /etc/cni/net.d/10-mynet.conf
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
    cat <<EOF | sudo tee /etc/containerd/config.toml
version = 3

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
    cat <<EOF | sudo tee /var/lib/kubelet/config.yaml
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
    echo "Preparing static pod manifests..."
    
    export HOST_IP=$(hostname -I | awk '{print $1}')
    
    # Copy static pod manifests and replace HOST_IP placeholder
    for manifest in etcd.yaml kube-apiserver.yaml kube-scheduler.yaml kube-controller-manager.yaml; do
        if [ -f "labs/lab-01-control-plane-static-pods/manifests/static-pods/$manifest" ]; then
            echo "Processing $manifest..."
            sudo cp "labs/lab-01-control-plane-static-pods/manifests/static-pods/$manifest" "/etc/kubernetes/manifests/"
            sudo sed -i "s/HOST_IP/$HOST_IP/g" "/etc/kubernetes/manifests/$manifest"
        else
            echo "Warning: $manifest not found in lab static-pods directory"
        fi
    done
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

    # Start kubelet if not running
    if ! is_running "kubelet"; then
        echo "Starting kubelet..."
        sudo PATH=$PATH:/opt/cni/bin:/usr/sbin kubebuilder/bin/kubelet \
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
    fi
}

verify_setup() {
    echo "Verifying setup..."
    echo "Waiting for static pods to start..."
    sleep 30
    
    echo "Checking static pods status:"
    sudo kubebuilder/bin/kubectl get pods -n kube-system || echo "API server may not be ready yet"
    
    echo ""
    echo "Checking API server health:"
    sudo kubebuilder/bin/kubectl get --raw='/readyz?verbose' || echo "API server not ready"
    
    echo ""
    echo "Lab 01 Setup Complete!"
    echo ""
    echo "Next steps:"
    echo "1. To deploy the nginx application (this should fail initially):"
    echo "   sudo kubebuilder/bin/kubectl apply -f labs/lab-01-control-plane-static-pods/manifests/nginx-deployment.yaml"
    echo ""
    echo "2. Investigate why the deployment doesn't work:"
    echo "   sudo kubebuilder/bin/kubectl get pods"
    echo "   sudo kubebuilder/bin/kubectl describe pod <pod-name>"
    echo ""
    echo "3. Think about what components are missing for pod networking!"
}

stop() {
    echo "Stopping Lab 01 components..."
    stop_process "kubelet"
    stop_process "containerd"
    
    # Remove static pod manifests
    sudo rm -f /etc/kubernetes/manifests/*.yaml
    echo "Lab 01 components stopped"
}

cleanup() {
    stop
    echo "Cleaning up Lab 01..."
    sudo rm -rf /var/lib/kubelet/*
    sudo rm -rf /run/containerd/*
    sudo rm -rf /etc/kubernetes/pki/*
    sudo rm -f /etc/kubernetes/kubeconfig
    echo "Lab 01 cleanup complete"
}

case "${1:-start}" in
    start)
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
        echo "Usage: $0 {start|stop|cleanup}"
        echo ""
        echo "start   - Set up and start Lab 01 environment"
        echo "stop    - Stop Lab 01 components"
        echo "cleanup - Stop and clean up all Lab 01 data"
        exit 1
        ;;
esac

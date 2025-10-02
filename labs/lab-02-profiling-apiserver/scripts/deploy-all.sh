#!/bin/bash

# Lab 02: Deploy All Components for Profiling
# This script deploys kube-proxy, CoreDNS, and the debug profiler

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Lab 02: Deploying Components for API Server Profiling    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get the absolute path to the lab directory and kubectl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"
MANIFESTS_DIR="$LAB_DIR/manifests"
KUBECTL="/workspaces/mastering-k8s/kubebuilder/bin/kubectl"

# Check if API server is running
echo -e "${YELLOW}Checking if control plane is running...${NC}"
if ! sudo $KUBECTL get nodes >/dev/null 2>&1; then
    echo -e "${RED}❌ API server is not running!${NC}"
    echo ""
    echo -e "${YELLOW}Please start the control plane first:${NC}"
    echo "  sudo labs/lab-02-profiling-apiserver/scripts/setup-lab02.sh"
    echo ""
    exit 1
fi
echo -e "${GREEN}✅ Control plane is running${NC}"
echo ""

echo -e "${YELLOW}Step 1: Deploying kube-proxy${NC}"
echo "  • Creates iptables rules for Services"
echo "  • Generates API server watch traffic"
echo ""
sudo $KUBECTL apply -f "$MANIFESTS_DIR/kube-proxy.yaml"
echo -e "${GREEN}✅ kube-proxy deployed${NC}"
echo ""

echo -e "${YELLOW}Step 2: Deploying Debug Profiler${NC}"
echo "  • Privileged pod with perf tools"
echo "  • Access to host processes"
echo ""
sudo $KUBECTL apply -f "$MANIFESTS_DIR/debug-profiler.yaml"
echo -e "${GREEN}✅ Debug profiler deployed${NC}"
echo ""

echo -e "${BLUE}Waiting for pods to be ready...${NC}"
sleep 5

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ All components deployed successfully!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Current Status:${NC}"
sudo $KUBECTL get pods -A
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo -e "${YELLOW}1. Wait for all pods to be Running:${NC}"
echo "   sudo $KUBECTL get pods -A"
echo ""
echo -e "${YELLOW}2. Exec into the debug profiler:${NC}"
echo "   sudo $KUBECTL exec -it debug-profiler -- /bin/sh"
echo ""
echo -e "${YELLOW}3. Find kube-apiserver PID:${NC}"
echo "   ps aux | grep kube-apiserver | grep -v grep"
echo ""
echo -e "${YELLOW}4. Start profiling (replace <PID> with actual PID):${NC}"
echo "   /app/perf record -F 99 -g -p <PID> -o /results/perf.data sleep 30"
echo ""
echo -e "${YELLOW}5. Generate flame graph:${NC}"
echo "   cd /results"
echo "   /app/perf script -i perf.data | /app/FlameGraph/stackcollapse-perf.pl | /app/FlameGraph/flamegraph.pl > flame.svg"
echo ""
echo -e "${YELLOW}6. View results on host:${NC}"
echo "   ls -la /tmp/profiling-results/"
echo ""
echo -e "${GREEN}🔥 Happy Profiling! 🔥${NC}"


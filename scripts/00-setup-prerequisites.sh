#!/bin/bash

# Script to check and install prerequisites for Flux Tofu-Controller Demo
# This script checks for required tools and provides installation instructions

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "Flux Tofu-Controller Prerequisites"
echo "======================================"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Function to get version
get_version() {
    $1 2>&1 || echo "unknown"
}

MISSING_TOOLS=0

# Check kubectl
echo "Checking kubectl..."
if command_exists kubectl; then
    VERSION=$(kubectl version --client -o json 2>/dev/null | grep gitVersion | head -1 | cut -d'"' -f4)
    print_status 0 "kubectl is installed (version: $VERSION)"
else
    print_status 1 "kubectl is NOT installed"
    echo -e "${YELLOW}  Install: https://kubernetes.io/docs/tasks/tools/${NC}"
    echo -e "${YELLOW}  macOS: brew install kubectl${NC}"
    MISSING_TOOLS=1
fi
echo ""

# Check flux CLI
echo "Checking flux CLI..."
if command_exists flux; then
    VERSION=$(flux --version | cut -d' ' -f3)
    print_status 0 "flux CLI is installed (version: $VERSION)"
else
    print_status 1 "flux CLI is NOT installed"
    echo -e "${YELLOW}  Install: https://fluxcd.io/flux/installation/${NC}"
    echo -e "${YELLOW}  macOS: brew install fluxcd/tap/flux${NC}"
    MISSING_TOOLS=1
fi
echo ""

# Check Azure CLI
echo "Checking Azure CLI..."
if command_exists az; then
    VERSION=$(az version --output tsv 2>/dev/null | grep azure-cli | cut -f2)
    print_status 0 "Azure CLI is installed (version: $VERSION)"
else
    print_status 1 "Azure CLI is NOT installed"
    echo -e "${YELLOW}  Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli${NC}"
    echo -e "${YELLOW}  macOS: brew install azure-cli${NC}"
    MISSING_TOOLS=1
fi
echo ""

# Check git
echo "Checking git..."
if command_exists git; then
    VERSION=$(git --version | cut -d' ' -f3)
    print_status 0 "git is installed (version: $VERSION)"
else
    print_status 1 "git is NOT installed"
    echo -e "${YELLOW}  Install: https://git-scm.com/downloads${NC}"
    echo -e "${YELLOW}  macOS: brew install git${NC}"
    MISSING_TOOLS=1
fi
echo ""

# Check for Kubernetes cluster access
echo "Checking Kubernetes cluster access..."
if kubectl cluster-info >/dev/null 2>&1; then
    CONTEXT=$(kubectl config current-context)
    print_status 0 "Connected to Kubernetes cluster: $CONTEXT"
else
    print_status 1 "No Kubernetes cluster access detected"
    echo -e "${YELLOW}  Create a cluster with:${NC}"
    echo -e "${YELLOW}    - kind: kind create cluster${NC}"
    echo -e "${YELLOW}    - minikube: minikube start${NC}"
    echo -e "${YELLOW}    - AKS: az aks create ...${NC}"
    MISSING_TOOLS=1
fi
echo ""

# Optional: Check for kind (for local clusters)
echo "Checking optional tools..."
if command_exists kind; then
    VERSION=$(kind version | cut -d' ' -f2)
    print_status 0 "kind is installed (version: $VERSION) - for local clusters"
else
    echo -e "${YELLOW}ℹ${NC}  kind is NOT installed (optional for local clusters)"
    echo -e "${YELLOW}  macOS: brew install kind${NC}"
fi
echo ""

# Check required environment variables
echo "Checking environment variables..."
MISSING_VARS=0

if [ -z "$GITHUB_TOKEN" ]; then
    print_status 1 "GITHUB_TOKEN not set"
    echo -e "${YELLOW}  Create a token at: https://github.com/settings/tokens${NC}"
    echo -e "${YELLOW}  Then: export GITHUB_TOKEN=your-token${NC}"
    MISSING_VARS=1
else
    print_status 0 "GITHUB_TOKEN is set"
fi

if [ -z "$GITHUB_USER" ]; then
    print_status 1 "GITHUB_USER not set"
    echo -e "${YELLOW}  Set it: export GITHUB_USER=your-username${NC}"
    MISSING_VARS=1
else
    print_status 0 "GITHUB_USER is set ($GITHUB_USER)"
fi

if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    print_status 1 "AZURE_SUBSCRIPTION_ID not set"
    MISSING_VARS=1
else
    print_status 0 "AZURE_SUBSCRIPTION_ID is set"
fi

if [ -z "$AZURE_TENANT_ID" ]; then
    print_status 1 "AZURE_TENANT_ID not set"
    MISSING_VARS=1
else
    print_status 0 "AZURE_TENANT_ID is set"
fi

if [ -z "$AZURE_CLIENT_ID" ]; then
    print_status 1 "AZURE_CLIENT_ID not set"
    MISSING_VARS=1
else
    print_status 0 "AZURE_CLIENT_ID is set"
fi

if [ -z "$AZURE_CLIENT_SECRET" ]; then
    print_status 1 "AZURE_CLIENT_SECRET not set"
    MISSING_VARS=1
else
    print_status 0 "AZURE_CLIENT_SECRET is set"
fi

echo ""
echo "======================================"

if [ $MISSING_TOOLS -eq 0 ] && [ $MISSING_VARS -eq 0 ]; then
    echo -e "${GREEN}✓ All prerequisites are met!${NC}"
    echo -e "${GREEN}  You can proceed with the demo.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some prerequisites are missing.${NC}"
    echo -e "${YELLOW}  Please install the missing tools and set environment variables.${NC}"
    echo ""
    echo "Quick setup commands:"
    echo "  export GITHUB_TOKEN=your-github-token"
    echo "  export GITHUB_USER=your-github-username"
    echo "  export AZURE_SUBSCRIPTION_ID=your-subscription-id"
    echo "  export AZURE_TENANT_ID=your-tenant-id"
    echo "  export AZURE_CLIENT_ID=your-client-id"
    echo "  export AZURE_CLIENT_SECRET=your-client-secret"
    exit 1
fi

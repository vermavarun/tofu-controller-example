#!/bin/bash

# Script to bootstrap Flux on Kubernetes cluster
# This sets up Flux with GitHub as the source repository

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================"
echo "Flux Bootstrap Script"
echo -e "======================================${NC}"
echo ""

# Check prerequisites
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}Error: GITHUB_TOKEN is not set${NC}"
    echo "Create a token at: https://github.com/settings/tokens"
    echo "Then run: export GITHUB_TOKEN=your-token"
    exit 1
fi

if [ -z "$GITHUB_USER" ]; then
    echo -e "${RED}Error: GITHUB_USER is not set${NC}"
    echo "Run: export GITHUB_USER=your-username"
    exit 1
fi

GITHUB_REPO=${GITHUB_REPO:-"tofu-controller-example"}
FLUX_NAMESPACE=${FLUX_NAMESPACE:-"flux-system"}

echo -e "${GREEN}Configuration:${NC}"
echo "  GitHub User: $GITHUB_USER"
echo "  GitHub Repo: $GITHUB_REPO"
echo "  Flux Namespace: $FLUX_NAMESPACE"
echo ""

# Check if kubectl is connected to a cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}Error: Not connected to a Kubernetes cluster${NC}"
    echo "Please ensure kubectl is configured correctly"
    exit 1
fi

CONTEXT=$(kubectl config current-context)
echo -e "${YELLOW}Current cluster context: $CONTEXT${NC}"
echo ""

# Pre-flight checks
echo -e "${BLUE}Running Flux pre-flight checks...${NC}"
flux check --pre

if [ $? -ne 0 ]; then
    echo -e "${RED}Pre-flight checks failed. Please fix the issues above.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Pre-flight checks passed!${NC}"
echo ""

# Bootstrap Flux
echo -e "${BLUE}Bootstrapping Flux...${NC}"
echo "This will:"
echo "  1. Install Flux components in the cluster"
echo "  2. Create/use GitHub repository: $GITHUB_USER/$GITHUB_REPO"
echo "  3. Configure Flux to sync from the repository"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/demo \
  --personal \
  --private=false

if [ $? -ne 0 ]; then
    echo -e "${RED}Flux bootstrap failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Flux bootstrapped successfully!${NC}"
echo ""

# Wait for Flux to be ready
echo -e "${BLUE}Waiting for Flux components to be ready...${NC}"
kubectl wait --for=condition=ready --timeout=5m \
  -n $FLUX_NAMESPACE pod -l app.kubernetes.io/part-of=flux

echo ""
echo -e "${GREEN}✓ Flux is ready!${NC}"
echo ""

# Show status
echo -e "${BLUE}Flux components:${NC}"
kubectl get pods -n $FLUX_NAMESPACE

echo ""
echo -e "${GREEN}======================================"
echo "Flux Bootstrap Complete!"
echo -e "======================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Install tofu-controller: ./scripts/02-install-tofu-controller.sh"
echo "  2. Configure Azure credentials: ./scripts/03-create-azure-secrets.sh"
echo ""

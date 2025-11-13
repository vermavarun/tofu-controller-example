#!/bin/bash

# Complete demo script - runs all setup steps

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${MAGENTA}======================================${NC}"
echo -e "${MAGENTA}  Flux Tofu-Controller Complete Demo${NC}"
echo -e "${MAGENTA}======================================${NC}"
echo ""

# Step 1: Prerequisites
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"
"$SCRIPT_DIR/00-setup-prerequisites.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Prerequisites check failed. Please fix the issues above.${NC}"
    exit 1
fi
echo ""

# Step 2: Bootstrap Flux
echo -e "${BLUE}Step 2: Bootstrapping Flux...${NC}"
read -p "Bootstrap Flux? This will create a GitHub repository. (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/01-bootstrap-flux.sh"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Flux bootstrap failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}Skipping Flux bootstrap${NC}"
fi
echo ""

# Step 3: Install Tofu-Controller
echo -e "${BLUE}Step 3: Installing Tofu-Controller...${NC}"
"$SCRIPT_DIR/02-install-tofu-controller.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Tofu-Controller installation failed${NC}"
    exit 1
fi
echo ""

# Step 4: Create Azure Secrets
echo -e "${BLUE}Step 4: Creating Azure secrets...${NC}"
"$SCRIPT_DIR/03-create-azure-secrets.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create Azure secrets${NC}"
    exit 1
fi
echo ""

# Step 5: Deploy Terraform Resources
echo -e "${BLUE}Step 5: Deploying Terraform resources...${NC}"
echo "This will deploy:"
echo "  - GitRepository source"
echo "  - Azure Resource Group"
echo "  - Azure Storage Account"
echo "  - Azure Virtual Network"
echo ""

read -p "Deploy Terraform resources? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Replace GITHUB_USER and GITHUB_REPO in GitRepository manifest
    TEMP_FILE=$(mktemp)
    sed "s/\${GITHUB_USER}/$GITHUB_USER/g; s/\${GITHUB_REPO}/${GITHUB_REPO:-tofu-controller-example}/g" \
        "$SCRIPT_DIR/../manifests/sources/gitrepository.yaml" > "$TEMP_FILE"

    kubectl apply -f "$TEMP_FILE"
    rm "$TEMP_FILE"

    # Apply Terraform resources
    kubectl apply -f "$SCRIPT_DIR/../manifests/terraform/01-resource-group.yaml"
    kubectl apply -f "$SCRIPT_DIR/../manifests/terraform/02-storage-account.yaml"
    kubectl apply -f "$SCRIPT_DIR/../manifests/terraform/03-virtual-network.yaml"

    echo -e "${GREEN}✓ Resources deployed${NC}"
else
    echo -e "${YELLOW}Skipping resource deployment${NC}"
fi
echo ""

# Step 6: Monitor deployment
echo -e "${BLUE}Step 6: Monitoring deployment...${NC}"
echo ""
echo -e "${YELLOW}Waiting for Terraform resources to be ready...${NC}"
echo "This may take several minutes as Terraform plans and applies the infrastructure."
echo ""

# Monitor the resources
echo -e "${BLUE}Terraform resources status:${NC}"
kubectl get terraform -n flux-system

echo ""
echo "To watch the progress in real-time, run:"
echo -e "${YELLOW}  kubectl get terraform -n flux-system -w${NC}"
echo ""
echo "To see detailed status of a resource:"
echo -e "${YELLOW}  kubectl describe terraform azure-resource-group -n flux-system${NC}"
echo ""
echo "To see logs from the controller:"
echo -e "${YELLOW}  kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller -f${NC}"
echo ""

# Wait for resources (optional)
read -p "Wait for all Terraform resources to be ready? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Waiting for azure-resource-group...${NC}"
    kubectl wait --for=condition=ready --timeout=10m \
      terraform/azure-resource-group -n flux-system || true

    echo -e "${BLUE}Waiting for azure-storage-account...${NC}"
    kubectl wait --for=condition=ready --timeout=10m \
      terraform/azure-storage-account -n flux-system || true

    echo -e "${BLUE}Waiting for azure-virtual-network...${NC}"
    kubectl wait --for=condition=ready --timeout=10m \
      terraform/azure-virtual-network -n flux-system || true
fi

echo ""
echo -e "${GREEN}======================================"
echo "Demo Deployment Complete!"
echo -e "======================================${NC}"
echo ""
echo "Your Azure resources should now be provisioned!"
echo ""
echo -e "${BLUE}Verify in Azure:${NC}"
echo "  az group show --name tofu-demo-rg"
echo "  az storage account list --resource-group tofu-demo-rg"
echo "  az network vnet list --resource-group tofu-demo-rg"
echo ""
echo -e "${BLUE}Check Kubernetes resources:${NC}"
echo "  kubectl get terraform -n flux-system"
echo "  kubectl get secrets -n flux-system | grep outputs"
echo ""
echo -e "${YELLOW}To test drift detection:${NC}"
echo "  1. Manually modify a resource in Azure Portal (e.g., add a tag)"
echo "  2. Wait for drift detection (10m interval) or trigger:"
echo "     flux reconcile terraform azure-resource-group -n flux-system"
echo "  3. Watch the controller auto-remediate the drift"
echo ""
echo -e "${YELLOW}To cleanup:${NC}"
echo "  ./scripts/98-cleanup.sh"
echo ""

#!/bin/bash

# Cleanup script - removes all deployed resources

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================"
echo "Cleanup Script"
echo -e "======================================${NC}"
echo ""

FLUX_NAMESPACE=${FLUX_NAMESPACE:-"flux-system"}

echo -e "${YELLOW}WARNING: This will delete all Terraform resources and Azure infrastructure!${NC}"
echo ""
echo "This will:"
echo "  1. Delete Terraform custom resources (triggers Azure resource deletion)"
echo "  2. Delete GitRepository source"
echo "  3. Optionally uninstall Tofu-Controller"
echo "  4. Optionally uninstall Flux"
echo ""

read -p "Are you sure you want to continue? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Delete Terraform resources (this triggers deletion of Azure infrastructure)
echo -e "${BLUE}Step 1: Deleting Terraform resources...${NC}"
echo "This will destroy the Azure infrastructure (may take several minutes)."
echo ""

if kubectl get terraform -n $FLUX_NAMESPACE >/dev/null 2>&1; then
    # Delete in reverse order due to dependencies
    echo "Deleting azure-virtual-network..."
    kubectl delete terraform azure-virtual-network -n $FLUX_NAMESPACE --ignore-not-found=true

    echo "Deleting azure-storage-account..."
    kubectl delete terraform azure-storage-account -n $FLUX_NAMESPACE --ignore-not-found=true

    echo "Deleting azure-resource-group..."
    kubectl delete terraform azure-resource-group -n $FLUX_NAMESPACE --ignore-not-found=true

    # Delete example resources if they exist
    kubectl delete terraform azure-manual-approval-example -n $FLUX_NAMESPACE --ignore-not-found=true
    kubectl delete terraform azure-drift-detection-only -n $FLUX_NAMESPACE --ignore-not-found=true

    echo -e "${YELLOW}Waiting for Terraform resources to be deleted...${NC}"
    echo "This may take several minutes as Azure resources are destroyed."

    # Wait for deletion (with timeout)
    kubectl wait --for=delete terraform --all -n $FLUX_NAMESPACE --timeout=10m || true

    echo -e "${GREEN}✓ Terraform resources deleted${NC}"
else
    echo -e "${YELLOW}No Terraform resources found${NC}"
fi
echo ""

# Delete GitRepository
echo -e "${BLUE}Step 2: Deleting GitRepository source...${NC}"
kubectl delete gitrepository tofu-demo -n $FLUX_NAMESPACE --ignore-not-found=true
echo -e "${GREEN}✓ GitRepository deleted${NC}"
echo ""

# Delete secrets
echo -e "${BLUE}Step 3: Deleting secrets...${NC}"
kubectl delete secret azure-credentials -n $FLUX_NAMESPACE --ignore-not-found=true
kubectl delete secret azure-backend-config -n $FLUX_NAMESPACE --ignore-not-found=true
kubectl delete secret -n $FLUX_NAMESPACE -l terraform.io/terraform --ignore-not-found=true
echo -e "${GREEN}✓ Secrets deleted${NC}"
echo ""

# Ask about Tofu-Controller
echo -e "${BLUE}Step 4: Tofu-Controller${NC}"
read -p "Uninstall Tofu-Controller? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    kubectl delete helmrelease tofu-controller -n $FLUX_NAMESPACE --ignore-not-found=true
    kubectl delete helmrepository tofu-controller -n $FLUX_NAMESPACE --ignore-not-found=true

    # Delete CRDs (optional - be careful!)
    read -p "Delete Terraform CRD? This will remove all Terraform custom resources. (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete crd terraforms.infra.contrib.fluxcd.io --ignore-not-found=true
    fi

    echo -e "${GREEN}✓ Tofu-Controller uninstalled${NC}"
else
    echo -e "${YELLOW}Skipping Tofu-Controller uninstallation${NC}"
fi
echo ""

# Ask about Flux
echo -e "${BLUE}Step 5: Flux${NC}"
read -p "Uninstall Flux? This will remove all Flux components. (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    flux uninstall --silent
    echo -e "${GREEN}✓ Flux uninstalled${NC}"
else
    echo -e "${YELLOW}Skipping Flux uninstallation${NC}"
fi
echo ""

# Verify cleanup in Azure
echo -e "${BLUE}Step 6: Verifying Azure cleanup...${NC}"
echo "Checking if Azure resources are deleted..."

if command -v az >/dev/null 2>&1; then
    if az group show --name tofu-demo-rg >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: Azure resource group 'tofu-demo-rg' still exists${NC}"
        echo "You may need to manually delete it if cleanup failed:"
        echo "  az group delete --name tofu-demo-rg --yes --no-wait"
    else
        echo -e "${GREEN}✓ Azure resources cleaned up${NC}"
    fi
else
    echo -e "${YELLOW}Azure CLI not found, skipping verification${NC}"
fi
echo ""

echo -e "${GREEN}======================================"
echo "Cleanup Complete!"
echo -e "======================================${NC}"
echo ""
echo "Remaining items to clean up manually (if desired):"
echo "  - GitHub repository (if created by bootstrap)"
echo "  - Kubernetes cluster (if you want to delete it)"
echo "  - Azure resource groups (if they weren't fully deleted)"
echo ""

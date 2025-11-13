#!/bin/bash

# Complete cleanup script - removes EVERYTHING including Flux
# Use this to completely reset your cluster to pre-demo state

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

echo -e "${MAGENTA}======================================"
echo "COMPLETE CLEANUP SCRIPT"
echo "=====================================${NC}"
echo ""
echo -e "${RED}⚠️  WARNING: DESTRUCTIVE OPERATION ⚠️${NC}"
echo ""
echo "This will completely remove:"
echo "  ❌ All Terraform resources (destroys Azure infrastructure)"
echo "  ❌ All Kubernetes secrets"
echo "  ❌ GitRepository sources"
echo "  ❌ Tofu-Controller (with CRDs)"
echo "  ❌ Flux (all components)"
echo "  ❌ flux-system namespace"
echo "  ❌ All related CRDs"
echo ""
echo -e "${YELLOW}Your cluster will be reset to pre-demo state.${NC}"
echo ""

read -p "Are you absolutely sure? Type 'yes' to continue: " -r
echo
if [[ ! $REPLY == "yes" ]]; then
    echo -e "${GREEN}Aborted. No changes made.${NC}"
    exit 0
fi

FLUX_NAMESPACE=${FLUX_NAMESPACE:-"flux-system"}

# Step 1: Delete Terraform resources
echo ""
echo -e "${BLUE}[1/8] Deleting Terraform custom resources...${NC}"
if kubectl get crd terraforms.infra.contrib.fluxcd.io >/dev/null 2>&1; then
    if kubectl get terraform -n $FLUX_NAMESPACE >/dev/null 2>&1; then
        echo "Deleting Terraform resources (this destroys Azure infrastructure)..."

        # Delete in reverse order
        kubectl delete terraform azure-virtual-network -n $FLUX_NAMESPACE --ignore-not-found=true --timeout=2m
        kubectl delete terraform azure-storage-account -n $FLUX_NAMESPACE --ignore-not-found=true --timeout=2m
        kubectl delete terraform azure-resource-group -n $FLUX_NAMESPACE --ignore-not-found=true --timeout=2m
        kubectl delete terraform azure-manual-approval-example -n $FLUX_NAMESPACE --ignore-not-found=true --timeout=2m
        kubectl delete terraform azure-drift-detection-only -n $FLUX_NAMESPACE --ignore-not-found=true --timeout=2m

        # Wait for deletion
        echo "Waiting for Terraform resources to be deleted..."
        kubectl wait --for=delete terraform --all -n $FLUX_NAMESPACE --timeout=5m 2>/dev/null || true

        echo -e "${GREEN}✓ Terraform resources deleted${NC}"
    else
        echo -e "${YELLOW}No Terraform resources found${NC}"
    fi
else
    echo -e "${YELLOW}Terraform CRD not found${NC}"
fi

# Step 2: Delete GitRepository
echo ""
echo -e "${BLUE}[2/8] Deleting GitRepository sources...${NC}"
kubectl delete gitrepository --all -n $FLUX_NAMESPACE --ignore-not-found=true --timeout=1m
echo -e "${GREEN}✓ GitRepository sources deleted${NC}"

# Step 3: Delete HelmReleases
echo ""
echo -e "${BLUE}[3/8] Deleting HelmReleases...${NC}"
kubectl delete helmrelease --all -n $FLUX_NAMESPACE --ignore-not-found=true --timeout=2m
echo -e "${GREEN}✓ HelmReleases deleted${NC}"

# Step 4: Delete HelmRepositories
echo ""
echo -e "${BLUE}[4/8] Deleting HelmRepositories...${NC}"
kubectl delete helmrepository --all -n $FLUX_NAMESPACE --ignore-not-found=true --timeout=1m
echo -e "${GREEN}✓ HelmRepositories deleted${NC}"

# Step 5: Delete secrets
echo ""
echo -e "${BLUE}[5/8] Deleting secrets...${NC}"
kubectl delete secret azure-credentials -n $FLUX_NAMESPACE --ignore-not-found=true
kubectl delete secret azure-backend-config -n $FLUX_NAMESPACE --ignore-not-found=true
kubectl delete secret -n $FLUX_NAMESPACE -l terraform.io/terraform --ignore-not-found=true 2>/dev/null || true
kubectl delete secret -n $FLUX_NAMESPACE -l tfstate --ignore-not-found=true 2>/dev/null || true
echo -e "${GREEN}✓ Secrets deleted${NC}"

# Step 6: Uninstall Flux
echo ""
echo -e "${BLUE}[6/8] Uninstalling Flux...${NC}"
if command -v flux >/dev/null 2>&1; then
    if flux check >/dev/null 2>&1; then
        echo "Removing Flux components..."
        flux uninstall --silent || flux uninstall --force --silent
        echo -e "${GREEN}✓ Flux uninstalled${NC}"
    else
        echo -e "${YELLOW}Flux not installed or not responding${NC}"
    fi
else
    echo -e "${YELLOW}Flux CLI not found, attempting manual cleanup${NC}"
    kubectl delete deployment -n $FLUX_NAMESPACE --all --ignore-not-found=true
    kubectl delete service -n $FLUX_NAMESPACE --all --ignore-not-found=true
fi

# Step 7: Delete CRDs
echo ""
echo -e "${BLUE}[7/8] Deleting Custom Resource Definitions...${NC}"
echo "Removing Terraform CRDs..."
kubectl delete crd terraforms.infra.contrib.fluxcd.io --ignore-not-found=true

echo "Removing Flux CRDs..."
kubectl delete crd \
  alerts.notification.toolkit.fluxcd.io \
  buckets.source.toolkit.fluxcd.io \
  gitrepositories.source.toolkit.fluxcd.io \
  helmcharts.source.toolkit.fluxcd.io \
  helmreleases.helm.toolkit.fluxcd.io \
  helmrepositories.source.toolkit.fluxcd.io \
  kustomizations.kustomize.toolkit.fluxcd.io \
  ocirepositories.source.toolkit.fluxcd.io \
  providers.notification.toolkit.fluxcd.io \
  receivers.notification.toolkit.fluxcd.io \
  --ignore-not-found=true 2>/dev/null || true

echo -e "${GREEN}✓ CRDs deleted${NC}"

# Step 8: Delete namespace
echo ""
echo -e "${BLUE}[8/8] Deleting flux-system namespace...${NC}"
if kubectl get namespace $FLUX_NAMESPACE >/dev/null 2>&1; then
    echo "Deleting namespace (this may take a minute)..."
    kubectl delete namespace $FLUX_NAMESPACE --timeout=2m || {
        echo -e "${YELLOW}Namespace stuck, forcing deletion...${NC}"
        kubectl delete namespace $FLUX_NAMESPACE --grace-period=0 --force || true
    }

    # Wait for namespace deletion
    echo "Waiting for namespace to be fully removed..."
    kubectl wait --for=delete namespace/$FLUX_NAMESPACE --timeout=2m 2>/dev/null || true

    echo -e "${GREEN}✓ Namespace deleted${NC}"
else
    echo -e "${YELLOW}Namespace not found${NC}"
fi

# Verify cluster state
echo ""
echo -e "${BLUE}Verifying cleanup...${NC}"

# Check for remaining pods
REMAINING_PODS=$(kubectl get pods -n $FLUX_NAMESPACE 2>/dev/null | wc -l)
if [ "$REMAINING_PODS" -gt 1 ]; then
    echo -e "${YELLOW}⚠ Some pods still exist in flux-system namespace${NC}"
else
    echo -e "${GREEN}✓ No pods in flux-system namespace${NC}"
fi

# Check for namespace
if kubectl get namespace $FLUX_NAMESPACE >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ flux-system namespace still exists (may be terminating)${NC}"
else
    echo -e "${GREEN}✓ flux-system namespace removed${NC}"
fi

# Verify Azure resources
echo ""
echo -e "${BLUE}Verifying Azure cleanup...${NC}"
if command -v az >/dev/null 2>&1; then
    if az account show >/dev/null 2>&1; then
        if az group show --name tofu-demo-rg >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠ Azure resource group 'tofu-demo-rg' still exists${NC}"
            echo ""
            read -p "Delete Azure resource group now? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Deleting Azure resource group..."
                az group delete --name tofu-demo-rg --yes --no-wait
                echo -e "${GREEN}✓ Azure resource group deletion initiated${NC}"
                echo -e "${YELLOW}Note: Deletion is running in background. Check Azure Portal to verify.${NC}"
            fi
        else
            echo -e "${GREEN}✓ Azure resources cleaned up${NC}"
        fi
    else
        echo -e "${YELLOW}Not logged in to Azure CLI${NC}"
    fi
else
    echo -e "${YELLOW}Azure CLI not found, skipping verification${NC}"
fi

# Final summary
echo ""
echo -e "${MAGENTA}======================================"
echo "CLEANUP COMPLETE!"
echo "=====================================${NC}"
echo ""
echo -e "${GREEN}✓ All demo resources removed${NC}"
echo ""
echo "Your cluster is now back to pre-demo state."
echo ""
echo -e "${BLUE}What was removed:${NC}"
echo "  ✓ Terraform custom resources"
echo "  ✓ GitRepository sources"
echo "  ✓ HelmReleases and HelmRepositories"
echo "  ✓ Kubernetes secrets"
echo "  ✓ Tofu-Controller"
echo "  ✓ Flux components"
echo "  ✓ flux-system namespace"
echo "  ✓ All CRDs"
echo ""
echo -e "${YELLOW}Manual cleanup (if needed):${NC}"
echo "  - GitHub repository: https://github.com/$GITHUB_USER/tofu-controller-example"
echo "  - Azure resource group: Check Azure Portal"
echo "  - Kubernetes cluster: Delete if no longer needed"
echo ""
echo -e "${BLUE}To run the demo again, simply execute:${NC}"
echo "  source .env"
echo "  ./scripts/99-run-demo.sh"
echo ""

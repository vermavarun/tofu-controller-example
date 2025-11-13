#!/bin/bash

# Script to create Kubernetes secrets for Azure credentials

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================"
echo "Azure Credentials Secret Creation"
echo -e "======================================${NC}"
echo ""

FLUX_NAMESPACE=${FLUX_NAMESPACE:-"flux-system"}

# Check required environment variables
MISSING_VARS=0

if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    echo -e "${RED}Error: AZURE_SUBSCRIPTION_ID not set${NC}"
    MISSING_VARS=1
fi

if [ -z "$AZURE_TENANT_ID" ]; then
    echo -e "${RED}Error: AZURE_TENANT_ID not set${NC}"
    MISSING_VARS=1
fi

if [ -z "$AZURE_CLIENT_ID" ]; then
    echo -e "${RED}Error: AZURE_CLIENT_ID not set${NC}"
    MISSING_VARS=1
fi

if [ -z "$AZURE_CLIENT_SECRET" ]; then
    echo -e "${RED}Error: AZURE_CLIENT_SECRET not set${NC}"
    MISSING_VARS=1
fi

if [ $MISSING_VARS -eq 1 ]; then
    echo ""
    echo "Please set all required Azure environment variables:"
    echo "  export AZURE_SUBSCRIPTION_ID=your-subscription-id"
    echo "  export AZURE_TENANT_ID=your-tenant-id"
    echo "  export AZURE_CLIENT_ID=your-client-id"
    echo "  export AZURE_CLIENT_SECRET=your-client-secret"
    echo ""
    echo "To create a service principal:"
    echo '  az ad sp create-for-rbac --name "tofu-controller-sp" --role Contributor --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID'
    exit 1
fi

echo -e "${GREEN}All Azure credentials are set${NC}"
echo ""

# Test Azure credentials
echo -e "${BLUE}Testing Azure credentials...${NC}"
if az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Azure credentials are valid${NC}"

    # Get subscription name
    SUBSCRIPTION_NAME=$(az account show --query name -o tsv 2>/dev/null || echo "Unknown")
    echo -e "${GREEN}  Subscription: $SUBSCRIPTION_NAME${NC}"
else
    echo -e "${RED}✗ Azure credentials are invalid${NC}"
    exit 1
fi
echo ""

# Create namespace if it doesn't exist
if ! kubectl get namespace $FLUX_NAMESPACE >/dev/null 2>&1; then
    echo -e "${BLUE}Creating namespace $FLUX_NAMESPACE...${NC}"
    kubectl create namespace $FLUX_NAMESPACE
fi

# Delete existing secret if it exists
if kubectl get secret azure-credentials -n $FLUX_NAMESPACE >/dev/null 2>&1; then
    echo -e "${YELLOW}Deleting existing azure-credentials secret...${NC}"
    kubectl delete secret azure-credentials -n $FLUX_NAMESPACE
fi

# Create secret with Azure credentials
echo -e "${BLUE}Creating azure-credentials secret in $FLUX_NAMESPACE namespace...${NC}"

kubectl create secret generic azure-credentials \
  --namespace=$FLUX_NAMESPACE \
  --from-literal=ARM_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
  --from-literal=ARM_TENANT_ID=$AZURE_TENANT_ID \
  --from-literal=ARM_CLIENT_ID=$AZURE_CLIENT_ID \
  --from-literal=ARM_CLIENT_SECRET=$AZURE_CLIENT_SECRET

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Secret created successfully${NC}"
else
    echo -e "${RED}✗ Failed to create secret${NC}"
    exit 1
fi
echo ""

# Create a separate secret for backend configuration (optional)
echo -e "${BLUE}Creating azure-backend-config secret...${NC}"

if kubectl get secret azure-backend-config -n $FLUX_NAMESPACE >/dev/null 2>&1; then
    kubectl delete secret azure-backend-config -n $FLUX_NAMESPACE
fi

# For state backend (if you want to store state in Azure Storage)
kubectl create secret generic azure-backend-config \
  --namespace=$FLUX_NAMESPACE \
  --from-literal=subscription_id=$AZURE_SUBSCRIPTION_ID \
  --from-literal=tenant_id=$AZURE_TENANT_ID \
  --from-literal=client_id=$AZURE_CLIENT_ID \
  --from-literal=client_secret=$AZURE_CLIENT_SECRET

echo -e "${GREEN}✓ Backend config secret created${NC}"
echo ""

# Show created secrets
echo -e "${BLUE}Secrets in $FLUX_NAMESPACE namespace:${NC}"
kubectl get secrets -n $FLUX_NAMESPACE | grep azure

echo ""
echo -e "${GREEN}======================================"
echo "Azure Secrets Created Successfully!"
echo -e "======================================${NC}"
echo ""
echo "Secrets created:"
echo "  - azure-credentials (for Terraform authentication)"
echo "  - azure-backend-config (for state backend)"
echo ""
echo "Next steps:"
echo "  1. Deploy Terraform resources: kubectl apply -f manifests/"
echo "  2. Monitor: kubectl get terraform -n $FLUX_NAMESPACE -w"
echo ""

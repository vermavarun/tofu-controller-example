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
USE_CLI_AUTH=${AZURE_USE_CLI:-"false"}

# Determine authentication method
if [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || [ "$USE_CLI_AUTH" = "true" ]; then
    echo -e "${YELLOW}Using Azure CLI authentication (user credentials)${NC}"
    AUTH_METHOD="cli"
else
    echo -e "${YELLOW}Using Service Principal authentication${NC}"
    AUTH_METHOD="sp"
fi
echo ""

# Check required environment variables based on auth method
MISSING_VARS=0

if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    echo -e "${RED}Error: AZURE_SUBSCRIPTION_ID not set${NC}"
    MISSING_VARS=1
fi

if [ -z "$AZURE_TENANT_ID" ]; then
    echo -e "${RED}Error: AZURE_TENANT_ID not set${NC}"
    MISSING_VARS=1
fi

if [ "$AUTH_METHOD" = "sp" ]; then
    if [ -z "$AZURE_CLIENT_ID" ]; then
        echo -e "${RED}Error: AZURE_CLIENT_ID not set${NC}"
        MISSING_VARS=1
    fi

    if [ -z "$AZURE_CLIENT_SECRET" ]; then
        echo -e "${RED}Error: AZURE_CLIENT_SECRET not set${NC}"
        MISSING_VARS=1
    fi
fi

if [ $MISSING_VARS -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}Choose one of the following authentication methods:${NC}"
    echo ""
    echo -e "${BLUE}OPTION 1: Service Principal (Recommended for Production)${NC}"
    echo "  export AZURE_SUBSCRIPTION_ID=your-subscription-id"
    echo "  export AZURE_TENANT_ID=your-tenant-id"
    echo "  export AZURE_CLIENT_ID=your-client-id"
    echo "  export AZURE_CLIENT_SECRET=your-client-secret"
    echo ""
    echo "  To create a service principal:"
    echo '  az ad sp create-for-rbac --name "tofu-controller-sp" --role Contributor --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID'
    echo ""
    echo -e "${BLUE}OPTION 2: Azure CLI (For Demo/Testing)${NC}"
    echo "  az login  # Login with your user credentials"
    echo "  export AZURE_SUBSCRIPTION_ID=your-subscription-id"
    echo "  export AZURE_TENANT_ID=your-tenant-id"
    echo "  export AZURE_USE_CLI=true"
    echo ""
    exit 1
fi

echo -e "${GREEN}All required Azure credentials are set${NC}"
echo ""

# Test Azure credentials
echo -e "${BLUE}Testing Azure credentials...${NC}"

if [ "$AUTH_METHOD" = "sp" ]; then
    # Test Service Principal
    if az login --service-principal \
      -u $AZURE_CLIENT_ID \
      -p $AZURE_CLIENT_SECRET \
      --tenant $AZURE_TENANT_ID >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Service Principal credentials are valid${NC}"

        # Get subscription name
        SUBSCRIPTION_NAME=$(az account show --query name -o tsv 2>/dev/null || echo "Unknown")
        echo -e "${GREEN}  Subscription: $SUBSCRIPTION_NAME${NC}"
    else
        echo -e "${RED}✗ Service Principal credentials are invalid${NC}"
        exit 1
    fi
else
    # Test CLI credentials
    if az account show >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Azure CLI is authenticated${NC}"

        # Set the correct subscription
        az account set --subscription $AZURE_SUBSCRIPTION_ID

        # Get subscription name and current user
        SUBSCRIPTION_NAME=$(az account show --query name -o tsv 2>/dev/null || echo "Unknown")
        CURRENT_USER=$(az account show --query user.name -o tsv 2>/dev/null || echo "Unknown")
        echo -e "${GREEN}  Subscription: $SUBSCRIPTION_NAME${NC}"
        echo -e "${GREEN}  Logged in as: $CURRENT_USER${NC}"

        # For CLI auth, we need to get or create a service principal for Kubernetes
        echo ""
        echo -e "${YELLOW}Note: Creating a temporary service principal for Kubernetes...${NC}"
        echo "This is required because Terraform in Kubernetes cannot use interactive CLI auth."

        # Create a service principal for this demo
        SP_NAME="tofu-controller-temp-sp-$(date +%s)"
        echo "Creating service principal: $SP_NAME"

        SP_OUTPUT=$(az ad sp create-for-rbac --name "$SP_NAME" \
          --role Contributor \
          --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID \
          --output json 2>/dev/null)

        if [ $? -eq 0 ]; then
            AZURE_CLIENT_ID=$(echo $SP_OUTPUT | jq -r '.appId')
            AZURE_CLIENT_SECRET=$(echo $SP_OUTPUT | jq -r '.password')
            AZURE_TENANT_ID=$(echo $SP_OUTPUT | jq -r '.tenant')

            echo -e "${GREEN}✓ Service Principal created successfully${NC}"
            echo -e "${YELLOW}  Client ID: $AZURE_CLIENT_ID${NC}"
            echo -e "${YELLOW}  Note: This SP will be used by Terraform in Kubernetes${NC}"
            echo ""
            echo -e "${YELLOW}IMPORTANT: To delete this service principal later, run:${NC}"
            echo "  az ad sp delete --id $AZURE_CLIENT_ID"
            echo ""
        else
            echo -e "${RED}✗ Failed to create service principal${NC}"
            echo "You may need 'Application Administrator' or 'Cloud Application Administrator' role"
            echo "Or use a pre-created service principal (OPTION 1)"
            exit 1
        fi
    else
        echo -e "${RED}✗ Azure CLI is not authenticated${NC}"
        echo "Please run: az login"
        exit 1
    fi
fi
echo ""# Create namespace if it doesn't exist
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

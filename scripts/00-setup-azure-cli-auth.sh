#!/bin/bash

# Quick setup script for Azure CLI authentication
# This script helps you set up Azure credentials using 'az login' (your user account)

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================"
echo "Azure CLI Authentication Setup"
echo -e "======================================${NC}"
echo ""

echo -e "${YELLOW}This script will help you set up Azure authentication using your CLI credentials.${NC}"
echo ""

# Step 1: Check if Azure CLI is installed
if ! command -v az >/dev/null 2>&1; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    echo "macOS: brew install azure-cli"
    exit 1
fi

echo -e "${GREEN}✓ Azure CLI is installed${NC}"
echo ""

# Step 2: Check if logged in
echo -e "${BLUE}Step 1: Checking Azure CLI login status...${NC}"
if az account show >/dev/null 2>&1; then
    CURRENT_USER=$(az account show --query user.name -o tsv)
    echo -e "${GREEN}✓ Already logged in as: $CURRENT_USER${NC}"
else
    echo -e "${YELLOW}Not logged in. Running 'az login'...${NC}"
    az login

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Login failed${NC}"
        exit 1
    fi

    CURRENT_USER=$(az account show --query user.name -o tsv)
    echo -e "${GREEN}✓ Logged in as: $CURRENT_USER${NC}"
fi
echo ""

# Step 3: Select subscription
echo -e "${BLUE}Step 2: Selecting Azure subscription...${NC}"
echo ""

# List available subscriptions
echo "Available subscriptions:"
az account list --output table

echo ""
read -p "Enter subscription ID (or press Enter to use current): " SUB_ID

if [ -z "$SUB_ID" ]; then
    SUB_ID=$(az account show --query id -o tsv)
    echo "Using current subscription: $SUB_ID"
else
    az account set --subscription "$SUB_ID"
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to set subscription${NC}"
        exit 1
    fi
fi

# Get subscription details
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo -e "${GREEN}✓ Using subscription:${NC}"
echo "  Name: $SUBSCRIPTION_NAME"
echo "  ID: $SUBSCRIPTION_ID"
echo "  Tenant: $TENANT_ID"
echo ""

# Step 4: Create environment file
echo -e "${BLUE}Step 3: Creating environment configuration...${NC}"
echo ""

ENV_FILE=".env"

cat > "$ENV_FILE" << EOF
# Azure CLI Authentication Configuration
# Generated: $(date)

# GitHub Configuration
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # UPDATE THIS
export GITHUB_USER="vermavarun"
export GITHUB_REPO="tofu-controller-example"

# Azure Configuration - CLI Authentication
export AZURE_SUBSCRIPTION_ID="$SUBSCRIPTION_ID"
export AZURE_TENANT_ID="$TENANT_ID"
export AZURE_USE_CLI="true"

# Optional: Flux Configuration
export FLUX_NAMESPACE="flux-system"

# Optional: Tofu-Controller Version
export TOFU_VERSION="v0.16.0-rc.4"

# To use this file, run:
# source .env
EOF

echo -e "${GREEN}✓ Created $ENV_FILE${NC}"
echo ""

# Step 5: Instructions
echo -e "${BLUE}======================================"
echo "Setup Complete!"
echo -e "======================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Edit $ENV_FILE and set your GITHUB_TOKEN:"
echo "   - Get a token from: https://github.com/settings/tokens"
echo "   - Needs 'repo' scope"
echo ""
echo "2. Load the environment variables:"
echo -e "   ${GREEN}source $ENV_FILE${NC}"
echo ""
echo "3. Run the demo:"
echo -e "   ${GREEN}./scripts/99-run-demo.sh${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} The script will automatically create a service principal"
echo "for Terraform to use in Kubernetes (required for non-interactive auth)."
echo ""
echo -e "${BLUE}Preview of $ENV_FILE:${NC}"
cat "$ENV_FILE"
echo ""

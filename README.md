# Flux Tofu-Controller Demo with Azure

This repository demonstrates how to use [Flux Tofu-Controller](https://flux-iac.github.io/tofu-controller/) to GitOps-ify Terraform/OpenTofu infrastructure deployment on Kubernetes with Azure as the target cloud provider.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Step-by-Step Guide](#step-by-step-guide)
- [What Gets Deployed](#what-gets-deployed)
- [Drift Detection](#drift-detection)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

## 🎯 Overview

Tofu-Controller is a Flux controller that reconciles Terraform and OpenTofu resources in a GitOps manner. This demo shows:

- **GitOps Automation**: Automatically apply Terraform changes from Git
- **Drift Detection**: Detect and remediate infrastructure drift
- **Multi-Tenancy**: Run Terraform in isolated runner pods
- **Azure Integration**: Deploy real Azure infrastructure from Kubernetes

### What This Demo Does

1. Sets up Flux on a Kubernetes cluster
2. Installs Tofu-Controller
3. Deploys Azure infrastructure (Resource Group, Storage Account, Virtual Network) using Terraform
4. Demonstrates drift detection and auto-remediation
5. Shows plan and apply workflow

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                       │
│                                                               │
│  ┌────────────┐         ┌──────────────────┐                │
│  │    Flux    │────────▶│ Tofu-Controller  │                │
│  │ GitOps     │         │                  │                │
│  └────────────┘         └────────┬─────────┘                │
│        │                         │                           │
│        │                         ▼                           │
│        │              ┌─────────────────────┐                │
│        │              │  Terraform Runner   │                │
│        │              │       Pods          │                │
│        │              └──────────┬──────────┘                │
│        ▼                         │                           │
│  ┌──────────────┐               │                           │
│  │ GitRepository│               │                           │
│  │   Source     │               │                           │
│  └──────────────┘               │                           │
│                                  │                           │
└──────────────────────────────────┼───────────────────────────┘
                                   │
                                   ▼
                        ┌──────────────────────┐
                        │   Azure Cloud        │
                        │  - Resource Groups   │
                        │  - Storage Accounts  │
                        │  - Virtual Networks  │
                        │  - etc.              │
                        └──────────────────────┘
```

## ✅ Prerequisites

### Required Tools

- **Kubernetes Cluster**: v1.26+ (can be local with kind/minikube or cloud-based like AKS)
- **kubectl**: v1.26+
- **Flux CLI**: v2.0+
- **Azure CLI**: v2.50+
- **Git**: For version control
- **GitHub Account**: For GitOps repository (or GitLab/other Git providers)

### Azure Requirements

**Choose ONE of the following authentication methods:**

#### Option 1: Azure CLI Authentication (Easiest for Demo/Testing)
- **Azure CLI installed** and authenticated (`az login`)
- **Active Azure subscription**
- **Contributor access** to the subscription

This option uses your personal Azure credentials and automatically creates a temporary service principal for Kubernetes.

#### Option 2: Service Principal (Recommended for Production)
- **Azure Subscription**: Active subscription with contributor access
- **Service Principal**: With permissions to create resources
  - Application ID (Client ID)
  - Client Secret
  - Tenant ID
  - Subscription ID

To create a service principal:
```bash
az ad sp create-for-rbac --name "tofu-controller-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
```

### Install Prerequisites Script

Run the prerequisite setup script:

```bash
./scripts/00-setup-prerequisites.sh
```

## 🚀 Quick Start

**Choose your authentication method:**

### Quick Start - Option 1: Azure CLI Authentication (Recommended for Beginners)

```bash
# 1. Login to Azure
az login

# 2. Run the automated setup script
./scripts/00-setup-azure-cli-auth.sh

# 3. Edit .env and add your GitHub token
# Then load the environment
source .env

# 4. Run the complete demo
./scripts/99-run-demo.sh
```

### Quick Start - Option 2: Service Principal

```bash
# 1. Create a service principal
az ad sp create-for-rbac --name "tofu-controller-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# 2. Set your environment variables
export GITHUB_TOKEN="your-github-token"
export GITHUB_USER="your-github-username"
export GITHUB_REPO="tofu-controller-example"

export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-service-principal-id"
export AZURE_CLIENT_SECRET="your-service-principal-secret"

# 3. Run the complete demo
./scripts/99-run-demo.sh
```

## 📚 Step-by-Step Guide

### Step 1: Set Up Your Kubernetes Cluster

If you don't have a cluster, create one:

```bash
# Option 1: Local with kind
kind create cluster --name tofu-demo

# Option 2: Azure Kubernetes Service
az aks create \
  --resource-group tofu-demo-rg \
  --name tofu-demo-cluster \
  --node-count 2 \
  --enable-managed-identity \
  --generate-ssh-keys

az aks get-credentials --resource-group tofu-demo-rg --name tofu-demo-cluster
```

### Step 2: Bootstrap Flux

```bash
# Set your GitHub details
export GITHUB_TOKEN="your-github-token"
export GITHUB_USER="your-github-username"
export GITHUB_REPO="tofu-controller-example"

# Run bootstrap script
./scripts/01-bootstrap-flux.sh
```

This script will:
- Install Flux on your cluster
- Create a GitHub repository (if it doesn't exist)
- Configure Flux to sync from your repository

### Step 3: Install Tofu-Controller

```bash
./scripts/02-install-tofu-controller.sh
```

This installs the tofu-controller and its dependencies.

### Step 4: Configure Azure Credentials

```bash
# Set Azure credentials
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-service-principal-id"
export AZURE_CLIENT_SECRET="your-service-principal-secret"

# Create secrets
./scripts/03-create-azure-secrets.sh
```

### Step 5: Deploy Terraform Resources

```bash
# Apply the Terraform manifests
kubectl apply -f manifests/sources/
kubectl apply -f manifests/terraform/
```

### Step 6: Monitor the Deployment

```bash
# Watch Terraform resource status
kubectl get terraform -A -w

# Check logs
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller -f

# Get detailed status
kubectl describe terraform -n flux-system azure-resource-group
```

## 🎯 What Gets Deployed

This demo deploys the following Azure resources:

### 1. Resource Group
- **Name**: `tofu-demo-rg`
- **Location**: `eastus`

### 2. Storage Account
- **Name**: `tofudemo<random>`
- **SKU**: `Standard_LRS`
- **Dependencies**: Depends on Resource Group

### 3. Virtual Network (Optional)
- **Name**: `tofu-demo-vnet`
- **Address Space**: `10.0.0.0/16`
- **Subnet**: `10.0.1.0/24`

## 🔍 Drift Detection

Tofu-Controller automatically detects and remediates drift:

### Test Drift Detection

```bash
# 1. Make a manual change in Azure Portal (e.g., add a tag to the resource group)

# 2. Wait for drift detection (or trigger reconciliation)
flux reconcile terraform azure-resource-group -n flux-system

# 3. Check the plan
kubectl describe terraform azure-resource-group -n flux-system

# 4. The controller will auto-remediate (if approvePlan: auto)
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller -f
```

### Drift Detection Modes

**Automatic Remediation** (default in this demo):
```yaml
spec:
  approvePlan: auto
```

**Manual Approval**:
```yaml
spec:
  approvePlan: ""  # Leave empty, then set to plan-<hash> to approve
```

**Detection Only**:
```yaml
spec:
  approvePlan: "disable"
  disableDriftDetection: false
```

## 🧹 Cleanup

Remove all resources:

```bash
# Delete Terraform resources (this will destroy Azure resources)
kubectl delete -f manifests/terraform/

# Delete sources
kubectl delete -f manifests/sources/

# Uninstall tofu-controller
./scripts/98-cleanup.sh

# Delete the cluster (optional)
kind delete cluster --name tofu-demo
# OR
az aks delete --resource-group tofu-demo-rg --name tofu-demo-cluster
```

## 🐛 Troubleshooting

### Controller Not Running

```bash
# Check pod status
kubectl get pods -n flux-system

# Check logs
kubectl logs -n flux-system deploy/tofu-controller
```

### Terraform Apply Fails

```bash
# Check Terraform resource events
kubectl describe terraform <name> -n flux-system

# Check runner pod logs
kubectl logs -n flux-system -l terraform.io/terraform=<name>
```

### Authentication Issues

```bash
# Verify Azure credentials secret
kubectl get secret azure-credentials -n flux-system -o yaml

# Test Azure connection
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID
```

### State Lock Issues

If Terraform state is locked:

```bash
# Check the state secret
kubectl get secret tfstate-default-<name> -n flux-system

# If needed, force unlock (use with caution)
kubectl delete pod -n flux-system -l terraform.io/terraform=<name>
```

## 📖 Additional Resources

### 📚 Documentation Files

This project includes comprehensive documentation:

- **[QUICKSTART.md](QUICKSTART.md)** - Get running in 10 minutes
- **[AZURE-AUTH.md](AZURE-AUTH.md)** - Detailed authentication guide (CLI vs Service Principal)
- **[OVERVIEW.md](OVERVIEW.md)** - Architecture and concepts deep dive
- **[COMMANDS.md](COMMANDS.md)** - Complete command reference
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Debug guide and common issues
- **[SUMMARY.md](SUMMARY.md)** - Project capabilities summary
- **[PROJECT-STATUS.md](PROJECT-STATUS.md)** - Complete project inventory

### 🔗 External Resources

- [Tofu-Controller Documentation](https://flux-iac.github.io/tofu-controller/)
- [Flux Documentation](https://fluxcd.io/flux/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitOps Principles](https://opengitops.dev/)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)

## 🤝 Contributing

Feel free to open issues or submit pull requests for improvements!

## 📝 License

MIT License - See LICENSE file for details.

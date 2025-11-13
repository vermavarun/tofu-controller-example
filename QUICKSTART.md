# Quick Start Guide

Get up and running with Flux Tofu-Controller in 10 minutes!

## Prerequisites Checklist

- [ ] Kubernetes cluster (v1.26+)
- [ ] kubectl installed and configured
- [ ] Flux CLI installed
- [ ] Azure CLI installed
- [ ] GitHub account and personal access token
- [ ] Azure subscription (choose one auth method below)

## Choose Your Authentication Method

### 🎯 Option 1: Azure CLI (Easiest - Recommended for Demo)

✅ **Use this if:** You can run `az login` and want to get started quickly

**Pros:**
- No service principal setup needed
- Uses your existing Azure credentials
- Automatic service principal creation for Kubernetes

**Cons:**
- Creates a temporary service principal
- Not recommended for production

### 🔐 Option 2: Service Principal (Production-Ready)

✅ **Use this if:** You have or can create a service principal

**Pros:**
- Full control over credentials
- Best for production environments
- No automatic resource creation

**Cons:**
- Requires manual service principal creation
- Need admin permissions to create SP

---

## 5-Minute Setup - Azure CLI Method

### 1. Clone and Navigate
```bash
cd /path/to/tofu-controller-example
```

### 2. Login to Azure
```bash
az login
# Select your subscription if you have multiple
```

### 3. Run Automated Setup
```bash
./scripts/00-setup-azure-cli-auth.sh
```

This script will:
- ✅ Check Azure CLI authentication
- ✅ Select your subscription
- ✅ Create a `.env` file with your configuration

### 4. Configure GitHub Token
```bash
# Edit .env and add your GitHub token
nano .env  # or use your favorite editor

# Update this line:
# export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

Get a token from: https://github.com/settings/tokens (needs `repo` scope)

### 5. Load Environment and Run
```bash
# Load the environment variables
source .env

# Run the demo
./scripts/99-run-demo.sh
```

---

## 5-Minute Setup - Service Principal Method

### 1. Clone and Navigate
```bash
cd /path/to/tofu-controller-example
```

### 2. Set Environment Variables
```bash
# Copy and edit the example file
cp .env.example .env
# Edit .env with your actual values
source .env
```

Or set them directly:
```bash
export GITHUB_TOKEN="your-token"
export GITHUB_USER="your-username"
export AZURE_SUBSCRIPTION_ID="your-sub-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-secret"
```

### 3. Run the Demo
```bash
./scripts/99-run-demo.sh
```

This script will:
1. ✅ Check all prerequisites
2. 🚀 Bootstrap Flux
3. 📦 Install Tofu-Controller
4. 🔐 Create Azure secrets
5. 🏗️ Deploy infrastructure

### 1. Create Service Principal
```bash
# Create a service principal
az ad sp create-for-rbac --name "tofu-controller-sp" \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID

# Note the output - you'll need:
# - appId (Client ID)
# - password (Client Secret)
# - tenant (Tenant ID)
```

### 2. Set Environment Variables
```bash
export GITHUB_TOKEN="your-github-token"
export GITHUB_USER="your-username"
export AZURE_SUBSCRIPTION_ID="your-sub-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-secret"
```

### 3. Run the Demo
```bash
./scripts/99-run-demo.sh
```

---

## What Happens Next?

After running the demo script:

### Monitor Progress
```bash
# Watch Terraform resources
kubectl get terraform -n flux-system -w

# Watch in separate terminals:
# Terminal 1: Resource status
watch -n 5 kubectl get terraform -n flux-system

# Terminal 2: Controller logs
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller -f
```

### Verify in Azure
```bash
# Check resource group
az group show --name tofu-demo-rg

# List all resources
az resource list --resource-group tofu-demo-rg --output table
```

### View Outputs
```bash
# Terraform outputs are stored as secrets
kubectl get secrets -n flux-system | grep outputs

# View specific output
kubectl get secret azure-rg-outputs -n flux-system -o jsonpath='{.data.resource_group_name}' | base64 -d
```

## Test Drift Detection

### 1. Make a Manual Change
```bash
# Add a tag to the resource group in Azure
az tag create \
  --resource-id /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/tofu-demo-rg \
  --tags manual-change=test
```

### 2. Trigger Reconciliation
```bash
# Force immediate reconciliation (or wait 10 minutes)
flux reconcile terraform azure-resource-group -n flux-system
```

### 3. Watch Auto-Remediation
```bash
# Watch the controller detect and fix the drift
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller -f

# Verify tag was removed
az group show --name tofu-demo-rg --query tags
```

## Cleanup

```bash
./scripts/98-cleanup.sh
```

## What's Next?

### Explore Different Modes

1. **Manual Approval Mode**
```bash
kubectl apply -f manifests/terraform/examples.yaml
# Edit the resource to approve plans manually
```

2. **Drift Detection Only Mode**
```bash
# Already included in examples.yaml
kubectl get terraform azure-drift-detection-only -n flux-system
```

### Customize Your Infrastructure

1. Edit Terraform files in `terraform/` directory
2. Modify variables in `manifests/terraform/*.yaml`
3. Commit and push to Git
4. Watch Flux automatically apply changes!

### Add More Resources

Create new Terraform modules:
```bash
# Add a new module
mkdir -p terraform/04-my-resource
# Create main.tf

# Create corresponding manifest
cat > manifests/terraform/04-my-resource.yaml << EOF
apiVersion: infra.contrib.fluxcd.io/v1alpha2
kind: Terraform
metadata:
  name: my-resource
  namespace: flux-system
spec:
  path: ./terraform/04-my-resource
  sourceRef:
    kind: GitRepository
    name: tofu-demo
  interval: 10m
  approvePlan: auto
  serviceAccountName: tf-runner
  envFrom:
    - secretRef:
        name: azure-credentials
EOF

# Apply
kubectl apply -f manifests/terraform/04-my-resource.yaml
```

## Common Commands

See [COMMANDS.md](COMMANDS.md) for a comprehensive list.

```bash
# Get all Terraform resources
kubectl get terraform -n flux-system

# Describe a resource
kubectl describe terraform azure-resource-group -n flux-system

# Force reconciliation
flux reconcile terraform azure-resource-group -n flux-system

# Suspend a resource
flux suspend terraform azure-storage-account -n flux-system

# Resume a resource
flux resume terraform azure-storage-account -n flux-system

# View logs
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller -f
```

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed help.

Quick checks:
```bash
# Is Flux running?
flux check

# Are Terraform resources ready?
kubectl get terraform -n flux-system

# Any errors?
kubectl describe terraform azure-resource-group -n flux-system

# Controller logs
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller --tail=50
```

## Need Help?

1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review [COMMANDS.md](COMMANDS.md)
3. Read the [official docs](https://flux-iac.github.io/tofu-controller/)
4. Join [Weave Community Slack](https://weave-community.slack.com/)

## Directory Structure

```
.
├── README.md                    # Main documentation
├── QUICKSTART.md               # This file
├── COMMANDS.md                 # Useful commands
├── TROUBLESHOOTING.md          # Troubleshooting guide
├── .env.example                # Environment variables template
├── scripts/
│   ├── 00-setup-prerequisites.sh
│   ├── 01-bootstrap-flux.sh
│   ├── 02-install-tofu-controller.sh
│   ├── 03-create-azure-secrets.sh
│   ├── 98-cleanup.sh
│   └── 99-run-demo.sh
├── terraform/
│   ├── 01-resource-group/
│   ├── 02-storage-account/
│   └── 03-virtual-network/
└── manifests/
    ├── sources/
    │   └── gitrepository.yaml
    └── terraform/
        ├── 01-resource-group.yaml
        ├── 02-storage-account.yaml
        ├── 03-virtual-network.yaml
        └── examples.yaml
```

Enjoy GitOps-ing your infrastructure! 🚀

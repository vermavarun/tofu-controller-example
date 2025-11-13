# Azure Authentication Guide

This guide explains the two authentication methods supported by this demo and helps you choose the right one.

## 🎯 Which Method Should I Use?

| Scenario | Recommended Method | Why |
|----------|-------------------|-----|
| **Quick demo/testing** | Azure CLI | Fastest setup, uses your existing credentials |
| **Learning/Development** | Azure CLI | No service principal management needed |
| **Production deployment** | Service Principal | Better security, explicit credentials |
| **CI/CD pipelines** | Service Principal | Non-interactive, automated workflows |
| **Team environment** | Service Principal | Shared credentials, RBAC control |
| **Don't have SP permissions** | Azure CLI | No admin rights needed for SP creation |

---

## Option 1: Azure CLI Authentication (Easiest)

### ✅ Advantages
- 🚀 **Fastest setup** - Just `az login` and go
- 🔐 **Uses your credentials** - No need to create service principals manually
- 🎓 **Perfect for learning** - Focus on Flux/Tofu-Controller, not auth setup
- ♻️ **Auto-cleanup** - Script handles service principal lifecycle

### ⚠️ Considerations
- 🤖 **Creates temp resources** - Automatically creates a service principal for Kubernetes
- 👤 **Personal credentials** - Uses your Azure account (not ideal for production)
- 🔑 **Needs permissions** - Requires ability to create service principals

### 📝 Step-by-Step Setup

#### 1. Prerequisites
```bash
# Ensure Azure CLI is installed
az --version

# If not installed:
# macOS: brew install azure-cli
# Windows: Download from https://aka.ms/installazurecliwindows
# Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

#### 2. Login to Azure
```bash
# Login with your credentials
az login

# This will open a browser for authentication
# After login, you'll see your subscriptions
```

#### 3. Run the Automated Setup Script
```bash
# This script does everything for you
./scripts/00-setup-azure-cli-auth.sh
```

The script will:
1. ✅ Check if you're logged in to Azure
2. 📋 List your subscriptions
3. 🎯 Let you select a subscription
4. 📝 Create a `.env` file with your configuration
5. ℹ️ Show you next steps

#### 4. Configure GitHub Token
```bash
# Edit the generated .env file
nano .env  # or use your preferred editor

# Update the GITHUB_TOKEN line with your actual token:
export GITHUB_TOKEN="ghp_your_actual_token_here"
```

**Get a GitHub token:**
1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Give it a name (e.g., "Flux Tofu Demo")
4. Select scope: `repo` (Full control of private repositories)
5. Click "Generate token"
6. Copy the token immediately (you won't see it again!)

#### 5. Load Environment and Run Demo
```bash
# Load the environment variables
source .env

# Run the demo
./scripts/99-run-demo.sh
```

### 🔍 What Happens Behind the Scenes?

When you run `./scripts/03-create-azure-secrets.sh` (part of the demo):

1. **Detects CLI auth**: Script sees `AZURE_USE_CLI="true"` or missing SP credentials
2. **Validates login**: Checks `az account show` to ensure you're authenticated
3. **Creates service principal**: Automatically creates a temporary SP
   ```bash
   # The script runs something like:
   az ad sp create-for-rbac --name "tofu-controller-temp-sp-xxxxx" \
     --role Contributor \
     --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
   ```
4. **Stores in Kubernetes**: Creates secrets with the SP credentials
5. **Informs you**: Shows the SP details and cleanup command

### 🧹 Cleanup

The temporary service principal is automatically used by the demo, but you should delete it when done:

```bash
# After cleanup, delete the service principal
# (The cleanup script shows you the exact command)
az ad sp delete --id YOUR_CLIENT_ID
```

Or list all service principals and delete:
```bash
# List service principals
az ad sp list --display-name "tofu-controller-temp-sp" --output table

# Delete by app ID
az ad sp delete --id <app-id>
```

---

## Option 2: Service Principal (Production)

### ✅ Advantages
- 🔐 **Better security** - Dedicated credentials for automation
- 🎯 **Explicit control** - You manage the service principal lifecycle
- 🏢 **Production-ready** - Recommended for real deployments
- 🔄 **CI/CD friendly** - Non-interactive authentication
- 👥 **Team sharing** - Can be shared across team members

### ⚠️ Considerations
- 🛠️ **More setup** - Requires manual service principal creation
- 🔑 **Need permissions** - Requires admin rights to create SP
- 📝 **More variables** - Need to manage Client ID and Secret

### 📝 Step-by-Step Setup

#### 1. Prerequisites
```bash
# Ensure you have Azure CLI installed
az --version

# Login to Azure
az login

# Ensure you have permissions to create service principals
# You need one of these roles:
# - Application Administrator
# - Cloud Application Administrator
# - Global Administrator
```

#### 2. Get Your Subscription ID
```bash
# List your subscriptions
az account list --output table

# Set the subscription you want to use
az account set --subscription "YOUR_SUBSCRIPTION_NAME_OR_ID"

# Get subscription details
az account show
```

#### 3. Create the Service Principal
```bash
# Create service principal with Contributor role
az ad sp create-for-rbac \
  --name "tofu-controller-sp" \
  --role Contributor \
  --scopes /subscriptions/$(az account show --query id -o tsv)
```

**Expected output:**
```json
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "tofu-controller-sp",
  "password": "your-client-secret-here",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```

**⚠️ Important:** Save these values immediately! The password cannot be retrieved later.

#### 4. Set Environment Variables
```bash
# Set all required variables
export GITHUB_TOKEN="your-github-token"
export GITHUB_USER="your-github-username"
export GITHUB_REPO="tofu-controller-example"

export AZURE_SUBSCRIPTION_ID="from-az-account-show"
export AZURE_TENANT_ID="from-sp-output-tenant"
export AZURE_CLIENT_ID="from-sp-output-appId"
export AZURE_CLIENT_SECRET="from-sp-output-password"
```

Or create a `.env` file:
```bash
cat > .env << 'EOF'
export GITHUB_TOKEN="your-github-token"
export GITHUB_USER="your-username"
export GITHUB_REPO="tofu-controller-example"

export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
EOF

# Load it
source .env
```

#### 5. Verify the Service Principal
```bash
# Test the service principal login
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Check the account
az account show
```

#### 6. Run the Demo
```bash
./scripts/99-run-demo.sh
```

### 🔄 Managing the Service Principal

#### View Service Principal Details
```bash
# Show service principal info
az ad sp show --id $AZURE_CLIENT_ID

# List all service principals
az ad sp list --display-name "tofu-controller-sp" --output table
```

#### Reset Credentials
```bash
# If you need to reset the password
az ad sp credential reset --id $AZURE_CLIENT_ID
```

#### Add Additional Permissions
```bash
# Add a role assignment
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "Reader" \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/my-rg
```

#### Delete Service Principal
```bash
# When you're done with the demo
az ad sp delete --id $AZURE_CLIENT_ID
```

---

## Comparison Table

| Feature | Azure CLI Auth | Service Principal |
|---------|---------------|-------------------|
| **Setup Time** | 2 minutes | 5 minutes |
| **Prerequisites** | `az login` | SP creation permissions |
| **Credential Type** | Your user account + auto SP | Dedicated SP |
| **Security** | Good for demo | Best for production |
| **Automation** | ✅ Fully automated | ⚠️ Manual SP creation |
| **CI/CD Ready** | ❌ Not recommended | ✅ Yes |
| **Cleanup** | Manual SP deletion | Manual SP deletion |
| **Best For** | Learning, testing | Production, teams |

---

## Troubleshooting

### Azure CLI Method

**Problem:** "az login" fails
```bash
# Solution: Clear Azure CLI cache
az account clear
az login
```

**Problem:** "Insufficient privileges to create service principal"
```bash
# Solution: Ask your Azure admin to create one for you,
# then use Option 2 (Service Principal method)
```

**Problem:** Can't find the created service principal
```bash
# List all service principals with "tofu" in the name
az ad sp list --filter "startswith(displayName,'tofu')" --output table
```

### Service Principal Method

**Problem:** "Insufficient privileges" when creating SP
```bash
# Solution: You need Application Administrator role or higher
# Ask your Azure admin to:
# 1. Create the service principal for you, OR
# 2. Grant you the required permissions
```

**Problem:** Can't login with service principal
```bash
# Verify the credentials
echo "Client ID: $AZURE_CLIENT_ID"
echo "Tenant ID: $AZURE_TENANT_ID"
echo "Secret length: ${#AZURE_CLIENT_SECRET}"

# Try logging in with verbose output
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID \
  --debug
```

**Problem:** Service principal has no permissions
```bash
# Check role assignments
az role assignment list --assignee $AZURE_CLIENT_ID --output table

# Add Contributor role if missing
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role Contributor \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID
```

---

## Security Best Practices

### For Both Methods

1. **Never commit credentials to Git**
   - The `.env` file is in `.gitignore`
   - Always use environment variables or secrets

2. **Use minimal permissions**
   - Grant only the permissions needed
   - Consider using custom roles instead of Contributor

3. **Rotate credentials regularly**
   - For service principals, reset passwords periodically
   - Use Azure Key Vault for production

4. **Clean up when done**
   - Delete service principals after demo
   - Remove role assignments

### For Production Use

1. **Use Service Principal, not CLI auth**
2. **Store credentials in Azure Key Vault**
3. **Use Managed Identities when possible** (for AKS)
4. **Enable audit logging**
5. **Use separate SPs for different environments**

---

## Next Steps

After authenticating:

1. **Continue with the demo**: `./scripts/99-run-demo.sh`
2. **Read the main README**: [README.md](README.md)
3. **Check the quick start**: [QUICKSTART.md](QUICKSTART.md)

---

## Additional Resources

- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Service Principal Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Azure RBAC](https://docs.microsoft.com/en-us/azure/role-based-access-control/overview)
- [Terraform Azure Provider Auth](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret)

# Project Overview

## What This Demo Provides

A complete, production-ready example of using **Flux Tofu-Controller** to manage Azure infrastructure through GitOps principles in Kubernetes.

## 📁 Project Structure

```
tofu-controller-example/
│
├── 📄 Documentation
│   ├── README.md              # Main documentation with architecture
│   ├── QUICKSTART.md          # 10-minute quick start guide
│   ├── COMMANDS.md            # Comprehensive command reference
│   ├── TROUBLESHOOTING.md     # Detailed troubleshooting guide
│   └── OVERVIEW.md            # This file
│
├── 🔧 Configuration
│   ├── .env.example           # Environment variables template
│   ├── .gitignore            # Git ignore patterns
│   └── LICENSE               # MIT License
│
├── 🚀 Scripts (./scripts/)
│   ├── 00-setup-prerequisites.sh    # Check/install prerequisites
│   ├── 01-bootstrap-flux.sh         # Bootstrap Flux on cluster
│   ├── 02-install-tofu-controller.sh # Install Tofu-Controller
│   ├── 03-create-azure-secrets.sh   # Create Azure credentials
│   ├── 98-cleanup.sh                # Cleanup all resources
│   └── 99-run-demo.sh               # Run complete demo
│
├── 📦 Terraform Modules (./terraform/)
│   ├── 01-resource-group/     # Azure Resource Group module
│   ├── 02-storage-account/    # Azure Storage Account module
│   └── 03-virtual-network/    # Azure Virtual Network module
│
└── ☸️  Kubernetes Manifests (./manifests/)
    ├── sources/
    │   └── gitrepository.yaml          # Flux GitRepository source
    └── terraform/
        ├── 01-resource-group.yaml      # Terraform CR for RG
        ├── 02-storage-account.yaml     # Terraform CR for Storage
        ├── 03-virtual-network.yaml     # Terraform CR for VNet
        └── examples.yaml               # Additional examples
```

## 🎯 Key Features Demonstrated

### 1. GitOps Automation
- ✅ Automatic Terraform plan and apply
- ✅ Infrastructure as Code via Git
- ✅ Declarative resource management
- ✅ Version-controlled infrastructure

### 2. Drift Detection & Remediation
- ✅ Automatic drift detection (10-minute interval)
- ✅ Auto-remediation of configuration drift
- ✅ Manual approval mode option
- ✅ Drift detection only mode

### 3. Multi-Resource Management
- ✅ Resource dependencies (dependsOn)
- ✅ Multiple Terraform modules
- ✅ Parallel resource provisioning
- ✅ Output sharing between resources

### 4. Azure Integration
- ✅ Service Principal authentication
- ✅ Multiple Azure resource types
- ✅ Secure credential management
- ✅ Azure-specific runner image

## 🏗️ Infrastructure Components

### Azure Resources Created

| Resource | Purpose | Managed By |
|----------|---------|------------|
| Resource Group | Container for all resources | Terraform CR #1 |
| Storage Account | Blob storage with container | Terraform CR #2 |
| Virtual Network | Network with subnet and NSG | Terraform CR #3 |

### Kubernetes Resources Created

| Resource | Namespace | Purpose |
|----------|-----------|---------|
| HelmRepository | flux-system | Tofu-Controller chart source |
| HelmRelease | flux-system | Tofu-Controller installation |
| GitRepository | flux-system | Source for Terraform modules |
| Terraform (x3) | flux-system | Terraform resource definitions |
| Secret (azure-credentials) | flux-system | Azure authentication |
| Secret (tfstate-*) | flux-system | Terraform state storage |
| Secret (*-outputs) | flux-system | Terraform output values |

## 🔄 GitOps Workflow

```
┌─────────────┐
│  Developer  │
│   commits   │
│   changes   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Git Repo    │◄──────────┐
│  (GitHub)   │           │
└──────┬──────┘           │
       │                  │
       │ Flux syncs       │ Flux pushes
       ▼                  │ status
┌─────────────┐           │
│    Flux     │───────────┘
│  Source     │
│ Controller  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Tofu      │
│ Controller  │
└──────┬──────┘
       │
       ├─────► Plan ─────► Apply ─────┐
       │                               │
       └─────► Drift Detection ────────┤
                                       │
                                       ▼
                              ┌─────────────┐
                              │   Azure     │
                              │  Resources  │
                              └─────────────┘
```

## 🎓 Learning Objectives

After completing this demo, you will understand:

1. **Flux Basics**
   - How to bootstrap Flux on Kubernetes
   - GitRepository source configuration
   - HelmRepository and HelmRelease

2. **Tofu-Controller**
   - Terraform custom resource definition
   - Runner pod architecture
   - State management in Kubernetes
   - Plan approval workflows

3. **GitOps Patterns**
   - Declarative infrastructure
   - Git as single source of truth
   - Automated reconciliation
   - Drift detection and remediation

4. **Azure & Kubernetes Integration**
   - Service Principal authentication
   - Secure secret management
   - Multi-cloud GitOps patterns

## 📊 Demo Scenarios

### Scenario 1: Full Automation (Default)
```yaml
spec:
  approvePlan: auto
  disableDriftDetection: false
```
- Automatically applies all changes
- Detects and fixes drift
- Best for: Stable, well-tested infrastructure

### Scenario 2: Manual Approval
```yaml
spec:
  approvePlan: ""  # Set to plan ID to approve
  disableDriftDetection: false
```
- Requires manual approval for applies
- Still detects drift
- Best for: Production environments requiring review

### Scenario 3: Drift Detection Only
```yaml
spec:
  approvePlan: "disable"
  disableDriftDetection: false
```
- Only detects drift, doesn't remediate
- Read-only monitoring
- Best for: Audit and compliance

## 🛠️ Prerequisites

### Required Tools
- Kubernetes cluster (1.26+)
- kubectl CLI
- Flux CLI (2.0+)
- Azure CLI (2.50+)
- Git
- GitHub account

### Azure Requirements
- Active subscription
- Service Principal with Contributor role
- Following credentials:
  - Subscription ID
  - Tenant ID
  - Client ID
  - Client Secret

## 🚀 Quick Start

```bash
# 1. Set environment variables
export GITHUB_TOKEN="your-token"
export GITHUB_USER="your-username"
export AZURE_SUBSCRIPTION_ID="your-sub-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-secret"

# 2. Run the demo
./scripts/99-run-demo.sh

# 3. Monitor
kubectl get terraform -n flux-system -w
```

## 📈 Customization Options

### Add New Azure Resources

1. Create Terraform module in `terraform/04-my-resource/`
2. Create Terraform CR in `manifests/terraform/04-my-resource.yaml`
3. Commit and push to Git
4. Apply: `kubectl apply -f manifests/terraform/04-my-resource.yaml`

### Change Reconciliation Settings

```bash
# Change interval
kubectl patch terraform azure-resource-group -n flux-system \
  --type merge -p '{"spec":{"interval":"30m"}}'

# Change retry interval
kubectl patch terraform azure-resource-group -n flux-system \
  --type merge -p '{"spec":{"retryInterval":"30s"}}'
```

### Switch to Manual Approval

```bash
kubectl patch terraform azure-resource-group -n flux-system \
  --type merge -p '{"spec":{"approvePlan":""}}'
```

## 🧹 Cleanup

```bash
./scripts/98-cleanup.sh
```

This will:
1. Delete Terraform CRs (destroys Azure infrastructure)
2. Delete GitRepository source
3. Optionally uninstall Tofu-Controller
4. Optionally uninstall Flux

## 📚 Additional Resources

- [Tofu-Controller Docs](https://flux-iac.github.io/tofu-controller/)
- [Flux Documentation](https://fluxcd.io/flux/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitOps Principles](https://opengitops.dev/)

## 🤝 Contributing

Contributions are welcome! This is a demo project designed for learning and can be extended with:
- Additional Azure resources
- Multi-cloud examples
- Advanced Terraform patterns
- CI/CD integrations

## 📝 License

MIT License - See LICENSE file for details.

## ⚡ Tips for Success

1. **Start Small**: Run the basic demo first before customizing
2. **Monitor Logs**: Keep controller logs open to understand what's happening
3. **Test Drift**: Manually change resources to see drift detection in action
4. **Read Events**: Use `kubectl describe` to see detailed status and events
5. **Use Flux CLI**: Leverage `flux` commands for easier management

## 🎯 Next Steps

After completing this demo:

1. ✅ Explore different approval modes
2. ✅ Add custom Azure resources
3. ✅ Integrate with your CI/CD pipeline
4. ✅ Set up notifications (Slack, Teams)
5. ✅ Implement multi-environment setup
6. ✅ Add policy as code (OPA, Kyverno)
7. ✅ Explore advanced Terraform patterns

---

**Ready to get started?** Head to [QUICKSTART.md](QUICKSTART.md) for a 10-minute setup guide!

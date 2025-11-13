# Useful Commands for Tofu-Controller Demo

## Monitoring and Debugging

### Watch Terraform Resources
```bash
# Watch all Terraform resources
kubectl get terraform -n flux-system -w

# Get detailed info about a specific resource
kubectl describe terraform azure-resource-group -n flux-system

# Get all Terraform resources with their status
kubectl get terraform -n flux-system -o wide
```

### View Logs
```bash
# Tofu-Controller logs
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller -f

# Specific runner pod logs
kubectl logs -n flux-system -l terraform.io/terraform=azure-resource-group -f

# All pods in flux-system
kubectl get pods -n flux-system
```

### Check Flux Status
```bash
# Check all Flux components
flux check

# Get all Flux resources
flux get all

# Reconcile a specific resource immediately
flux reconcile terraform azure-resource-group -n flux-system
flux reconcile source git tofu-demo
```

## Terraform Resource Management

### View Terraform Outputs
```bash
# Terraform outputs are stored as Kubernetes secrets
kubectl get secret azure-rg-outputs -n flux-system -o yaml
kubectl get secret azure-storage-outputs -n flux-system -o yaml
kubectl get secret azure-vnet-outputs -n flux-system -o yaml

# Decode a specific output value
kubectl get secret azure-rg-outputs -n flux-system -o jsonpath='{.data.resource_group_name}' | base64 -d
```

### View Terraform State
```bash
# State files are stored as secrets with the prefix tfstate-
kubectl get secrets -n flux-system | grep tfstate

# View state for a specific resource
kubectl get secret tfstate-default-azure-resource-group -n flux-system -o yaml
```

### Manual Approval Workflow
```bash
# 1. Create a Terraform resource with approvePlan: ""
kubectl apply -f manifests/terraform/examples.yaml

# 2. Wait for plan to be generated
kubectl get terraform azure-manual-approval-example -n flux-system

# 3. Check events for the plan ID
kubectl describe terraform azure-manual-approval-example -n flux-system

# 4. Approve the plan by setting approvePlan to the plan ID
kubectl patch terraform azure-manual-approval-example -n flux-system \
  --type merge -p '{"spec":{"approvePlan":"plan-main-xxxxx"}}'

# Or edit directly
kubectl edit terraform azure-manual-approval-example -n flux-system
```

## Drift Detection

### Test Drift Detection
```bash
# 1. Manually change a resource in Azure
az tag create --resource-id /subscriptions/xxx/resourceGroups/tofu-demo-rg \
  --tags manual-tag=test

# 2. Trigger reconciliation (or wait for interval)
flux reconcile terraform azure-resource-group -n flux-system

# 3. Watch the plan being generated and applied
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller -f

# 4. Verify drift was fixed
kubectl describe terraform azure-resource-group -n flux-system
```

### Disable Drift Detection
```bash
kubectl patch terraform azure-resource-group -n flux-system \
  --type merge -p '{"spec":{"disableDriftDetection":true}}'
```

## Azure Verification

### Check Azure Resources
```bash
# List all resource groups
az group list --output table

# Show specific resource group
az group show --name tofu-demo-rg

# List storage accounts
az storage account list --resource-group tofu-demo-rg --output table

# List virtual networks
az network vnet list --resource-group tofu-demo-rg --output table

# Show all resources in the resource group
az resource list --resource-group tofu-demo-rg --output table
```

## Troubleshooting

### Runner Pod Issues
```bash
# Get runner pods
kubectl get pods -n flux-system -l terraform.io/terraform

# Describe a runner pod
kubectl describe pod <pod-name> -n flux-system

# Get logs from a failed runner
kubectl logs <pod-name> -n flux-system

# Check service account
kubectl get sa tf-runner -n flux-system -o yaml
```

### Authentication Issues
```bash
# Verify secrets exist
kubectl get secret azure-credentials -n flux-system

# Check secret contents (redacted)
kubectl get secret azure-credentials -n flux-system -o json | jq '.data | keys'

# Test Azure credentials manually
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID
```

### State Lock Issues
```bash
# If state is locked, you may need to force unlock
# WARNING: Only do this if you're sure no other process is running

# Delete the runner pod to release the lock
kubectl delete pod -n flux-system -l terraform.io/terraform=azure-resource-group

# Check state secret for lock info
kubectl get secret tfstate-default-azure-resource-group -n flux-system -o yaml
```

### Suspend/Resume Reconciliation
```bash
# Suspend reconciliation
flux suspend terraform azure-resource-group -n flux-system

# Resume reconciliation
flux resume terraform azure-resource-group -n flux-system

# Check if suspended
kubectl get terraform azure-resource-group -n flux-system -o jsonpath='{.spec.suspend}'
```

## Advanced Operations

### Force Reconciliation
```bash
# Force reconcile all Terraform resources
flux reconcile terraform --all -n flux-system

# Force reconcile source
flux reconcile source git tofu-demo -n flux-system
```

### Export Terraform Resource
```bash
# Export to YAML
kubectl get terraform azure-resource-group -n flux-system -o yaml > backup.yaml

# Export all Terraform resources
kubectl get terraform -n flux-system -o yaml > all-terraform-resources.yaml
```

### Update Variables
```bash
# Update a variable value
kubectl patch terraform azure-resource-group -n flux-system \
  --type json -p '[{"op":"replace","path":"/spec/vars/0/value","value":"westus"}]'

# Or edit directly
kubectl edit terraform azure-resource-group -n flux-system
```

### Change Intervals
```bash
# Change reconciliation interval
kubectl patch terraform azure-resource-group -n flux-system \
  --type merge -p '{"spec":{"interval":"5m"}}'

# Change retry interval
kubectl patch terraform azure-resource-group -n flux-system \
  --type merge -p '{"spec":{"retryInterval":"30s"}}'
```

## Cleanup Commands

### Delete Specific Resources
```bash
# Delete a single Terraform resource (triggers destroy)
kubectl delete terraform azure-storage-account -n flux-system

# Delete without destroying Azure resources
kubectl patch terraform azure-resource-group -n flux-system \
  --type merge -p '{"spec":{"destroyResourcesOnDeletion":false}}'
kubectl delete terraform azure-resource-group -n flux-system
```

### Clean State Secrets
```bash
# Delete all state secrets
kubectl delete secrets -n flux-system -l terraform.io/terraform

# Delete output secrets
kubectl delete secret azure-rg-outputs azure-storage-outputs azure-vnet-outputs -n flux-system
```

## Performance Monitoring

### Check Resource Usage
```bash
# Controller resource usage
kubectl top pod -n flux-system -l app.kubernetes.io/name=tofu-controller

# Runner pod resource usage
kubectl top pod -n flux-system -l terraform.io/terraform
```

### Events
```bash
# Get events for flux-system namespace
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events -n flux-system --watch

# Events for specific resource
kubectl get events -n flux-system --field-selector involvedObject.name=azure-resource-group
```

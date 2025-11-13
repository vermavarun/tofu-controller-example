# Troubleshooting Guide

Common issues and solutions for the Flux Tofu-Controller demo.

## Table of Contents
- [Installation Issues](#installation-issues)
- [Authentication Issues](#authentication-issues)
- [Terraform Apply Failures](#terraform-apply-failures)
- [Drift Detection Issues](#drift-detection-issues)
- [Performance Issues](#performance-issues)
- [State Management Issues](#state-management-issues)

## Installation Issues

### Flux Bootstrap Fails

**Symptom**: `flux bootstrap` command fails

**Possible Causes**:
1. Invalid GitHub token
2. Insufficient permissions on the repository
3. Kubernetes cluster not accessible

**Solutions**:
```bash
# Verify GitHub token has correct scopes (repo, admin:repo_hook)
echo $GITHUB_TOKEN | cut -c1-10  # Should show token prefix

# Check cluster connectivity
kubectl cluster-info

# Verify Flux prerequisites
flux check --pre

# Try with more verbose output
flux bootstrap github --verbose \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/demo \
  --personal
```

### Tofu-Controller Installation Fails

**Symptom**: HelmRelease is not ready

**Solution**:
```bash
# Check HelmRelease status
kubectl describe helmrelease tofu-controller -n flux-system

# Check HelmRepository
kubectl get helmrepository -n flux-system

# View controller logs
kubectl logs -n flux-system deploy/helm-controller

# Manually pull the chart
helm repo add tofu-controller https://flux-iac.github.io/tofu-controller
helm repo update
helm search repo tofu-controller
```

### CRD Not Found

**Symptom**: `error: unable to recognize "manifests/terraform/01-resource-group.yaml": no matches for kind "Terraform"`

**Solution**:
```bash
# Verify CRD is installed
kubectl get crd terraforms.infra.contrib.fluxcd.io

# If missing, check HelmRelease
kubectl describe helmrelease tofu-controller -n flux-system

# Manually install CRD (if needed)
kubectl apply -f https://raw.githubusercontent.com/flux-iac/tofu-controller/main/config/crd/bases/infra.contrib.fluxcd.io_terraforms.yaml
```

## Authentication Issues

### Azure Authentication Fails

**Symptom**: Terraform plan fails with authentication errors

**Solutions**:
```bash
# Verify secret exists
kubectl get secret azure-credentials -n flux-system

# Check secret has all required keys
kubectl get secret azure-credentials -n flux-system -o json | jq '.data | keys'
# Should show: ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_SUBSCRIPTION_ID, ARM_TENANT_ID

# Test credentials locally
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

az account show

# Recreate secret
./scripts/03-create-azure-secrets.sh

# Check runner pod logs
kubectl logs -n flux-system -l terraform.io/terraform=azure-resource-group
```

### Service Account Issues

**Symptom**: Runner pod fails with permission errors

**Solution**:
```bash
# Verify service account exists
kubectl get sa tf-runner -n flux-system

# Check service account in Terraform spec
kubectl get terraform azure-resource-group -n flux-system -o jsonpath='{.spec.serviceAccountName}'

# Recreate if needed
kubectl delete sa tf-runner -n flux-system
# Will be recreated by HelmRelease
kubectl delete pod -n flux-system -l app.kubernetes.io/name=tofu-controller
```

## Terraform Apply Failures

### Plan Generation Fails

**Symptom**: Terraform resource shows "PlanFailed" status

**Diagnostics**:
```bash
# Get detailed status
kubectl describe terraform azure-resource-group -n flux-system

# Check runner pod logs
kubectl logs -n flux-system -l terraform.io/terraform=azure-resource-group

# Check events
kubectl get events -n flux-system --field-selector involvedObject.name=azure-resource-group
```

**Common Issues**:

1. **Module not found**
   - Verify path in Terraform spec matches repository structure
   - Check GitRepository is synced: `kubectl get gitrepository -n flux-system`

2. **Provider initialization fails**
   - Check Azure credentials
   - Verify network connectivity from runner pod

3. **Invalid Terraform syntax**
   - Validate locally: `cd terraform/01-resource-group && terraform validate`

### Apply Fails

**Symptom**: Plan succeeds but apply fails

**Solutions**:
```bash
# Check runner pod logs for detailed error
kubectl logs -n flux-system -l terraform.io/terraform=azure-resource-group --tail=100

# Common Azure issues:
# - Quota exceeded
az vm list-usage --location eastus --output table

# - Resource name conflict
az group show --name tofu-demo-rg

# - Insufficient permissions
az role assignment list --assignee $AZURE_CLIENT_ID
```

### Dependencies Not Met

**Symptom**: Resource fails because dependency isn't ready

**Solution**:
```bash
# Check dependency status
kubectl get terraform -n flux-system

# Resource with dependsOn waits for others to be ready
# Verify dependency is actually ready:
kubectl describe terraform azure-resource-group -n flux-system | grep -A 10 Conditions

# Check retry interval (increase if needed)
kubectl patch terraform azure-storage-account -n flux-system \
  --type merge -p '{"spec":{"retryInterval":"30s"}}'
```

## Drift Detection Issues

### Drift Not Detected

**Symptom**: Manual changes to Azure resources not detected

**Solutions**:
```bash
# Check drift detection is enabled
kubectl get terraform azure-resource-group -n flux-system -o jsonpath='{.spec.disableDriftDetection}'
# Should be empty or false

# Check reconciliation interval
kubectl get terraform azure-resource-group -n flux-system -o jsonpath='{.spec.interval}'

# Force reconciliation
flux reconcile terraform azure-resource-group -n flux-system

# Check controller logs
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller -f
```

### Drift Remediation Fails

**Symptom**: Drift detected but not fixed

**Solutions**:
```bash
# Check approvePlan setting
kubectl get terraform azure-resource-group -n flux-system -o jsonpath='{.spec.approvePlan}'
# Should be "auto" for automatic remediation

# Check for apply errors in events
kubectl describe terraform azure-resource-group -n flux-system

# Manually trigger remediation
kubectl annotate terraform azure-resource-group -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
```

## Performance Issues

### Slow Reconciliation

**Symptom**: Terraform resources take too long to reconcile

**Solutions**:
```bash
# Check runner pod resources
kubectl get terraform azure-resource-group -n flux-system -o yaml | grep -A 5 resources

# Increase runner pod resources
kubectl patch terraform azure-resource-group -n flux-system \
  --type merge -p '{
    "spec":{
      "runnerPodTemplate":{
        "spec":{
          "resources":{
            "limits":{"cpu":"1000m","memory":"1Gi"},
            "requests":{"cpu":"200m","memory":"256Mi"}
          }
        }
      }
    }
  }'

# Check cluster resource availability
kubectl top nodes
kubectl top pods -n flux-system
```

### Too Many Runner Pods

**Symptom**: Many runner pods running simultaneously

**Solutions**:
```bash
# Adjust reconciliation intervals
# Increase interval to reduce frequency
kubectl patch terraform azure-resource-group -n flux-system \
  --type merge -p '{"spec":{"interval":"30m"}}'

# Suspend resources not actively needed
flux suspend terraform azure-virtual-network -n flux-system

# Clean up old runner pods (they should auto-delete, but check)
kubectl delete pod -n flux-system -l terraform.io/terraform --field-selector=status.phase=Succeeded
```

## State Management Issues

### State Lock Issues

**Symptom**: "Error acquiring the state lock"

**Solutions**:
```bash
# Check for stuck runner pods
kubectl get pods -n flux-system -l terraform.io/terraform

# Delete stuck runner pod (releases lock)
kubectl delete pod -n flux-system -l terraform.io/terraform=azure-resource-group

# Check state secret
kubectl get secret tfstate-default-azure-resource-group -n flux-system

# If lock persists, may need to force unlock (DANGEROUS!)
# This should be a last resort
```

### State Out of Sync

**Symptom**: Terraform state doesn't match actual resources

**Solutions**:
```bash
# Check if Azure resources exist
az resource list --resource-group tofu-demo-rg

# View state secret
kubectl get secret tfstate-default-azure-resource-group -n flux-system -o yaml

# Import existing resources (create a new Terraform resource pointing to existing infra)
# Or delete state and re-apply (will recreate resources)

# Last resort: Manually update state (not recommended)
# Better to delete and recreate the Terraform resource
kubectl delete terraform azure-resource-group -n flux-system
kubectl apply -f manifests/terraform/01-resource-group.yaml
```

### Missing State Secret

**Symptom**: State secret not found after successful apply

**Solutions**:
```bash
# Check for state secrets
kubectl get secrets -n flux-system | grep tfstate

# Verify Terraform resource has succeeded
kubectl get terraform -n flux-system

# Check controller logs for errors
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller --tail=100

# If state lost, Terraform will try to recreate resources
# Import existing resources or delete and recreate
```

## General Debugging Tips

### Enable Debug Logging

```bash
# Increase controller log level
kubectl patch helmrelease tofu-controller -n flux-system \
  --type merge -p '{"spec":{"values":{"logLevel":"debug"}}}'

# Wait for controller to restart
kubectl rollout status deploy/tofu-controller -n flux-system
```

### Collect Diagnostics

```bash
# Create a diagnostics bundle
mkdir -p diagnostics
kubectl get all -n flux-system > diagnostics/resources.txt
kubectl get terraform -n flux-system -o yaml > diagnostics/terraform-resources.yaml
kubectl get events -n flux-system > diagnostics/events.txt
kubectl logs -n flux-system -l app.kubernetes.io/name=tofu-controller > diagnostics/controller.log

# Compress and share
tar czf diagnostics.tar.gz diagnostics/
```

### Fresh Start

If all else fails, clean up and start over:

```bash
# Run cleanup script
./scripts/98-cleanup.sh

# Verify cleanup
kubectl get terraform -n flux-system
az group show --name tofu-demo-rg

# Start fresh
./scripts/99-run-demo.sh
```

## Getting Help

If you're still stuck:

1. Check the [Tofu-Controller documentation](https://flux-iac.github.io/tofu-controller/)
2. Search [GitHub issues](https://github.com/flux-iac/tofu-controller/issues)
3. Ask in the [Weave Community Slack](https://weave-community.slack.com/archives/C054MR4UP88)
4. Review [Flux documentation](https://fluxcd.io/flux/)

When asking for help, include:
- Kubernetes version: `kubectl version`
- Flux version: `flux --version`
- Tofu-Controller version: `kubectl get helmrelease tofu-controller -n flux-system -o jsonpath='{.spec.chart.spec.version}'`
- Error messages from `kubectl describe terraform <name> -n flux-system`
- Controller logs
- Runner pod logs

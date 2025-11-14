#!/bin/bash

# Script to install Tofu-Controller on Flux-enabled Kubernetes cluster

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================"
echo "Tofu-Controller Installation Script"
echo -e "======================================${NC}"
echo ""

FLUX_NAMESPACE=${FLUX_NAMESPACE:-"flux-system"}
TOFU_VERSION=${TOFU_VERSION:-"v0.16.0-rc.4"}

# Check if Flux is installed
echo -e "${BLUE}Checking Flux installation...${NC}"
if ! kubectl get namespace $FLUX_NAMESPACE >/dev/null 2>&1; then
    echo -e "${RED}Error: Flux namespace not found${NC}"
    echo "Please run ./scripts/01-bootstrap-flux.sh first"
    exit 1
fi

echo -e "${GREEN}✓ Flux is installed${NC}"
echo ""

# Install tofu-controller using Flux
echo -e "${BLUE}Installing Tofu-Controller ${TOFU_VERSION}...${NC}"
echo ""

# Create HelmRepository for tofu-controller
cat <<EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: tofu-controller
  namespace: $FLUX_NAMESPACE
spec:
  interval: 1h
  url: https://flux-iac.github.io/tofu-controller
EOF

echo -e "${GREEN}✓ HelmRepository created${NC}"

# Wait for HelmRepository to be ready
echo -e "${BLUE}Waiting for HelmRepository to be ready...${NC}"
kubectl wait --for=condition=ready --timeout=2m \
  -n $FLUX_NAMESPACE helmrepository/tofu-controller

echo -e "${GREEN}✓ HelmRepository is ready${NC}"
echo ""

# Install tofu-controller HelmRelease
echo -e "${BLUE}Creating HelmRelease for tofu-controller...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: tofu-controller
  namespace: $FLUX_NAMESPACE
spec:
  interval: 10m
  chart:
    spec:
      chart: tofu-controller
      version: "0.16.0-rc.4"
      sourceRef:
        kind: HelmRepository
        name: tofu-controller
        namespace: $FLUX_NAMESPACE
      interval: 1m
  install:
    crds: Create
    remediation:
      retries: 3
  upgrade:
    crds: CreateReplace
    remediation:
      retries: 3
  values:
    runner:
      serviceAccount:
        create: true
        name: tf-runner
      image:
        repository: ghcr.io/flux-iac/tf-runner-azure
        tag: v0.16.0-rc.4
    # Enable more verbose logging for demo
    logLevel: info
    # Resources for the controller
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 200m
        memory: 256Mi
EOF

echo -e "${GREEN}✓ HelmRelease created${NC}"
echo ""

# Wait for HelmRelease to be ready
echo -e "${BLUE}Waiting for HelmRelease to be ready (this may take a few minutes)...${NC}"
kubectl wait --for=condition=ready --timeout=5m \
  -n $FLUX_NAMESPACE helmrelease/tofu-controller

echo -e "${GREEN}✓ HelmRelease is ready${NC}"
echo ""

# Wait for tofu-controller pod to be ready
echo -e "${BLUE}Waiting for tofu-controller pod to be ready...${NC}"
kubectl wait --for=condition=ready --timeout=3m \
  -n $FLUX_NAMESPACE pod -l app.kubernetes.io/name=tofu-controller

echo -e "${GREEN}✓ Tofu-Controller pod is ready${NC}"
echo ""

# Show status
echo -e "${BLUE}Tofu-Controller status:${NC}"
kubectl get pods -n $FLUX_NAMESPACE -l app.kubernetes.io/name=tofu-controller
echo ""

kubectl get helmrelease -n $FLUX_NAMESPACE tofu-controller
echo ""

# Check CRDs
echo -e "${BLUE}Terraform CRD installed:${NC}"
kubectl get crd terraforms.infra.contrib.fluxcd.io

echo ""
echo -e "${GREEN}======================================"
echo "Tofu-Controller Installation Complete!"
echo -e "======================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Configure Azure credentials: ./scripts/03-create-azure-secrets.sh"
echo "  2. Deploy Terraform resources: kubectl apply -f manifests/"
echo ""

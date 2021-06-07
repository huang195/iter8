#!/bin/bash

set -e 

# Step 0: Ensure environment and arguments are well-defined

## 0(a). Ensure ITER8 environment variable is set
if [[ -z ${ITER8} ]]; then
    echo "ITER8 environment variable needs to be set to the root folder of Iter8"
    exit 1
else
    echo "ITER8 is set to " $ITER8
fi

## 0(b). Ensure Kubernetes cluster is available
OPENSHIFT_STATUS=$(oc version | awk '/^Server /' -)
if [[ -z ${OPENSHIFT_STATUS} ]]; then
    echo "Openshift cluster is unavailable"
    exit 1
else
    echo "Openshift cluster is available"
fi

## 0(b). Ensure Kustomize v3 or v4 is available
KUSTOMIZE_VERSION=$(kustomize  version | cut -d. -f1 | tail -c 2)
if [[ ${KUSTOMIZE_VERSION} -ge "3" ]]; then
    echo "Kustomize v3+ available"
else
    echo "Kustomize v3+ is unavailable"
    exit 1
fi

# Step 1: Export correct tags for install artifacts
export ISTIO_VERSION="${ISTIO_VERSION:-1.9.4}"
echo "ISTIO_VERSION=$ISTIO_VERSION"

# Step 2: Install Istio (https://istio.io/latest/docs/setup/getting-started/)
echo "Installing Istio"
WORK_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
cd istio-${ISTIO_VERSION}
export PATH=$PWD/bin:$PATH
cd $WORK_DIR

# Allow Istio service account to run with user ID 0
oc adm policy add-scc-to-group anyuid system:serviceaccounts:istio-system

# Install Istio with Openshift profile
istioctl install -y --set profile=openshift

# Expose Openshift Route for Istio ingress gateway
if [ `oc -n istio-system get route istio-ingressgateway | wc -l` == 0 ];
then
    oc -n istio-system expose svc/istio-ingressgateway --port=http2
fi
echo "Istio installed successfully"

# Verify readiness of Istio pods
echo "Waiting for all Istio pods to be running..."
oc wait --for condition=ready --timeout=300s pods --all -n istio-system

# Step 3: Install Iter8
echo "Installing Iter8 with Istio Support"
kustomize build $ITER8/install/core | oc apply -f -

# Verify Iter8 installation
echo "Verifying Iter8 and add-on installation"
oc wait --for condition=ready --timeout=300s pods --all -n iter8-system

# Step 4: Install Argo CD
echo "Installing latest Argo CD"
oc create namespace argocd --dry-run -o yaml | oc apply -f -
oc apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify Argo CD installation
echo "Verifying Argo CD installation"
oc wait --for condition=ready --timeout=300s pods --all -n argocd
echo "Your Argo CD installation is complete"
echo "Run the following commands: "
echo "  1. oc port-forward svc/argocd-server -n argocd 8080:443"
echo "  2. Open a browser with URL: http://localhost:8080 with the following credential"
echo "     Username: 'admin', Password: '`oc -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`'"

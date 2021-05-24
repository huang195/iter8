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
KUBERNETES_STATUS=$(kubectl version | awk '/^Server Version:/' -)
if [[ -z ${KUBERNETES_STATUS} ]]; then
    echo "Kubernetes cluster is unavailable"
    exit 1
else
    echo "Kubernetes cluster is available"
fi

# Step 1: Export correct tags for install artifacts
export TAG="${TAG:-v0.5.1}"
export ISTIO_VERSION="${ISTIO_VERSION:-1.9.4}"
echo "TAG = $TAG"
echo "ISTIO_TAG = $ISTIO_VERSION"

# Step 2: Install Istio (https://istio.io/latest/docs/setup/getting-started/)
echo "Installing Istio"
WORK_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
cd istio-${ISTIO_VERSION}
export PATH=$PWD/bin:$PATH
cd $WORK_DIR
istioctl install -y -f ${ITER8}/samples/istio/quickstart/istio-minimal-operator.yaml
echo "Istio installed successfully"

# Step 3: Ensure readiness of Istio pods
echo "Waiting for all Istio pods to be running..."
kubectl wait --for condition=ready --timeout=300s pods --all -n istio-system

### Note: the preceding steps perform domain install; following steps perform Iter8 install

# Step 4: Install Iter8
echo "Installing Iter8 with Istio Support"
kubectl apply -f https://raw.githubusercontent.com/iter8-tools/iter8-install/${TAG}/core/build.yaml

# Step 5: Install Iter8's Prometheus add-on
echo "Installing Iter8's Prometheus add-on"
kubectl apply -f https://raw.githubusercontent.com/iter8-tools/iter8-install/${TAG}/prometheus-add-on/prometheus-operator/build.yaml
kubectl wait crd -l creator=iter8 --for condition=established --timeout=120s
kubectl apply -f https://raw.githubusercontent.com/iter8-tools/iter8-install/${TAG}/prometheus-add-on/prometheus/build.yaml

kubectl apply -f ${ITER8}/samples/istio/quickstart/service-monitor.yaml

# Step 6: Install Iter8's mock New Relic service
#echo "Installing Iter8's mock New Relic service"
#kubectl apply -f ${ITER8}/samples/istio/quickstart/metrics-mock.yaml

# Step 7: Verify Iter8 installation
echo "Verifying Iter8 and add-on installation"
kubectl wait --for condition=ready --timeout=300s pods --all -n iter8-system
sleep 20
kubectl wait --for condition=ready --timeout=300s pods prometheus-iter8-prometheus-0 -n iter8-system

# Step 8: Install Argo CD
echo "Installing latest Argo CD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
#arch=`uname | awk '{print tolower($0)}'`
#if [ $arch  = "linux" ]; 
#then
    #arch="linux"
#else if [ $arch != "darwin" ];
    #then
        #echo "\"$arch\" is not a supported archicture"
        #exit 1
    #fi
#fi
#echo "Installing Argo CD CLI"
#VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argo-cd/releases/latest" | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
#curl -sSL -o ${ITER8}/argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-${arch}-amd64
#chmod +x ${ITER8}/argocd

# Step 9: Verify Argo CD installation
echo "Verifying Argo CD installation"
kubectl wait --for condition=ready --timeout=300s pods --all -n argocd
echo "Your Argo CD installation is complete"
echo "Run the following commands: "
echo "  1. kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  2. Open a browser with URL: http://localhost:8080 with the following credential"
echo "     Username: 'admin', Password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`"

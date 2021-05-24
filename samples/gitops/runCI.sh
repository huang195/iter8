#!/bin/sh

# point fortio to istio ingress
URL_VALUE="http://$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.spec.clusterIP}'):80/productpage"

# give fortio deployment a random name so it restarts it upon a new experiment
RANDOM=`od -An -N4 -i /dev/random`
sed "s|value: URL_VALUE|value: $URL_VALUE|" templates/fortio.yaml |\
sed "s|  name: fortio|  name: fortio-$RANDOM|" > ./fortio.yaml

# use a random color for a new experiment candidate
declare -a colors=("red" "orange" "blue" "green" "yellow" "violet" "brown")
color=`expr $RANDOM % ${#colors[@]}`
version=`cat templates/version`
version=`expr $version + 1`
sed "s|value: COLOR|value: \"${colors[$color]}\"|" templates/productpage-candidate.yaml |\
sed "s|version: v.*|version: v$version|" > ./productpage-candidate.yaml
echo $version > templates/version

# give experiment a random name so CI triggers new experiment each time a new app version is available
sed "s|name: gitops-exp|name: gitops-exp-$RANDOM|" templates/experiment.yaml > ./experiment.yaml

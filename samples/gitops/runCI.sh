#!/bin/sh

# use Fortio as a workload generator
cp templates/fortio.yaml ./fortio.yaml

# use a random color for a new experiment candidate
declare -a colors=("red" "orange" "blue" "green" "yellow" "violet" "brown")
color=`expr $RANDOM % ${#colors[@]}`
version=`git rev-parse HEAD`
sed "s|value: COLOR|value: \"${colors[$color]}\"|" templates/productpage-candidate.yaml |\
sed "s|version: v.*|version: v$version|" > ./productpage-candidate.yaml

# give experiment a random name so CI triggers new experiment each time a new app version is available
sed "s|name: gitops-exp|name: gitops-exp-$RANDOM|" templates/experiment.yaml > ./experiment.yaml

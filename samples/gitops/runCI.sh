#!/bin/sh

# use Fortio as a workload generator - use a random name so workload generator restarts on new experiment
cp templates/fortio.yaml ./fortio.yaml

# start a experiment targetting a fixed name baseline and candidate
cp templates/experiment.yaml ./experiment.yaml

# use a random color for a new experiment candidate
declare -a colors=("red" "orange" "blue" "green" "yellow" "violet" "brown")
color=`expr $RANDOM % ${#colors[@]}`
version=`git rev-parse HEAD`
sed "s|value: COLOR|value: \"${colors[$color]}\"|" templates/productpage-candidate.yaml |\
sed "s|version: v.*|version: v$version|" > ./productpage-candidate.yaml


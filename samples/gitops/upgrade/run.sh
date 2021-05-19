#!/bin/sh

kubectl delete -f f.yaml
kubectl delete -f experiment.yaml
kubectl apply -f f.yaml
kubectl apply -f experiment.yaml
kubectl get experiments.iter8.tools

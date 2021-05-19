#!/bin/sh

URL_VALUE="http://$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath='{.spec.clusterIP}'):80/productpage"
sed "s|value: URL_VALUE|value: $URL_VALUE|" upgrade/fortio.yaml > ./fortio.yaml
cp upgrade/productpage-candidate.yaml ./productpage-candidate.yaml

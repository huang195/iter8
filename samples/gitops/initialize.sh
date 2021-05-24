#!/bin/sh

rm -f productpage-candidate.yaml
rm -f fortio.yaml
echo 1 > templates/version
git add -A ./; git commit -m "initialize"; git push origin head

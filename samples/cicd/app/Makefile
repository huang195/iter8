all: run

build:
	docker build -t haih/helloworld:`git rev-parse --short HEAD` .

push:
	docker push haih/helloworld:`git rev-parse --short HEAD`

candidate:
	cat deployment-candidate.yaml | sed "s/VERSION/`git rev-parse --short head`/g" > ../deployment-candidate.yaml
	cp service-candidate.yaml ../service-candidate.yaml
	sed "s|  name: gitops-exp-|  name: gitops-exp-`od -An -N4 -i /dev/random`|" experiment.yaml > ../experiment.yaml

run: build push candidate

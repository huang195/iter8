all: run

build:
	docker build -t haih/helloworld:`git rev-parse --short HEAD` .

push:
	docker push haih/helloworld:`git rev-parse --short HEAD`

candidate:
	cat deployment-candidate.yaml | sed "s/VERSION/v`git rev-parse --short head`/g" > ../deployment-candidate.yaml
	sed "s|  name: gitops-exp-|  name: gitops-exp-$(shell echo $$RANDOM)|" experiment.yaml > ../experiment.yaml

run: build push candidate

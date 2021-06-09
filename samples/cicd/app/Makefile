all: run

build:
	docker build -t haih/helloworld:`git rev-parse --short HEAD` .

push:
	docker push haih/helloworld:`git rev-parse --short HEAD`

candidate:
	cat deployment-candidate.yaml | sed "s/VERSION/`git rev-parse --short head`/g" > ../deployment-candidate.yaml
	cp service-candidate.yaml ../service-candidate.yaml
	cp experiment.yaml ../experiment.yaml

run: build push candidate

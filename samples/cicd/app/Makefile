all: build

build: Dockerfile server.py
	docker build -t haih/helloworld:`git rev-parse --short HEAD` .

push:
	docker push haih/helloworld:`git rev-parse --short HEAD`

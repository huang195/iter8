all: build

build: Dockerfile server.py
	docker build -t haih/helloworld:latest .

push:
	docker push haih/helloworld:latest

ifndef VERSION
VERSION = $(shell git rev-parse --short head)
endif

candidate:
	cat deployment-candidate.yaml | sed "s/VERSION/v$(VERSION)/g" > ../deployment-candidate.yaml
	sed "s|  name: gitops-exp-|  name: gitops-exp-$(shell echo $$RANDOM)|" experiment.yaml > ../experiment.yaml

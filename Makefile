NAME := $(shell jq -r .docker_name package.json)
TAG := $(shell jq -r .version package.json)
DOCKER_OPENSIPS_VERSION := $(shell jq -r .opensips.version package.json)

image: Dockerfile
	docker build -t ${NAME}:${TAG} .
	docker tag ${NAME}:${TAG} ${REGISTRY}/${NAME}:${TAG}

tests:
	DEBUG='ccnq4-opensips:*' npm test

%: %.src
	sed -e 's/DOCKER_OPENSIPS_VERSION/${DOCKER_OPENSIPS_VERSION}/' $< > $@

push: image tests
	docker push ${REGISTRY}/${NAME}:${TAG}
	docker push ${NAME}:${TAG}
	docker rmi ${REGISTRY}/${NAME}:${TAG}
	docker rmi ${NAME}:${TAG}

NAME ::= shimaore/`jq -r .name package.json`
TAG ::= `jq -r .version package.json`
DOCKER_OPENSIPS_VERSION ::= `jq -r .opensips.version package.json`

image: Dockerfile supervisord.conf
	docker build -t ${NAME}:${TAG} .
	docker tag -f ${NAME}:${TAG} ${REGISTRY}/${NAME}:${TAG}

tests:
	npm test

%: %.src
	sed -e "s/DOCKER_OPENSIPS_VERSION/${DOCKER_OPENSIPS_VERSION}/" $< > $@

push: image tests
	docker push ${REGISTRY}/${NAME}:${TAG}
	docker push ${NAME}:${TAG}
	docker rmi ${REGISTRY}/${NAME}:${TAG}
	docker rmi ${NAME}:${TAG}

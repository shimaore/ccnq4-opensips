NAME ::= shimaore/`jq -r .name package.json`
TAG ::= `jq -r .version package.json`
MEDIAPROXY_VERSION ::= `jq -r .mediaproxy.version package.json`
DOCKER_OPENSIPS_VERSION ::= `jq -r .opensips.version package.json`

image: Dockerfile supervisord.conf
	docker build --rm -t ${NAME}:${TAG} .
	docker tag -f ${NAME}:${TAG} ${REGISTRY}/${NAME}:${TAG}

tests:
	npm test

%: %.src
	sed -e "s/MEDIAPROXY_VERSION/${MEDIAPROXY_VERSION}/" $< | sed -e "s/DOCKER_OPENSIPS_VERSION/${DOCKER_OPENSIPS_VERSION}/" > $@

push: image tests
	docker push ${REGISTRY}/${NAME}:${TAG}
	# docker push ${NAME}:${TAG}

# Local #

vendor-download:
	mkdir -p vendor/
	curl -o vendor/mediaproxy-${MEDIAPROXY_VERSION}.tar.gz -L http://download.ag-projects.com/MediaProxy/mediaproxy-${MEDIAPROXY_VERSION}.tar.gz

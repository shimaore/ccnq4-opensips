NAME ::= shimaore/`jq -r .name package.json`
TAG ::= `jq -r .version package.json`
MEDIAPROXY_VERSION ::= `jq -r .mediaproxy.version package.json`

image: Dockerfile
	docker build --rm -t ${NAME}:${TAG} .
	docker tag -f ${NAME}:${TAG} ${REGISTRY}/${NAME}:${TAG}

tests:
	npm test

Dockerfile: Dockerfile.src
	sed -e "s/MEDIAPROXY_VERSION/${MEDIAPROXY_VERSION}/" $< > $@

push: image tests
	# docker push ${NAME}:${TAG}
	docker push ${REGISTRY}/${NAME}:${TAG}

# Local #

vendor-download:
	mkdir -p vendor/
	curl -o vendor/mediaproxy-${MEDIAPROXY_VERSION}.tar.gz -L http://download.ag-projects.com/MediaProxy/mediaproxy-${MEDIAPROXY_VERSION}.tar.gz

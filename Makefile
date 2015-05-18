NAME ::= shimaore/`jq -r .name package.json`
TAG ::= `jq -r .version package.json`

image:
	docker build -t ${NAME}:${TAG} .
	docker tag -f ${NAME}:${TAG} ${REGISTRY}/${NAME}:${TAG}

image-no-cache:
	docker build --no-cache -t ${NAME} .
	docker build -t ${NAME}:${TAG} .

tests:
	npm test

push: image tests
	# docker push ${NAME}:${TAG}
	# docker push ${NAME}
	docker push ${REGISTRY}/${NAME}:${TAG}

# Local #

vendor:
	mkdir -p vendor/
	curl -o vendor/mediaproxy-2.6.1.tar.gz -L http://download.ag-projects.com/MediaProxy/mediaproxy-2.6.1.tar.gz

filepath        :=      $(PWD)
versionfile     :=      $(filepath)/version.txt
version         :=      $(shell cat $(versionfile))

release: 
	docker build -t codaprotocol/coda-network-services:$(version) -f Dockerfile  .
	docker tag codaprotocol/coda-network-services:$(version) gcr.io/o1labs-192920/coda-network-services:$(version)
	docker push gcr.io/o1labs-192920/coda-network-services:$(version)

latest:
	docker tag codaprotocol/coda-network-services:$(version) gcr.io/o1labs-192920/coda-network-services:latest
	docker push gcr.io/o1labs-192920/coda-network-services:latest

build: 
	docker build -t codaprotocol/coda-network-services:$(version) -f Dockerfile .

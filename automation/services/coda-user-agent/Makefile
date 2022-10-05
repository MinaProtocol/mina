filepath        :=      $(PWD)
versionfile     :=      $(filepath)/version.txt
version         :=      $(shell cat $(versionfile))

# Deployment Commands
release: 
	docker build --no-cache -t codaprotocol/coda-user-agent:$(version) .
	docker push codaprotocol/coda-user-agent:$(version)

build: 
	docker build -t codaprotocol/coda-user-agent:$(version) .
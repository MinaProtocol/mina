filepath        :=      $(PWD)
versionfile     :=      $(filepath)/version.txt
version         :=      $(shell cat $(versionfile))

# Deployment Commands
release:
	docker build --no-cache -t codaprotocol/buildkite-exporter:$(version) .
	docker push codaprotocol/buildkite-exporter:$(version)

build:
	docker build -t codaprotocol/buildkite-exporter:$(version) .

all : clean docker container build

.PHONY : all dev

kademlia:
	bash -c 'cd app/kademlia-haskell && nix-build release2.nix'

docker :
	@./rebuild-docker.sh nanotest Dockerfile

build :
	@echo "Starting Build"
	@if [ "$(USEDOCKER)" = "TRUE" ]; then \
		./scripts/run-in-docker dune build ; \
	else \
		dune build ; \
	fi
	@echo "Build complete"

container :
	@./container.sh restart

clean :
	@echo "Removing previous build artifacts"
	@rm -rf _build

dev : docker container build

nanobit-docker :
	./rebuild-docker.sh nanobit Dockerfile-nanobit

nanobit-minikube :
	./rebuild-minikube.sh nanobit Dockerfile-nanobit

nanobit-googlecloud :
	./rebuild-googlecloud.sh nanobit Dockerfile-nanobit

base-docker :
	./rebuild-docker.sh ocaml-base Dockerfile-base

base-minikube :
	./rebuild-minikube.sh ocaml-base Dockerfile-base

base-googlecloud :
	./rebuild-googlecloud.sh ocaml-base Dockerfile-base $(shell git rev-parse HEAD)

ocaml407-googlecloud:
	./rebuild-googlecloud.sh ocaml407 Dockerfile-ocaml407

pull-ocaml407-googlecloud:
	gcloud docker -- pull gcr.io/o1labs-192920/ocaml407:latest

update-deps: base-googlecloud
	./rewrite-from-dockerfile.sh ocaml-base $(shell git rev-parse HEAD)

test:
	@if [ "$(USEDOCKER)" = "TRUE" ]; then \
		./scripts/run-in-docker ./test_all.sh ; \
	else	\
		./test_all.sh ; \
	fi

reformat:
	dune exec app/reformat/reformat.exe -- -path .

check-format:
	dune exec app/reformat/reformat.exe -- -path . -check

## FIXME Things below are Deprecated things to clean up

testbridge-docker :
	./rebuild-docker.sh testbridge-nanobit Dockerfile-testbridge

testbridge-minikube :
	./rebuild-minikube.sh testbridge-nanobit Dockerfile-testbridge

testbridge-googlecloud :
	./rebuild-googlecloud.sh testbridge-nanobit Dockerfile-testbridge

ci-base-docker:
	./rebuild-docker.sh o1labs/ci-base Dockerfile-ci-base
	
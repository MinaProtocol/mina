
all : docker dev
.PHONY : all

kademlia:
	bash -c 'cd app/kademlia-haskell && source ~/.profile && nix-build release2.nix'

docker :
	./rebuild-docker.sh nanotest

dev : docker
	./develop.sh restart
	@echo "*****"
	@echo "** Add hackbin to the front of your PATH"
	@echo "** Talk to bkase to help you setup your vimrc"
	@echo "****"

nanobit-docker :
	./rebuild-docker.sh nanobit nanobit-Dockerfile

nanobit-minikube :
	./rebuild-minikube.sh nanobit nanobit-Dockerfile

nanobit-googlecloud :
	./rebuild-googlecloud.sh nanobit nanobit-Dockerfile

testbridge-docker :
	./rebuild-docker.sh testbridge-nanobit testbridge-Dockerfile

testbridge-minikube :
	./rebuild-minikube.sh testbridge-nanobit testbridge-Dockerfile

testbridge-googlecloud :
	./rebuild-googlecloud.sh testbridge-nanobit testbridge-Dockerfile

base-docker :
	./rebuild-docker.sh ocaml-base base-Dockerfile

base-minikube :
	./rebuild-minikube.sh ocaml-base base-Dockerfile

base-googlecloud :
	./rebuild-googlecloud.sh ocaml-base base-Dockerfile $(shell git rev-parse HEAD)

ocaml405-googlecloud:
	./rebuild-googlecloud.sh ocaml405 ocaml405-Dockerfile

pull-ocaml405-googlecloud:
	gcloud docker -- pull gcr.io/o1labs-192920/ocaml405:latest

ci-base-docker:
	./rebuild-docker.sh o1labs/ci-base ci-base-Dockerfile

update-deps: base-googlecloud
	./rewrite-from-dockerfile.sh ocaml-base $(shell git rev-parse HEAD)

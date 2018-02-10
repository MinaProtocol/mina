
all : docker dev
.PHONY : all

docker :
	./rebuild-docker.sh nanotest

dev : docker
	./develop.sh restart
	@echo "*****"
	@echo "** Add hackbin to the front of your PATH"
	@echo "** Talk to bkase to help you setup your vimrc"
	@echo "****"



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
	./rebuild-googlecloud.sh ocaml-base base-Dockerfile


all : docker googlecloud minikube
.PHONY : all

docker :
	cd container && ../../../rebuild-docker.sh testbridge

minikube :
	cd container && ../../../rebuild-minikube.sh testbridge

googlecloud :
	cd container && ../../../rebuild-googlecloud.sh testbridge


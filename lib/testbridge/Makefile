
all : docker minikube googlecloud camlsnark-docker camlsnark-minikube camlsnark-googlecloud
.PHONY : all

docker :
	cd container && ../../../rebuild-docker.sh testbridge

minikube :
	cd container && ../../../rebuild-minikube.sh testbridge

googlecloud :
	cd container && ../../../rebuild-googlecloud.sh testbridge 

camlsnark-docker :
	cd container && ../../../rebuild-docker.sh testbridge-camlsnark camlsnark-Dockerfile

camlsnark-minikube :
	cd container && ../../../rebuild-minikube.sh testbridge-camlsnark camlsnark-Dockerfile

camlsnark-googlecloud :
	cd container && ../../../rebuild-googlecloud.sh testbridge-camlsnark camlsnark-Dockerfile





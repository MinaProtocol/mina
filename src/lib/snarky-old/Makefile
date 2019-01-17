
all : docker googlecloud minikube
.PHONY : all

build :
	dune build --root=.

docker :
	./rebuild-docker.sh ocaml-camlsnark

minikube :
	./rebuild-minikube.sh ocaml-camlsnark

googlecloud :
	./rebuild-googlecloud.sh ocaml-camlsnark


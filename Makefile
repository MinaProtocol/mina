
all : docker
.PHONY : all

docker :
	./rebuild-docker.sh nanotest


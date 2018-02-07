
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


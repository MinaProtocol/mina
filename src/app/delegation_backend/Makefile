.PHONY: clean build test tidy docker docker-run

ifeq ($(GO),)
GO := go
endif

build:
	GO=$(GO) ./scripts/build.sh

clean:
	rm -rf result

tidy:
	cd src && $(GO) mod tidy

test:
	GO=$(GO) ./scripts/build.sh test

docker-upload:
	./scripts/build.sh docker-upload

docker-run:
	./scripts/build.sh docker-run

docker:
	./scripts/build.sh docker

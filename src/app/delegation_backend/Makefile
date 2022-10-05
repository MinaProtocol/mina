.PHONY: clean build test tidy docker docker-run docker-toolchain

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

docker-run:
	./scripts/build.sh $@

docker-toolchain:
	./scripts/build.sh $@

docker:
	./scripts/build.sh $@

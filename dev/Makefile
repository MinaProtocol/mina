export HOST_UID := $(shell id -u)
export HOST_GID := $(shell id -g)

all:
	docker compose up

rebuild:
	docker compose down --volumes
	docker compose build --no-cache
	docker compose up

ssh:
	docker exec -u opam -it -w "/mina" mina /bin/bash

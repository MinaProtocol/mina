.PHONY: devnet mainnet clean stop logs status health

# Podman does not read .env on its own; pass it once it exists.
COMPOSE_ENV = $(if $(wildcard .env),--env-file .env)

devnet:
	cp example.devnet.env .env
	docker compose --env-file .env up -d

mainnet:
	cp example.mainnet.env .env
	docker compose --env-file .env up -d

stop:
	docker compose $(COMPOSE_ENV) down

clean:
	docker compose $(COMPOSE_ENV) down -v
	@echo ""
	@echo "Containers + volumes removed."
	@echo ""
	@echo "The daemon, archive, and postgres write to ./archive/ and"
	@echo "./mina_node/.mina-config/ as root inside the containers, so the"
	@echo "leftover files are root-owned on the host and this Makefile will"
	@echo "not rm them for you. To finish cleanup, run one of:"
	@echo ""
	@echo "  sudo rm -rf ./archive ./mina_node"
	@echo "  docker run --rm -v \"\$$(pwd)\":/work alpine rm -rf /work/archive /work/mina_node"

logs:
	docker compose $(COMPOSE_ENV) logs -f

status:
	docker compose $(COMPOSE_ENV) ps -a

health:
	@echo "=== Postgres ==="
	@docker compose $(COMPOSE_ENV) exec -T postgres psql -U postgres -d archive -tAc "SELECT count(*) FROM blocks" 2>/dev/null && echo "OK" || echo "FAIL"
	@echo ""
	@echo "=== Mina Node (GraphQL) ==="
	@curl -sf http://localhost:3085/graphql -H 'Content-Type: application/json' \
		-d '{"query":"{ syncStatus }"}' 2>/dev/null | head -c 200 && echo "" || echo "FAIL - not reachable"
	@echo ""
	@echo "=== Container Status ==="
	@docker compose $(COMPOSE_ENV) ps --format "table {{.Name}}\t{{.Status}}"

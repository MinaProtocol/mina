.PHONY: devnet mainnet clean stop logs status ps health

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
	rm -rf ./archive ./mina_node/.mina-config ./mina_rosetta/.mina-config

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
	@echo "=== Mina Rosetta ==="
	@curl -sf http://localhost:3087/network/list \
		-H 'Content-Type: application/json' -d '{}' 2>/dev/null | head -c 200 && echo "" || echo "FAIL - not reachable"
	@echo ""
	@echo "=== Container Status ==="
	@docker compose $(COMPOSE_ENV) ps --format "table {{.Name}}\t{{.Status}}"

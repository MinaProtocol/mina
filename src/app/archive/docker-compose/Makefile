.PHONY: devnet mainnet clean stop logs status health

devnet:
	cp example.devnet.env .env
	docker compose up -d

mainnet:
	cp example.mainnet.env .env
	docker compose up -d

stop:
	docker compose down

clean:
	docker compose down -v
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
	docker compose logs -f

status:
	docker compose ps -a

health:
	@echo "=== Postgres ==="
	@docker compose exec -T postgres psql -U postgres -d archive -tAc "SELECT count(*) FROM blocks" 2>/dev/null && echo "OK" || echo "FAIL"
	@echo ""
	@echo "=== Mina Node (GraphQL) ==="
	@curl -sf http://localhost:3085/graphql -H 'Content-Type: application/json' \
		-d '{"query":"{ syncStatus }"}' 2>/dev/null | head -c 200 && echo "" || echo "FAIL - not reachable"
	@echo ""
	@echo "=== Container Status ==="
	@docker compose ps --format "table {{.Name}}\t{{.Status}}"

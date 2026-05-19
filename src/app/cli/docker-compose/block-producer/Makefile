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
	@echo "The daemon writes to ./mina_node/.mina-config/ as root inside the"
	@echo "container, so the leftover files are root-owned on the host and this"
	@echo "Makefile will not rm them for you. To finish cleanup, run one of:"
	@echo ""
	@echo "  sudo rm -rf ./mina_node"
	@echo "  docker run --rm -v \"\$$(pwd)\":/work alpine rm -rf /work/mina_node"
	@echo ""
	@echo "WARNING: this removes the generated block-producer key. Back up"
	@echo "./mina_node/.mina-config/keys/ first if you want to keep it."

logs:
	docker compose logs -f

status:
	docker compose ps -a

health:
	@echo "=== Mina Block Producer (GraphQL) ==="
	@curl -sf http://localhost:3085/graphql -H 'Content-Type: application/json' \
		-d '{"query":"{ syncStatus }"}' 2>/dev/null | head -c 200 && echo "" || echo "FAIL - not reachable"
	@echo ""
	@echo "=== Block production status ==="
	@docker compose exec -T mina_block_producer mina client status 2>/dev/null | grep -E "(Sync status|Block producers|Chain id)" || echo "FAIL - client status not reachable"
	@echo ""
	@echo "=== Container Status ==="
	@docker compose ps --format "table {{.Name}}\t{{.Status}}"

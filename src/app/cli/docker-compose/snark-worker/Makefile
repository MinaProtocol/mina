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
	rm -rf ./mina_node/.mina-config

logs:
	docker compose logs -f

status:
	docker compose ps -a

health:
	@echo "=== Coordinator (GraphQL) ==="
	@curl -sf http://localhost:3085/graphql -H 'Content-Type: application/json' \
		-d '{"query":"{ syncStatus }"}' 2>/dev/null | head -c 200 && echo "" || echo "FAIL - not reachable"
	@echo ""
	@echo "=== Coordinator client status ==="
	@docker compose exec -T mina_snark_coordinator mina client status 2>/dev/null | grep -E "(Sync status|Snark work fee|Chain id)" || echo "FAIL - client status not reachable"
	@echo ""
	@echo "=== Container Status ==="
	@docker compose ps --format "table {{.Name}}\t{{.Status}}"

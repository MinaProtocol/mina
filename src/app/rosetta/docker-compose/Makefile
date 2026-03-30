.PHONY: devnet mainnet clean stop logs status ps health

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
	rm -rf ./archive ./mina_node/.mina-config ./mina_rosetta/.mina-config

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
	@echo "=== Mina Rosetta ==="
	@curl -sf http://localhost:3087/network/list \
		-H 'Content-Type: application/json' -d '{}' 2>/dev/null | head -c 200 && echo "" || echo "FAIL - not reachable"
	@echo ""
	@echo "=== Container Status ==="
	@docker compose ps --format "table {{.Name}}\t{{.Status}}"

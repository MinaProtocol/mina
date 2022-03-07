all:
	docker-compose up

rebuild:
	docker-compose down --volumes
	docker-compose build --no-cache
	docker-compose up

ssh:
	docker exec -it -w "/mina" mina /bin/bash

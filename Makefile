IMAGE_NAME=ssh-tunnel
COMPOSE_FILE=docker-compose.yml
CONTAINER_NAME=ssh-tunnel

.PHONY: all build up down restart logs ssh clean

all: build up

build:
	docker build -t ${IMAGE_NAME} .

up:
	docker compose up -d

down:
	docker compose down

restart: down up

logs:
	docker logs -f $(CONTAINER_NAME)

ssh:
	ssh -p 2222 tunnel@localhost

clean:
	docker compose down --rmi all --volumes --remove-orphans
	docker system prune -f


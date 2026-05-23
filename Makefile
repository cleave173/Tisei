COMPOSE := docker compose -f infra/docker-compose.yml

.PHONY: help up down build logs ps restart shell-backend shell-db psql migrate migration seed reset-db app-pubget app-run app-analyze

help:
	@echo "Tisei — make commands"
	@echo "  up            Start the stack (postgres + backend + libretranslate)"
	@echo "  down          Stop the stack"
	@echo "  build         Rebuild backend image"
	@echo "  logs          Follow logs"
	@echo "  migrate       Apply Alembic migrations to head"
	@echo "  migration m=  Generate a new autogenerate migration with message m"
	@echo "  seed          Seed English content (idempotent)"
	@echo "  reset-db      Drop & recreate DB volume, run migrations + seed"
	@echo "  shell-backend Shell into backend container"
	@echo "  psql          Open psql in db container"
	@echo "  app-pubget    flutter pub get"
	@echo "  app-run       flutter run"
	@echo "  app-analyze   flutter analyze"

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build backend

logs:
	$(COMPOSE) logs -f --tail=100

ps:
	$(COMPOSE) ps

restart:
	$(COMPOSE) restart backend

shell-backend:
	$(COMPOSE) exec backend bash

shell-db:
	$(COMPOSE) exec db sh

psql:
	$(COMPOSE) exec db psql -U tisei -d tisei

migrate:
	$(COMPOSE) exec backend alembic upgrade head

migration:
	@if [ -z "$(m)" ]; then echo "Usage: make migration m='your message'"; exit 1; fi
	$(COMPOSE) exec backend alembic revision --autogenerate -m "$(m)"

seed:
	$(COMPOSE) exec backend python -m scripts.seed_english

reset-db:
	$(COMPOSE) down -v
	$(COMPOSE) up -d db
	sleep 4
	$(COMPOSE) up -d backend libretranslate
	sleep 3
	$(MAKE) migrate
	$(MAKE) seed

app-pubget:
	cd app && flutter pub get

app-run:
	cd app && flutter run

app-analyze:
	cd app && flutter analyze

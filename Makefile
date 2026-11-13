# Developer shortcuts for the Workshop Organizer API.
# Each target is a thin wrapper: the underlying command is shown next to it,
# and the operations runbook documents the commands without make.

.DEFAULT_GOAL := help
API_URL ?= http://localhost:8080/api/workshops

.PHONY: help install up down ps logs health test backup restore psql clean wait-api

help: ## List the targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

.env:
	@cp .env.example .env
	@echo "Created .env from .env.example: set POSTGRES_PASSWORD, then run make install again." && exit 1

install: .env ## Build the image and start the API and its database
	docker compose up -d --build --wait
	@$(MAKE) --no-print-directory wait-api

up: .env ## Start the stack without rebuilding
	docker compose up -d --wait
	@$(MAKE) --no-print-directory wait-api

# --wait only waits for the database healthcheck: Spring needs a few more seconds
wait-api:
	@printf "waiting for the API"; for i in $$(seq 1 60); do \
	  curl -sf -o /dev/null $(API_URL) && echo " ready" && exit 0; printf "."; sleep 2; done; \
	echo " not answering after 2 min (make logs)"; exit 1

down: ## Stop the stack (data is kept in the pgdata volume)
	docker compose down

ps: ## Show the containers and their health
	docker compose ps

logs: ## Follow the API logs
	docker compose logs -f app

health: ## Check the database and the API
	docker compose exec -T db sh -c 'pg_isready -h 127.0.0.1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'
	curl -sf $(API_URL) && echo

test: ## Run the unit tests (reports in test-results/)
	./run-tests.sh

backup: ## Dump the database into backups/
	scripts/backup.sh

restore: ## Restore a dump: make restore FILE=backups/xxx.dump
	@test -n "$(FILE)" || (echo "usage: make restore FILE=backups/xxx.dump" && exit 2)
	scripts/restore.sh "$(FILE)"

psql: ## Open a psql shell on the database
	docker compose exec db sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

clean: ## Stop the stack and DELETE the database volume
	@printf "Delete the pgdata volume and all its data? [y/N] " && read a && [ "$$a" = y ]
	docker compose down -v

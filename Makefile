.DEFAULT_GOAL := help
.PHONY: help setup dev dev-native check test build db-info db-migrate db-plan db-reset clean

help: ## Show the available commands
	@awk 'BEGIN {FS = ":.*## "; printf "\nUsage: make \033[36m<target>\033[0m\n\n"} /^[a-zA-Z_-]+:.*?## / { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

setup: ## Install pinned local dependencies
	uv sync --project app/backend --all-groups
	pnpm --dir app/frontend install --frozen-lockfile

dev: ## Start everything in containers with live reload
	docker compose up --build --remove-orphans

dev-native: ## Start local processes (requires mise-managed tools)
	./scripts/dev.sh

check: ## Run format, lint, type, unit, and IaC checks
	./scripts/check.sh

test: ## Run application tests
	uv run --project app/backend pytest -c app/backend/pyproject.toml
	pnpm --dir app/frontend test:ci

build: ## Build the exact production container
	docker build --build-arg APP_VERSION=local -t palladium:local .

db-info: ## Show local Flyway migration state
	docker compose run --rm flyway info

db-migrate: ## Validate and migrate the local database
	docker compose run --rm flyway migrate

db-plan: ## Show the exact pending local SQL files
	@docker compose up --detach --wait database
	@FLYWAY_DOCKER_NETWORK=palladium_default \
		FLYWAY_URL=jdbc:postgresql://database:5432/$${POSTGRES_DB:-palladium} \
		FLYWAY_USER=$${POSTGRES_USER:-palladium} \
		FLYWAY_PASSWORD=$${POSTGRES_PASSWORD:-palladium} \
		./scripts/db/plan.sh local database/migrations .cache/schema-plan.json .cache/schema-plan.md
	@cat .cache/schema-plan.md

db-reset: ## Recreate the disposable local database and reapply every migration
	docker compose down --volumes --remove-orphans
	docker compose up --detach --wait database
	docker compose run --rm flyway migrate

clean: ## Remove generated local artifacts
	docker compose down --volumes --remove-orphans

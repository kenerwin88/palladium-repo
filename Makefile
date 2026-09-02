.DEFAULT_GOAL := help
.PHONY: help setup dev dev-native check test build clean

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
	uv run --project app/backend pytest
	pnpm --dir app/frontend test:ci

build: ## Build the exact production container
	docker build --build-arg APP_VERSION=local -t palladium:local .

clean: ## Remove generated local artifacts
	docker compose down --volumes --remove-orphans

# Hundred Eight (108) — Makefile
# Default: `make` or `make help`

SHELL         := /bin/bash
.SHELLFLAGS   := -eu -o pipefail -c
.DEFAULT_GOAL := help

BUNDLE          ?= bundle
DOCKER_COMPOSE  ?= docker compose

export RAILS_ENV         ?= development
export PGHOST            ?= 127.0.0.1
export PGUSER            ?= postgres
export PGPASSWORD        ?= postgres
# Used by config/database.yml ERB for primary + cable DB hosts
export DB_HOST           ?= 127.0.0.1
export DB_USER           ?= postgres
export DB_PASSWORD       ?= postgres

.PHONY: help start dev stop clean reset lint lint-ci test check db-prepare docker-up security brakeman bundler-audit importmap-audit

help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

start: docker-up db-prepare ## Start Postgres (Docker) + migrate, then Rails + Tailwind (blocking)
	@echo "Starting app with bin/dev (Ctrl+C to stop). Postgres stays up; run 'make stop' to tear down Docker."
	exec bin/dev

dev: ## Run Rails + Tailwind only (Postgres must already be running)
	exec bin/dev

docker-up: ## Start Docker services (PostgreSQL)
	$(DOCKER_COMPOSE) up -d
	@echo "Waiting for Postgres…"
	@for i in {1..30}; do \
		$(DOCKER_COMPOSE) exec -T postgres pg_isready -U postgres >/dev/null 2>&1 && break; \
		sleep 1; \
	done
	@$(DOCKER_COMPOSE) exec -T postgres pg_isready -U postgres >/dev/null 2>&1 || (echo "Postgres failed to become ready"; exit 1)

db-prepare: ## Create / migrate primary + cable databases (requires Postgres)
	$(BUNDLE) exec rails db:prepare

stop: ## Stop Docker services (PostgreSQL)
	$(DOCKER_COMPOSE) down

clean: ## Stop stack and remove orphan containers
	$(DOCKER_COMPOSE) down --remove-orphans

reset: docker-up ## Drop, recreate, migrate, seed (destructive for local DB data)
	$(BUNDLE) exec rails db:reset

lint: ## Run RuboCop (Omakase)
	$(BUNDLE) exec rubocop

lint-ci: ## RuboCop with GitHub Actions annotation formatter (CI-style)
	$(BUNDLE) exec rubocop --format github

test: ## Run RSpec
	RAILS_ENV=test $(BUNDLE) exec rails db:test:prepare
	RAILS_ENV=test $(BUNDLE) exec rspec

brakeman: ## Static security analysis
	$(BUNDLE) exec brakeman -q --no-pager

bundler-audit: ## Check gems for known CVEs (updates local advisory DB)
	$(BUNDLE) exec bundler-audit check --update

importmap-audit: ## Audit importmap / JS pins (npm advisories)
	./bin/importmap audit

security: brakeman bundler-audit ## Run Brakeman + bundler-audit

check: lint test security importmap-audit ## Lint + tests + Brakeman + bundler-audit + importmap audit

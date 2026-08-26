.PHONY: help up down restart logs ps \
        migrate-up migrate-down migrate-new migrate-drop \
        api run worker build-backend test-backend vet lint \
        mobile-get mobile-test mobile-analyze \
        verify clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ---------------------------------------------------------------- infra ------
up: ## Start infra (postgres, redis)
	docker compose up -d postgres redis

down: ## Stop all services (keeps volumes)
	docker compose down

restart: down up ## Restart infra

logs: ## Tail logs of running services
	docker compose logs -f --tail=100

ps: ## List service status
	docker compose ps

clean: ## Stop everything and remove volumes (DESTRUCTIVE)
	docker compose down -v

# ------------------------------------------------------------- migrations ----
# Load .env for DB credentials (make does not read it automatically), with
# dev defaults matching docker-compose.yml.
-include .env
export ATHENA_DATABASE_URL ATHENA_APP_ENV ATHENA_HTTP_ADDR ATHENA_LOG_LEVEL ATHENA_LOG_FORMAT ATHENA_REDIS_ADDR ATHENA_ADMIN_TOKEN ATHENA_WORKER_CONCURRENCY ATHENA_INGESTION_ENABLED LLM_PROVIDER LLM_BASE_URL LLM_API_KEY LLM_MODEL EMBEDDING_PROVIDER EMBEDDING_MODEL EMBEDDING_DIM SEMANTICSCHOLAR_API_KEY OPENALEX_MAILTO ARXIV_USER_AGENT ATHENA_JWT_SECRET
export POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB
POSTGRES_USER ?= athena
POSTGRES_PASSWORD ?= athena_dev_password
POSTGRES_DB ?= athena

# compose `run <svc> <args>` REPLACES the service's `command:`, so every
# target must pass the full flag set itself.
MIGRATE_FLAGS := -path=/migrations -database=postgres://$(POSTGRES_USER):$(POSTGRES_PASSWORD)@postgres:5432/$(POSTGRES_DB)?sslmode=disable

migrate-up: up ## Apply pending migrations (dockerized golang-migrate)
	docker compose --profile tools run --rm migrate $(MIGRATE_FLAGS) up

migrate-down: ## Roll back the most recent migration
	docker compose --profile tools run --rm migrate $(MIGRATE_FLAGS) down 1

migrate-new: ## Create a migration pair: make migrate-new name=add_something
	@test -n "$(name)" || { echo "usage: make migrate-new name=<snake_case_name>"; exit 1; }
	migrate create -ext sql -dir backend/migrations -seq "$(name)"

migrate-drop: ## Drop the entire schema (DESTRUCTIVE)
	docker compose run --rm migrate $(MIGRATE_FLAGS) drop -f

# --------------------------------------------------------------- backend -----
run: api ## Alias for make api

api: build-backend ## Run the Go API locally
	cd backend && ./bin/api

worker: ## Run the Go worker locally
	cd backend && go run ./cmd/worker

build-backend: ## Build api + worker binaries into backend/bin
	mkdir -p backend/bin && cd backend && go build -o bin/api ./cmd/api && go build -o bin/worker ./cmd/worker

test-backend: ## Run backend unit tests
	cd backend && go test ./...

vet: ## go vet the backend
	cd backend && go vet ./...

lint: ## golangci-lint (if installed)
	cd backend && golangci-lint run

tidy: ## go mod tidy
	cd backend && go mod tidy

# ---------------------------------------------------------------- mobile -----
mobile-get: ## Fetch Flutter dependencies
	cd mobile && flutter pub get

mobile-analyze: ## Static analysis for the Flutter app
	cd mobile && flutter analyze

mobile-test: ## Run Flutter tests
	cd mobile && flutter test

# --------------------------------------------------------------- one-shot ----
verify: vet test-backend ## Quick sanity check of the whole repo
	docker compose config -q && echo "compose config OK"

.PHONY: setup build up down logs clean db:prepare db:seed sync console

# Docker Compose
DC = docker compose

# Default target
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Initial setup (creates .env, builds images, prepares DB)
	bash setup.sh

build: ## Build all Docker images (staged: base → rails/sidekiq/vite)
	@echo "Building base image..."
	$(DC) build base
	@echo "Building dependent services..."
	$(DC) build rails sidekiq vite

up: ## Start all services
	$(DC) up -d

down: ## Stop all services
	$(DC) down

restart: down up ## Restart all services

logs: ## Follow all logs
	$(DC) logs -f

logs-rails: ## Follow Rails logs
	$(DC) logs -f rails

logs-sidekiq: ## Follow Sidekiq logs
	$(DC) logs -f sidekiq

logs-vite: ## Follow Vite logs
	$(DC) logs -f vite

clean: ## Stop and remove all containers and volumes
	$(DC) down -v --remove-orphans

# Database
db:prepare: ## Prepare database (migrations + seeds)
	$(DC) exec -T rails bundle exec rails db:chatwoot_prepare

db:seed: ## Run database seeds
	$(DC) exec -T rails bundle exec rails db:seed

db:reset: ## Reset database
	$(DC) exec -T rails bundle exec rails db:drop db:create db:migrate db:seed

# Rails
console: ## Open Rails console
	$(DC) exec rails bundle exec rails console

rails-task: ## Run a Rails task (usage: make rails-task TASK="db:migrate")
	$(DC) exec -T rails bundle exec rails $(TASK)

# Sync
sync: ## Sync with upstream Chatwoot (optional: pass CLIENT_BRANCH=client/xyz)
	bash sync-upstream.sh $(CLIENT_BRANCH)

# Testing
test-ruby: ## Run Ruby tests
	$(DC) exec -T rails bundle exec rspec

test-js: ## Run JavaScript tests
	$(DC) exec -T rails pnpm test

lint-ruby: ## Run Rubocop
	$(DC) exec -T rails bundle exec rubocop -a

lint-js: ## Run ESLint
	$(DC) exec -T rails pnpm eslint

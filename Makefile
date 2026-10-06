.DEFAULT_GOAL := help
VENV := .venv
BIN := $(VENV)/bin

help: ## Show available targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

venv: ## Create virtualenv and install dev dependencies
	python3 -m venv $(VENV)
	$(BIN)/pip install -r requirements-dev.txt

run: ## Run the app locally with SQLite and auto-reload
	$(BIN)/uvicorn app.main:app --reload

lock: ## Re-pin requirements*.txt (with hashes) from requirements*.in
	$(BIN)/pip-compile -q --strip-extras --generate-hashes --allow-unsafe -o requirements.txt requirements.in
	$(BIN)/pip-compile -q --strip-extras --generate-hashes --allow-unsafe -o requirements-dev.txt requirements-dev.in

lint: ## Lint and check formatting
	$(BIN)/ruff check .
	$(BIN)/ruff format --check .

fmt: ## Auto-format code
	$(BIN)/ruff check --fix .
	$(BIN)/ruff format .

test: ## Run tests with coverage
	$(BIN)/pytest --cov=app --cov-report=term-missing --cov-fail-under=80

up: ## Build and start the Docker stack
	@test -f .env || cp .env.example .env
	docker compose up -d --build

down: ## Stop the Docker stack
	docker compose down

logs: ## Tail app logs
	docker compose logs -f app

.PHONY: help venv run lock lint fmt test up down logs

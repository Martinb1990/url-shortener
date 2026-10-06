.DEFAULT_GOAL := help
VENV := .venv
BIN := $(VENV)/bin

help: ## Show available targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

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

test-alerts: ## Unit-test the Prometheus alert rules (needs helm + promtool)
	helm template url-shortener charts/url-shortener -n url-shortener \
	  --set monitoring.prometheusRule.enabled=true --show-only templates/monitoring.yaml \
	  | python3 -c 'import json,sys,yaml; print(json.dumps({"groups": yaml.safe_load(sys.stdin)["spec"]["groups"]}))' \
	  > tests/monitoring/rules.yaml
	promtool check rules tests/monitoring/rules.yaml
	promtool test rules tests/monitoring/alerts_test.yaml

up: ## Build and start the Docker stack
	@test -f .env || cp .env.example .env
	docker compose up -d --build

down: ## Stop the Docker stack
	docker compose down

logs: ## Tail app logs
	docker compose logs -f app

# ----------------------------------------------------------- infrastructure
INFRA_BIN := .venv-infra/bin
TOFU := tofu -chdir=infra/tofu
ANSIBLE := cd infra/ansible && ../../$(INFRA_BIN)

infra-venv: ## Install Ansible tooling + collections
	python3 -m venv .venv-infra
	$(INFRA_BIN)/pip install -r infra/requirements.txt
	$(ANSIBLE)/ansible-galaxy collection install -r requirements.yml -p collections

tofu-init: ## Init OpenTofu with the GCS state backend
	$(TOFU) init -backend-config=backend.hcl

tofu-plan: ## Show infrastructure changes
	$(TOFU) plan -out=tfplan

tofu-apply: ## Apply the saved plan
	$(TOFU) apply tfplan

ansible-check: ## Dry-run host configuration (asks for sudo password)
	$(ANSIBLE)/ansible-playbook site.yml --check --diff -K

ansible-apply: ## Configure the host (asks for sudo password)
	$(ANSIBLE)/ansible-playbook site.yml --diff -K

infra-lint: ## Lint OpenTofu + Ansible
	$(TOFU) fmt -check -recursive
	$(ANSIBLE)/ansible-lint

.PHONY: infra-venv tofu-init tofu-plan tofu-apply ansible-check ansible-apply infra-lint
.PHONY: help venv run lock lint test-alerts fmt test up down logs

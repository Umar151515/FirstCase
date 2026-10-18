COMPOSE = docker compose

.PHONY: demo dev prod test test-backend test-frontend lint seed-demo reset-demo migrate bot stop

demo:
	$(COMPOSE) up -d --build postgres backend frontend

dev:
	$(COMPOSE) up --build postgres backend frontend

prod:
	$(COMPOSE) --env-file .env.production -f docker-compose.prod.yml up -d --build

bot:
	$(COMPOSE) --profile bot up -d --build bot

migrate:
	$(COMPOSE) exec backend alembic upgrade head

seed-demo:
	$(COMPOSE) exec backend python -m scripts.seed_demo

reset-demo:
	$(COMPOSE) exec backend python -m scripts.reset_demo --confirm firstcase_demo

test: test-backend test-frontend

test-backend:
	$(COMPOSE) --profile test run --rm --build backend-test

test-frontend:
	cd frontend && flutter test

lint:
	uv run ruff check backend shared bot scripts
	uv run ruff format --check backend shared bot scripts
	uv run python scripts/check_localization.py
	cd frontend && flutter analyze

stop:
	$(COMPOSE) down

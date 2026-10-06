# Shortly: URL Shortener (a DevOps showcase project)

[![CI](https://github.com/Martinb1990/url-shortener/actions/workflows/ci.yml/badge.svg)](https://github.com/Martinb1990/url-shortener/actions/workflows/ci.yml)

**Live:** https://shortly-martin.duckdns.org

A small URL shortener that demonstrates a complete DevOps toolchain, end to end, built only from free and open-source tools and running on a single GCP VM (`gcp-devops01`).

## Roadmap

All six phases are complete.

| Phase | Scope | Tools | Status |
|---|---|---|---|
| 1 | App + containers | FastAPI, PostgreSQL, Redis, Docker, Compose | ✅ |
| 2 | CI + DevSecOps | GitHub Actions, ruff, pytest, gitleaks, Semgrep, Trivy, GHCR (SBOM + provenance), Dependabot, pre-commit | ✅ |
| 3 | IaC + config management | OpenTofu (VM, static IP, all firewall rules; GCS state), Ansible | ✅ |
| 4 | Kubernetes + GitOps CD | k3s, Helm, Flux CD with image automation, SOPS + age | ✅ |
| 5 | Observability | Prometheus, Grafana, Loki + Alloy, Alertmanager to Discord, alert unit tests | ✅ |
| 6 | Hardening + continuous testing | cert-manager + Let's Encrypt, Traefik HTTPS/HSTS/rate limits, k6, OWASP ZAP, security headers, zero-downtime rollouts, runbook, Headlamp + k9s | ✅ |

## DevOps components

| Component | How it's done here |
|---|---|
| Culture and collaboration | Protected `main` (PRs + required checks), CODEOWNERS, PR template, Conventional Commits, [CONTRIBUTING.md](CONTRIBUTING.md) |
| Continuous integration | GitHub Actions on every PR: lint, tests on Python 3.13/3.14, image build |
| Continuous testing | Unit tests (90% coverage), Compose smoke test, end-to-end on k3d (same k3s as prod), k6 load test, promtool alert tests |
| Continuous delivery | Merge to `main` → CI publishes `main-<ts>-<sha>` → Flux commits the new tag and rolls it out; failed upgrades roll back |
| Infrastructure as Code | OpenTofu: VM, static IP, firewall rules ([infra/](infra/README.md)) |
| Configuration management | Ansible: packages, swap, Docker, k3s, cluster CLIs, SSH tunnel exception |
| Continuous monitoring | Prometheus, Grafana dashboards, Loki logs, Alertmanager to Discord, [runbook](docs/runbook.md) |
| Security (DevSecOps) | gitleaks, Semgrep, Trivy (deps, IaC, image), OWASP ZAP, SOPS-encrypted secrets, hash-pinned deps, SHA-pinned Actions, restricted Pod Security, NetworkPolicies, HTTPS + HSTS, rate limits |

## Architecture

```
 developer ─► PR ─► CI: lint · tests · gitleaks · Semgrep · Trivy · k3d e2e · k6 · ZAP
                         │ merge to main
                         ▼
               ghcr.io/martinb1990/url-shortener:main-<timestamp>-<sha>
                         │ Flux scans GHCR, commits the new tag to git
                         ▼
 gcp-devops01 (OpenTofu + Ansible) ─ k3s ◄── Flux ◄── git (main)
   │
   ├─ Traefik ── HTTPS (Let's Encrypt via cert-manager), HSTS, rate limits
   │     └─► url-shortener ns: app ×2 ─► PostgreSQL (PVC) · Redis (cache)
   ├─ monitoring ns: Prometheus · Alertmanager ─► Discord · Grafana · Loki ◄ Alloy
   └─ headlamp ns: Headlamp web console
```

Internet exposure: **only ports 80/443** (the app). SSH is key-only. Grafana, Headlamp, Prometheus and Alertmanager are private, reachable only through the SSH tunnel.

## Access

| What | Where |
|---|---|
| App | https://shortly-martin.duckdns.org (API docs: [`/docs`](https://shortly-martin.duckdns.org/docs)) |
| Grafana | `ssh -L 3000:localhost:3000 <user>@34.89.12.210`, then http://localhost:3000 |
| Headlamp | `ssh -L 4466:localhost:4466 <user>@34.89.12.210`, then http://localhost:4466 (token: see [operations](docs/operations.md#consoles)) |
| k9s | `k9s` on the VM |
| Alerts | Discord channel (warning and critical) |

## Try it

```bash
curl -s -X POST https://shortly-martin.duckdns.org/api/links \
  -H "Content-Type: application/json" -d '{"url": "https://www.wikipedia.org", "custom_code": "wiki"}'
curl -sI https://shortly-martin.duckdns.org/wiki          # 307 → location: https://www.wikipedia.org/
curl -s  https://shortly-martin.duckdns.org/api/links/wiki # stats, including "clicks"
```

Or open the site, paste a long URL and click **Shorten**.

## API

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/links` | Create a link: `{"url": "https://…", "custom_code": "optional"}` |
| `GET` | `/api/links?limit=10` | Most recent links |
| `GET` | `/api/links/{code}` | Stats for one link |
| `GET` | `/{code}` | 307 redirect to the target (counts a click; `HEAD` doesn't) |
| `GET` | `/healthz` | Liveness probe |
| `GET` | `/readyz` | Readiness probe (checks DB + Redis) |
| `GET` | `/metrics` | Prometheus metrics (in-cluster only; 403 through the ingress) |
| `GET` | `/docs` | Interactive OpenAPI docs |

Errors: `409` code taken, `400` reserved code, `422` invalid URL, `429` rate limited.

## Quick start

### Local development (no Docker)

```bash
make venv          # virtualenv + dev dependencies
make test          # pytest + coverage (fails under 80%)
make lint          # ruff
make test-alerts   # promtool alert unit tests (needs helm + promtool)
make run           # http://127.0.0.1:8000, SQLite, no Redis
```

### Full stack with Docker Compose

```bash
make up            # app + PostgreSQL + Redis on http://localhost:8000
./scripts/smoke-test.sh http://localhost:8000
make down
```

### The whole platform on a fresh VM

```bash
make infra-venv && make ansible-apply                 # Docker, swap, k3s, CLIs, tunnel (infra/README.md)
make tofu-init && make tofu-plan && make tofu-apply   # GCP resources (infra/README.md)
# then bootstrap Flux once: docs/operations.md#bootstrap-one-time-already-done-on-gcp-devops01
```

## Documentation

| Doc | Covers |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Workflow, dependency locking, every CI stage and what fails it |
| [infra/README.md](infra/README.md) | OpenTofu and Ansible, accepted risks, firewall rules |
| [docs/operations.md](docs/operations.md) | Cluster layout, deploys, consoles, observability, rollback, secrets, bootstrap |
| [docs/runbook.md](docs/runbook.md) | What to do when each alert fires |

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./shortener.db` | SQLAlchemy URL |
| `REDIS_URL` | *(empty, cache disabled)* | Redis URL for the lookup cache |
| `CACHE_TTL_SECONDS` | `3600` | Cache entry lifetime |
| `CODE_LENGTH` | `7` | Length of generated codes |

## Design notes

- **12-factor config:** settings come from environment variables only.
- **Cache is optional:** if Redis is unreachable, lookups fall back to PostgreSQL, and `/readyz` reports it.
- **Resilient startup:** the app waits for the database and tolerates replicas racing to create tables.
- **Zero-downtime rollouts:** `maxUnavailable: 0` plus a 5 s `preStop` drain. Measured: 0 of 370 requests failed during a rolling restart (6 of 298 before the drain).
- **Container hardening:** multi-stage build, no pip in the runtime image, non-root UID 10001, read-only root filesystem, all capabilities dropped.
- **Metrics:** HTTP metrics from `prometheus-fastapi-instrumentator`; business metrics `shortener_links_created_total` and `shortener_redirects_total{result,source}`.
- **Known trade-off:** every redirect writes its click count to PostgreSQL synchronously. That's fine at this scale; batching counts in Redis is the first optimisation if traffic grows.

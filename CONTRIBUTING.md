# Contributing

## Workflow

1. Open (or pick) an issue describing the change.
2. Branch from `main`: `feat/<short-name>`, `fix/<short-name>` or `chore/<short-name>`.
3. Commit using [Conventional Commits](https://www.conventionalcommits.org/): `feat: add link expiry`, `fix: handle redis timeout`.
4. Open a pull request. CI must be green before merging, and `main` is protected.
5. Squash-merge. Every merge to `main` publishes a new image to GHCR.

## Local checks

```bash
make venv                                   # once
.venv/bin/pip install pre-commit && .venv/bin/pre-commit install   # once
make lint test
```

## Dependencies

Direct dependencies live in `requirements.in` / `requirements-dev.in`. The `.txt` files are generated lockfiles: every package, including indirect ones, is pinned with SHA-256 hashes. Don't edit the `.txt` files by hand:

```bash
# edit requirements.in, then:
make lock
make test
```

Pinning indirect dependencies matters: Trivy can only flag a vulnerable package it can see in the lockfile.

## CI pipeline

| Stage | Tool | Fails the build on |
|---|---|---|
| Lint | ruff | any lint or format issue |
| Test | pytest (Python 3.13 + 3.14) | test failure or coverage < 80% |
| Secret scan | gitleaks | any secret in git history |
| SAST | Semgrep | any finding |
| Dependencies + Dockerfile | Trivy | fixable HIGH/CRITICAL CVE or misconfiguration |
| Image | Trivy | fixable HIGH/CRITICAL CVE in the built image |
| Smoke test | `scripts/smoke-test.sh` on the compose stack | any end-to-end failure |
| E2E on Kubernetes | chart on k3d (same k3s as prod) + smoke test; `/metrics` must be blocked at the ingress | any failure |
| Load test | k6 (`tests/load/shortener.js`): redirect + create mix, about 3.5k requests | errors ≥ 1%, redirect p95 ≥ 300 ms, create p95 ≥ 500 ms |
| DAST | OWASP ZAP baseline, passive scan through the ingress | any WARN/FAIL not overridden in `.zap/rules.tsv` |
| Alert rules | `promtool check` + unit tests (`make test-alerts`) | invalid rule or alert firing at the wrong time |
| Publish | GHCR (main only) | n/a: also attaches an SBOM and provenance |

Findings from Semgrep and Trivy also appear under the repo's **Security → Code scanning** tab.

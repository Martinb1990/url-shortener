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
| Publish | GHCR (main only) | n/a: also attaches an SBOM and provenance |

Findings from Semgrep and Trivy also appear under the repo's **Security → Code scanning** tab.

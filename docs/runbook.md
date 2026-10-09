# Runbook

What to do when an alert fires. Every app alert links here (`runbook_url`).

Commands assume a shell on gcp-devops01 (`kubectl` and `flux` are configured there).

```bash
NS=url-shortener
kubectl -n $NS get pods              # first look, always
flux get helmreleases -A             # did a deploy just happen or fail?
git log --oneline -5 origin/main     # what changed recently (fluxcdbot = image deploy)
```

Grafana → **URL Shortener** dashboard shows traffic, errors, latency and logs on one screen.

---

## ShortenerDown

**Severity:** critical. **Meaning:** Prometheus cannot scrape any app pod for 2 minutes, so the app is most likely down for users too.

**Check**

```bash
kubectl -n $NS get pods -l app.kubernetes.io/name=app
kubectl -n $NS describe pods -l app.kubernetes.io/name=app | grep -A5 -E 'State|Events'
kubectl -n $NS logs deploy/url-shortener --tail=50
```

**Likely causes and fixes**

| Symptom | Cause | Fix |
|---|---|---|
| `CrashLoopBackOff`, logs show a Python error | Bad release | Roll back (see [Rollback](#rollback)) |
| `ImagePullBackOff` | Tag missing on GHCR | Check `flux get images all -A`; roll back |
| `Pending` | Node out of memory or CPU | `kubectl describe node`; see [Node pressure](#node-pressure) |
| Pods `Running` but not `Ready` | `/readyz` failing (DB/Redis) | Check [ShortenerDatabaseDown](#shortenerdatabasedown) |

## ShortenerHighErrorRate

**Severity:** warning. **Meaning:** more than 5% of requests returned 5xx for 5 minutes.

**Check:** on the dashboard, *Responses by status* and *Request rate by route* show which route fails; the *Logs* panel shows the traceback.

```bash
kubectl -n $NS logs deploy/url-shortener --since=10m | grep -iE 'error|traceback' | tail -20
```

**Fix:** if it started with a deploy, [roll back](#rollback). If the DB is the cause, see below. 4xx errors (bad input) do not count toward this alert.

## ShortenerHighLatency

**Severity:** warning. **Meaning:** p95 latency above 500 ms for 10 minutes.

**Check**

```bash
kubectl top pods -n $NS
kubectl top node
```

**Likely causes:** CPU saturation on the node (check other namespaces, especially `monitoring`), Postgres slow under write load (every redirect writes a click count), Redis down so every redirect hits the DB ([ShortenerCacheDown](#shortenercachedown)).

**Fix:** remove the pressure (see [Node pressure](#node-pressure)); scale the app with `replicaCount` in the HelmRelease values (via PR).

## ShortenerDatabaseDown

**Severity:** critical. **Meaning:** the Postgres StatefulSet has had no ready replica for 2 minutes. Creating links fails; uncached redirects fail.

**Check**

```bash
kubectl -n $NS get pod url-shortener-postgres-0
kubectl -n $NS logs url-shortener-postgres-0 --tail=50
kubectl -n $NS get pvc
df -h /var/lib/rancher/k3s/storage
```

**Likely causes:** disk full (the PVC lives on the node's disk via local-path), OOM kill (check `describe pod`), or a wrong password after editing the SOPS secret (`FATAL: password authentication failed`).

**Fix:** free disk space; for a password mismatch, the secret and the existing database must agree (the DB keeps the password it was initialised with).

## ShortenerCacheDown

**Severity:** warning. **Meaning:** Redis unavailable for 5 minutes. The app keeps working (redirects fall back to Postgres) but is slower and the DB takes all the load.

```bash
kubectl -n $NS get pods -l app.kubernetes.io/name=redis
kubectl -n $NS logs deploy/url-shortener-redis --tail=30
```

**Fix:** usually self-heals when the pod restarts. Redis is a pure cache (no persistence), so deleting the pod is safe: `kubectl -n $NS delete pod -l app.kubernetes.io/name=redis`.

---

## Site down but no Discord alert / healthchecks.io email

**Meaning:** the in-cluster pipeline can't deliver (the healthchecks.io email or a failed `Uptime` run told you). Most likely the pod network is broken. On 2026-10-07 a host firewall reload (server-baseline re-apply) removed k3s's rules: pod DNS failed for ~44h, the app went not-ready, Flux stalled, and 2,646 Discord sends failed.

**Check**

```bash
kubectl -n url-shortener logs deploy/url-shortener --tail=5     # "Temporary failure in name resolution"?
journalctl -t k3s-netguard --since -1h                           # did the self-heal act?
systemctl status k3s-netguard.timer
```

**Fix:** `k3s-netguard.timer` re-adds the firewall exceptions every minute and restarts k3s if its chains were wiped (at most once per 10 min). If it didn't heal: `sudo systemctl restart k3s` (running pods are not restarted), then `flux reconcile kustomization flux-system --with-source`.

## Rollback

Deploys are git commits by `fluxcdbot`. To go back:

```bash
flux suspend image update url-shortener -n flux-system   # stop Flux re-deploying the newest tag
```

Then revert the bad `deploy: url-shortener main-…` commit in a PR (or pin the previous tag in `apps/devops01/url-shortener/helmrelease.yaml`) and merge. Resume with `flux resume image update url-shortener -n flux-system` once a fixed build is out.

A failed upgrade (pods never ready) is already rolled back automatically by the HelmRelease; `flux get helmreleases -A` shows it.

## Node pressure

```bash
uptime; free -h; cat /proc/pressure/cpu /proc/pressure/memory
kubectl top pods -A --sort-by=memory | head
kubectl get pods -A | grep -E 'OOMKilled|Evicted|CrashLoop'
```

The monitoring stack is the largest consumer. Retention and memory limits are in `infrastructure/devops01/monitoring/kube-prometheus-stack.yaml`; the VM size is `machine_type` in `infra/tofu/variables.tf` (resize from Cloud Shell, see `docs/operations.md`).

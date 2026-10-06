# Infrastructure

Two layers, two tools:

| Layer | Tool | Manages |
|---|---|---|
| Cloud resources | **OpenTofu** (`infra/tofu`) | The VM, its static IP, all firewall rules |
| Inside the VM | **Ansible** (`infra/ansible`) | Packages, swap, Docker, SSH tunnel exception |

OS hardening (SSH, firewall, auditd, sysctls) stays with
[server-baseline](../../server-baseline). Ansible only adds what this project
needs on top and never edits the baseline's files.

## OpenTofu

The VM was created by hand, so it is **imported**, not created: the first
`apply` adopts it into state. `prevent_destroy` and `deletion_protection`
guard against accidental deletion.

State lives in a versioned GCS bucket (`<project>-tfstate`, in the
Always Free region us-central1).

```bash
gcloud auth login --update-adc                        # once; also sets credentials for tofu
./infra/tofu/bootstrap-state.sh <project-id>          # once; creates the state bucket
cp infra/tofu/terraform.tfvars.example infra/tofu/terraform.tfvars   # fill in
make tofu-init
make tofu-plan    # review before applying
make tofu-apply
```

## Ansible

Runs on the VM against itself (`ansible_connection: local`).

```bash
make infra-venv      # once
make ansible-check   # dry run with diff
make ansible-apply
```

Run a single role with tags, e.g. `ansible-playbook site.yml -K --tags docker`.

## Accepted risks

| Finding | Why accepted |
|---|---|
| Trivy GCP-0031: VM has a public IP | Single host reached over key-only SSH and serving HTTPS from phase 6. A bastion or NAT + load balancer would cost money. |
| Trivy GCP-0067 (MEDIUM): Secure Boot off | The VM was created without it and enabling it needs a stop/start. Planned for a maintenance window: set `enable_secure_boot = true` and apply. |
| Trivy GCP-0027 (CRITICAL): SSH from 0.0.0.0/0 | Key-only, server-baseline hardened. **Stronger option:** limit `default-allow-ssh` source ranges in `infra/tofu/firewall.tf` (your IP, or IAP `35.235.240.0/20` + `gcloud compute ssh --tunnel-through-iap`). Check you have another way in before applying. |
| Trivy GCP-0027 (CRITICAL): ICMP from 0.0.0.0/0 | Ping / path-MTU discovery only. |

## Firewall rules

All rules on the `default` network are in OpenTofu (`firewall.tf`, `main.tf`). GCP's `default-allow-rdp` (tcp:3389 from anywhere) was deleted through it.

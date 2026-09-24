# Bastion lab scripts

Deployed to `~/lab/scripts/` by `bastion-ocp-install.yml` or `bastion-scripts.yml`.

| Script | Purpose |
|--------|---------|
| `pull-secret-for-oc-mirror.sh` | Build `~/lab/pull-secret-oc-mirror.txt` (called by Ansible before `oc-mirror`) |
| `lab-startup-check.sh` | DNS / registry / NTP checks before SNO boot |
| `verify-mirror-before-sno.sh` | Preflight after mirror, before agent install |

Install YAML (CA, pullSecret, sshKey): re-run `ansible-playbook playbooks/bastion-ocp-install.yml` — no shell helpers.

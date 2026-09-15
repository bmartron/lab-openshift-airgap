# Procédures manuelles ↔ Ansible

Convention du dépôt : chaque guide de configuration décrit d’abord la **procédure manuelle**, puis l’**équivalent Ansible** (playbook, limite d’hôte, prérequis).

## Lancer Ansible (rappel)

**Machine : Mac** — répertoire `ansible/`, inventaire local (non versionné) :

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
cp inventory/hosts.yml.example inventory/hosts.yml   # une fois
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml   # registry / OCP
ssh-copy-id root@192.168.1.147                       # jump Proxmox
ssh-copy-id -o ProxyJump=root@192.168.1.147 bernard@172.16.10.11   # DNS, etc.
ansible-playbook playbooks/<playbook>.yml --limit <hôte> --ask-become-pass
```

Détail inventaire, SSH, variables : [ansible/README.md](../ansible/README.md).

## Table de correspondance

| Action manuelle (doc) | Playbook | `--limit` | Rôle(s) | Non couvert par Ansible (reste manuel) |
|----------------------|----------|-----------|---------|----------------------------------------|
| Repo DVD RHEL | `lab-infra.yml`, `registry.yml` | `dns`, `registry` | `rhel_dvd` | Attacher l’ISO dans Proxmox |
| VM DNS (NTP, firewall, dnsmasq au boot) | `lab-infra.yml` | `dns` | `rhel_dvd`, `common`, `dns` | `/etc/dnsmasq.conf` (zones lab) — [dns/README.md](../dns/README.md) §4 |
| VM registry (disque, TLS, conteneur) | `registry.yml` | `registry` | `rhel_dvd`, `common`, `registry` | Image `.tar` sur le Mac → `registry_image_tar` ; `podman-restart.service` au boot |
| Disque données registry seul | `registry-data-disk.yml` | `registry` | `registry` (disque) | — |
| Bastion (NTP client, script preflight) | `lab-infra.yml` | `bastion` | `common`, `bastion` | `oc` / `openshift-install` / `oc-mirror` — [bastion/README.md](../bastion/README.md) |
| Scripts bastion seulement | `bastion-scripts.yml` | `bastion` | scripts | Pas de `dnf` |
| Install-config, ISO agent, CA | `bastion-ocp-install.yml` | `bastion` (+ lecture CA sur `registry`) | `ocp_bastion_install` | `pull-secret.txt` dans `ansible/files/` |
| Infra complète (DNS + registry + bastion) | `lab-infra.yml` | (tous) | voir ci-dessus | Création VMs Proxmox / Terraform |

## Bloc type dans les README

À recopier (adapter les cellules) après une section manuelle :

```markdown
### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `dns` |
| **Prérequis** | ISO RHEL attachée ; `inventory/hosts.yml` ; clé SSH vers `bernard@172.16.10.11` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit dns --ask-become-pass` |
| **Couverture** | … |
| **Hors Ansible** | … |
```

Guide playbooks : [ansible/README.md](../ansible/README.md) · install OCP : [ansible-ocp-install.md](ansible-ocp-install.md).

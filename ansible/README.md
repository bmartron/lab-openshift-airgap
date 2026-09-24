# Ansible — lab infra configuration

Configures **DNS**, **registry** (data disk + Podman), and **bastion** (DVD repo, NTP, `/etc/hosts`, CA trust, ISO packages, OCP clients, preflight scripts).

Run from the **Mac** (Proxmox ProxyJump) or from the bastion for lab hosts only.

Rebuild overview: [docs/iac.md](../docs/iac.md).

## Registry VM (Terraform + this role)

| Parameter | Value |
|-----------|--------|
| Name / IP | `registry` — `172.16.10.20` on `vmbr1` |
| Template | `rhel10-tpl` on `local-lvm` |
| Disks | **virtio0** OS + **virtio1** → `/dev/vdb` → `/opt/registry` |
| Endpoint | `https://registry.lab.local:5000` (`registry:2` via Podman) |

Check: `curl -s --cacert ~/lab/ca.crt https://registry.lab.local:5000/v2/_catalog` (from bastion).

| Symptom | Action |
|---------|--------|
| `platform arm64 vs amd64` | Re-save tar with `--platform linux/amd64` on Mac |
| HTTP 500 on push | `df -h /opt/registry` |
| x509 / SAN | Re-run with `registry_tls_mode: generate` |
| No `podman` | RHEL DVD on `ide2` — see § RHEL DVD below |

## Prerequisites

```bash
brew install ansible          # Mac (recommended)
# or: dnf install ansible-core  (bastion / RHEL)
```

```bash
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml
cp inventory/group_vars/all.yml.example inventory/group_vars/all.yml
# Required: registry_data_device, registry_image_tar (absolute path to .tar on the Mac)
# Edit hosts.yml: bastion LAN IP, SSH user; all.yml: data disk + tar path
```

Typical Mac connectivity:

- `bastion`: direct SSH on LAN IP (`vmbr0`)
- `dns`, `registry`: `ansible_host` = lab IP + `ProxyJump` via Proxmox (`hosts.yml.example`)

### Registry image `registry:2` (once on the Mac)

The registry VM has **no Internet**. `lab-infra.yml` does **not** pull from Docker Hub. It uses the same `registry` role as `registry.yml`: copy a local tar → `podman load` on the VM.

**Mac** (once, with Internet):

```bash
podman pull --platform linux/amd64 docker.io/library/registry:2
podman save -o ~/Downloads/registry2-amd64.tar docker.io/library/registry:2
```

Point `registry_image_tar` in `group_vars/all.yml` at that file (see `inventory/group_vars/all.yml.example`).

Flow inside the role (`roles/registry/tasks/image.yml`):

1. Assert `registry_image_tar` exists on the **controller** (Mac)
2. `copy` → `/tmp/registry2-amd64.tar` on the registry VM
3. `podman load` + tag → `docker.io/library/registry:2` (default `registry_image`)
4. Start the Podman container

If the tar is missing, `lab-infra.yml` fails on the registry host with a clear assert.

## Default rebuild path

After Terraform VMs exist (`terraform/lab-airgap`):

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/lab-infra.yml
ansible-playbook playbooks/bastion-ocp-install.yml
```

Then on the **bastion**: `oc-mirror` — [mirror/README.md](../mirror/README.md).

`lab-infra.yml` order: **dns → registry → bastion** (includes DVD repo, NTP, registry disk/TLS/image/container, bastion packages/CA/clients).

On stock RHEL, `bernard` is in **wheel** but sudo asks for a password — without `-K` / `--ask-become-pass`: `Missing sudo password`. Lab option (once on the VM): `bernard ALL=(ALL) NOPASSWD: ALL` in sudoers (isolated lab only).

Without the RHEL DVD on `ide2`: `No package podman available` — see § RHEL DVD below; Terraform: `rhel_dvd_iso`.

### RHEL DVD repo (no subscription)

Infra VMs use the full RHEL 10 DVD (BaseOS + AppStream) via role **`rhel_dvd`** (not `subscription-manager`).

Terraform (`terraform.tfvars`):

```hcl
rhel_dvd_iso = "nfs_iso:iso/rhel-10.2-x86_64-dvd.iso"
```

Attached as **`ide2`**. With cloud-init on `ide0`: **`/dev/sr0` = cidata**, **`/dev/sr1` = RHEL DVD**.  
`lifecycle.ignore_changes` on disks: re-attach with `qm set <VMID> --ide2 …` or recreate the VM.

Ansible template: [roles/rhel_dvd/templates/rhel-dvd.repo.j2](roles/rhel_dvd/templates/rhel-dvd.repo.j2).

| Symptom | Action |
|---------|--------|
| Empty repos / `No package` | Wrong `sr*` or boot-only ISO — use full DVD |
| `Unable to read consumer identity` | Expected — RHSM plugin disabled by the role |
| ISO missing after recreate | Set `rhel_dvd_iso` before `terraform apply` |

## Playbooks

| Playbook | Role |
|----------|------|
| `playbooks/lab-infra.yml` | **Default** — DNS → registry → bastion |
| `playbooks/registry.yml` | Registry host only (same `registry` role; use if you do not want dns/bastion) |
| `playbooks/registry-data-disk.yml` | Data disk `/opt/registry` only |
| `playbooks/bastion-ocp-install.yml` | Bastion: install-config, agent-config, imageset, CA, pull-secret |
| `playbooks/bastion-scripts.yml` | Bastion: copy `~/lab/scripts/*.sh` only (**no** sudo / dnf) |

Targeted re-run after a full stack exists:

```bash
ansible-playbook playbooks/lab-infra.yml --limit registry
```

### OCP install configs on the bastion

Full guide: **[docs/ansible-ocp-install.md](../docs/ansible-ocp-install.md)**.

Summary:

1. **Mac** — [files/README.md](files/README.md): `files/pull-secret.txt` (gitignored).
2. `ocp_sno_mac` in `group_vars/all.yml` (or `inventory/group_vars/all.yml`).
3. Inventory: `bastion` + `registry` (Proxmox jump in `hosts.yml`).
4. SNO `sshKey`: live from bastion `~/.ssh/id_ed25519.pub` (no Mac copy).


```bash
cd ansible
ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass
```

**Effect**: Jinja templates → `~/lab/4.22-ga/config-backup/` + copies under `~/lab/4.22-ga/`, `~/lab/ca.crt`, registry trust for `oc`, scripts in `~/lab/scripts/`.

| Variable | Role |
|----------|------|
| `ocp_imageset_profile` | `platform-only` \| `gitops` \| `virtualization` \| `lvms` \| `odf` \| `rook-ceph` \| `virt-lvms` |
| `ocp_agent_generate_iso` | `true` = `openshift-install agent create image` on bastion |
| `ocp_push_iso_to_proxmox` | `true` = `scp` ISO bastion → `root@192.168.1.147:/mnt/pve/nfs_iso/template/iso/` |
| `ocp_virt_operator_version` | e.g. `4.22.9` (Virt stable channel) |

Defaults: [roles/ocp_bastion_install/defaults/main.yml](roles/ocp_bastion_install/defaults/main.yml).

### DNF / `rhel10-baseos` (dns, registry, or bastion)

Symptom: role **common**, task **base packages** — `Failed to download metadata for repo 'rhel10-baseos'`.

Cause: without a RH subscription, **common** runs `dnf` before the **DVD** repo (`file:///mnt/rhel/...`) is mounted.

1. Proxmox: full RHEL 10 ISO on `ide2` (often `/dev/sr1`; `/dev/sr0` = cloud-init cidata) — Terraform `rhel_dvd_iso` (§ RHEL DVD above).
2. Re-run the playbook (`rhel_dvd` **before** `common` for all three hosts in `lab-infra.yml`).

```bash
cd ansible
ansible-playbook playbooks/lab-infra.yml --limit dns --ask-become-pass
```

Dry-run:

```bash
ansible-playbook playbooks/lab-infra.yml --limit registry --check --diff
```

(`--check` may fail on `podman` / `mkfs` — expected.)

### SSH / ProxyJump (« port 65535 »)

1. Test like Ansible:

```bash
ssh -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20
```

2. Inventory: hard-code `ansible_ssh_common_args` (`hosts.yml.example`), not `{{ proxmox_jump }}`.
3. `ansible.cfg`: `ControlMaster=no` (already set).
4. Ping:

```bash
ansible registry -m ping
```

If **`root@192.168.1.147: Permission denied`**: Ansible does **not** prompt for the Proxmox jump password.

**Recommended fix (Mac, once)**:

```bash
ssh-copy-id root@192.168.1.147
ssh -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20
ansible registry -m ping
```

If **`bernard@… : Permission denied (publickey)`**: the Mac key must be in Terraform (`ssh_public_key_file` / cloud-init) **before** clone, or injected once via Proxmox. See [proxmox/access.md](../proxmox/access.md).

Other options: jump via **bastion** (`hosts.yml.example` method B), `hosts.sshconfig.yml.example`, or run from bastion (`hosts.from-bastion.yml.example`).

## Registry variables (summary)

| Variable | Description |
|----------|-------------|
| `registry_data_device` | Clone: `/dev/vdb`; ISO install: `/dev/sdb` — empty = skip format |
| `registry_tls_mode` | `generate` \| `copy` \| `skip` |
| `registry_image_tar` | Path to `podman save` tar on the Mac (required for container deploy) |
| `registry_recreate_container` | `true` to `podman rm` + recreate |

## Relation to Terraform

1. `cd terraform/lab-airgap` → `terraform apply` (new VMs + DVD ISO + SSH keys)
2. Ensure `registry_image_tar` exists on the Mac (section above)
3. `ansible-playbook playbooks/lab-infra.yml --ask-become-pass`
4. `ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass`
5. Bastion: `oc-mirror` → agent ISO / SNO — [docs/iac.md](../docs/iac.md)

If infra VMs already exist: skip Terraform, fix inventory, run Ansible.

## Secrets

- `inventory/hosts.yml`, `group_vars/all.yml`: **gitignored**
- `files/registry-certs/`: gitignored (`copy` mode)

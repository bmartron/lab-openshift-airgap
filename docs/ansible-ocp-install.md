# Bastion OCP install configs (Ansible)

Playbook: **`ansible/playbooks/bastion-ocp-install.yml`**  
Runs from the **Mac**. Deploys install YAML + pull-secret + imageset on the bastion, optionally builds the agent ISO and copies it to Proxmox NFS.

Place in the rebuild: **after** [lab-infra](../ansible/README.md) · **before** [oc-mirror](../mirror/README.md) · **before** booting SNO — full sequence: [iac.md](iac.md).

---

## Happy path (mandatory)

Do this once after a fresh `lab-infra`, in order.

### 1. Prerequisites (already done if you followed iac.md)

| Check | Where |
|-------|--------|
| `lab-infra.yml` OK | dns + registry + bastion |
| `ansible/files/pull-secret.txt` | Mac — from [console.redhat.com](https://cloud.redhat.com/openshift/install/pull-secret) |
| Mac can SSH `bernard@192.168.1.144` and `root@192.168.1.147` | [proxmox/access.md](../proxmox/access.md) |

SNO `sshKey` is **not** a Mac file: the playbook reads the live bastion `~/.ssh/id_ed25519.pub` ([sno-ssh-convention.md](sno-ssh-convention.md)).  
`lab-ssh.yml` is **imported automatically** by this playbook — do not run it separately.

### 2. Set variables in `inventory/group_vars/all.yml`

Source of truth: **`ansible/inventory/group_vars/all.yml`** (not ad-hoc `-e` flags).

**Required for first ISO + upload:**

```yaml
ocp_sno_mac: "BC:24:11:E1:8F:82"          # must match Terraform sno_mac
ocp_sno_root_device: "/dev/disk/by-path/pci-0000:06:0a.0"
ocp_imageset_profile: virt-lvms             # see profiles below
ocp_agent_generate_iso: true                # build agent.x86_64.iso on bastion
ocp_push_iso_to_proxmox: true               # scp ISO to nfs_iso
```

Then run:

```bash
cd ansible
ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass
```

### 3. After success — set flags back to false

Avoid rebuilding the ISO on every later run:

```yaml
ocp_agent_generate_iso: false
ocp_push_iso_to_proxmox: false
```

### 4. Next steps (not this playbook)

1. **Mirror** on bastion — [mirror/README.md](../mirror/README.md)  
2. **`~/lab/scripts/lab-startup-check.sh`** on bastion  
3. **Boot SNO** — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md)

---

## What the playbook writes (on bastion)

| Path | Purpose |
|------|---------|
| `~/lab/4.22-ga/config-backup/*.yaml` | install-config + agent-config (source of truth) |
| `~/lab/4.22-ga/install-config.yaml` / `agent-config.yaml` | Copies used by `openshift-install` |
| `~/lab/4.22-ga/imageset-config.yaml` | Input for `oc-mirror` |
| `~/lab/4.22-ga/agent.x86_64.iso` | Only if `ocp_agent_generate_iso: true` |
| `~/lab/ca.crt`, `~/lab/pull-secret*.txt` | Trust + auth |
| `~/lab/scripts/*.sh` | Preflight helpers |

---

## Variables reference

### Required

| Variable | Example | Meaning |
|----------|---------|---------|
| `ocp_sno_mac` | `BC:24:11:E1:8F:82` | SNO NIC MAC (Proxmox / Terraform) |
| `ocp_sno_root_device` | `/dev/disk/by-path/pci-0000:06:0a.0` | Install disk hint (VirtIO 120G) |
| `ocp_imageset_profile` | `virt-lvms` | What `oc-mirror` will pull |

### Optional (defaults are fine for lab)

| Variable | Default | When to change |
|----------|---------|----------------|
| `ocp_agent_generate_iso` | `false` | Set `true` for first ISO (or after config/CA/key change) |
| `ocp_push_iso_to_proxmox` | `false` | Set `true` with generate, to scp to NFS |
| `ocp_proxmox_host` / `ocp_proxmox_iso_dir` | lab NUC defaults | Only if Proxmox/NFS paths differ |
| `ocp_cluster_name` / `ocp_base_domain` | `ocp422` / `lab.local` | Rarely |

**Imageset profiles:** `platform-only` \| `gitops` \| `virtualization` \| `lvms` \| `odf` \| `rook-ceph` \| `virt-lvms`

---

## When to re-run (still the same playbook)

| Situation | What to set / do |
|-----------|------------------|
| First install after `lab-infra` | Happy path above (`generate` + `push` = `true`) |
| Changed MAC, root disk, imageset, pull-secret, or registry CA | Edit `all.yml` → set `generate` (+ `push`) `true` → re-run → mirror if imageset changed |
| Bastion VM recreated | `lab-infra` / `lab-ssh` already ran → this playbook with **new ISO** (new live `sshKey`) |
| Only refresh scripts on bastion | Optional: `bastion-scripts.yml` (see below) — **not** required for install |

Do **not** re-run `lab-infra` just to change install YAML.

---

## Optional / workarounds (not the happy path)

Use only if Ansible ISO/push is disabled or blocked.

### Manual ISO on bastion

If `ocp_agent_generate_iso: false`:

```bash
cd ~/lab/4.22-ga
rm -f .openshift_install_state.json agent.x86_64.iso
openshift-install agent create cluster-manifests --dir .
openshift-install agent create image --dir .
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
```

### Manual ISO copy to Proxmox

If `ocp_push_iso_to_proxmox: false`:

```bash
scp ~/lab/4.22-ga/agent.x86_64.iso \
  root@192.168.1.147:/mnt/pve/nfs_iso/template/iso/
```

Or attach via Proxmox UI (`nfs_iso` → `agent.x86_64.iso` → SNO `ide2`). Terraform may already set `sno_agent_iso`.

### Scripts only (no dnf / no ISO)

```bash
cd ansible
ansible-playbook playbooks/bastion-scripts.yml
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| Invalid `ocp_sno_mac` | Set MAC in `inventory/group_vars/all.yml` |
| Missing CA | Registry must have `/opt/registry/certs/ca.crt` (`lab-infra` registry) |
| Missing pull-secret | `ansible/files/pull-secret.txt` on the Mac |
| `Permission denied` Mac → bastion | Terraform `ssh_public_key_file` + [iac.md](iac.md) host-key cleanup |
| `Host key changed` | `ssh-keygen -R <ip>` on Mac or bastion after VM recreate |
| *Mirror registry not found in pullSecret* | Re-run this playbook (it merges `registry.lab.local:5000` into the pull secret) then new ISO |

---

## See also

- [docs/iac.md](iac.md) — full rebuild order  
- [ansible/README.md](../ansible/README.md) — inventory, `lab-ssh`, registry  
- [mirror/README.md](../mirror/README.md) — `oc-mirror` after imageset exists  
- [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) — boot SNO  

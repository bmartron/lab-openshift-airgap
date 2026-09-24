# Update OCP install configs via Ansible

Deploys install YAML on the **bastion** (`192.168.1.144`): no manual editing of `install-config.yaml` (CA, `pullSecret`, `imageContentSources`).

**In scope**: install YAML + pull-secret + imageset (+ CA re-trust).  
**Out of scope** (already `lab-infra.yml`): DVD, eth0 gateway/DNS, packages, `oc`/`oc-mirror` clients, `/etc/hosts`.

## When to run the playbook

| Situation | Action |
|-----------|--------|
| After `lab-infra`, **before** mirror | `bastion-ocp-install.yml` with `ocp_agent_generate_iso` + `ocp_push_iso_to_proxmox` (preferred) |
| Mirror OCP images | `oc-mirror` on bastion — [mirror/README.md](../mirror/README.md) — **then** boot SNO |
| Registry reinstalled (new CA) | Re-run playbook + regenerate ISO |
| SNO MAC, IP, or imageset change | Edit `inventory/group_vars/all.yml` + re-run (+ new ISO) |
| Bastion **recreated** (Terraform) | Resync `install_ssh_key.pub` from the new bastion |

## Prerequisites (Mac)

```bash
brew install ansible
cd ansible
# lab-infra already OK on dns / registry / bastion
cp inventory/hosts.yml.example inventory/hosts.yml   # once
# Edit inventory/group_vars/all.yml (source of truth — not ansible/group_vars/)
```

### Local secrets (not versioned)

See [ansible/files/README.md](../ansible/files/README.md):

```bash
cp ~/Downloads/pull-secret.txt ansible/files/pull-secret.txt
# Bastion public key (lab convention — not the Mac key):
scp bernard@192.168.1.144:~/.ssh/id_ed25519.pub ansible/files/install_ssh_key.pub
```

### Required variables

In **`ansible/inventory/group_vars/all.yml`**:

| Variable | Example | Description |
|----------|---------|-------------|
| `ocp_sno_mac` | `BC:24:11:E1:8F:82` | Proxmox SNO VM MAC (`qm config <VMID> \| grep net`) |
| `ocp_imageset_profile` | `virt-lvms` | `platform-only` \| `gitops` \| `virtualization` \| `lvms` \| `odf` \| `rook-ceph` \| `virt-lvms` |
| `ocp_agent_generate_iso` | `false` | `true` = run `openshift-install` on bastion |

## Command

```bash
cd ansible
ansible-playbook playbooks/bastion-ocp-install.yml
```

The **registry** play reads `/opt/registry/certs/ca.crt`; the **bastion** play deploys YAML, pull-secret, and (re)applies TLS trust.

## Files created on bastion

| Bastion path | Content |
|--------------|---------|
| `~/lab/4.22-ga/config-backup/install-config.yaml` | Platform 4.22.12, mirrors, CA, pullSecret, sshKey |
| `~/lab/4.22-ga/config-backup/agent-config.yaml` | IP `172.16.10.100`, MAC, DNS, NTP |
| `~/lab/4.22-ga/install-config.yaml` | Active copy (for `openshift-install`) |
| `~/lab/4.22-ga/agent-config.yaml` | Same |
| `~/lab/4.22-ga/imageset-config.yaml` | Chosen profile (e.g. Virt 4.22.9) |
| `~/lab/ca.crt` | Registry CA |
| `~/lab/pull-secret.txt` | Red Hat pull secret |
| `~/lab/pull-secret-oc-mirror.txt` | Filtered auth for `oc-mirror` (via script below) |
| `~/lab/scripts/pull-secret-for-oc-mirror.sh` | Builds `pull-secret-oc-mirror.txt` (called by Ansible) |
| `~/lab/scripts/lab-startup-check.sh` | Pre-boot checks (DNS, registry, NTP) |
| `~/lab/scripts/verify-mirror-before-sno.sh` | Preflight before SNO install |

To change install YAML: re-run **`bastion-ocp-install.yml`** (no separate shell helpers).

## Update install-config + registry pullSecret + ISO

When install shows *Mirror registry not found in pullSecret* or after a CA change:

1. **Mac** — update Red Hat pull secret in `ansible/files/pull-secret.txt` (the playbook **adds** `registry.lab.local:5000` if missing).
2. **Mac**:

```bash
cd ansible
ansible-playbook playbooks/bastion-ocp-install.yml
```

3. **ISO** — one of:
   - `ocp_agent_generate_iso: true` in `inventory/group_vars/all.yml`, then re-run the same playbook (long, on bastion);
   - **or** manually on the **bastion** (below).

Install YAML does not require re-running `lab-infra` (already done for OS / clients / network).

## Agent ISO (after playbook)

If `ocp_agent_generate_iso: false` (default), on the **bastion**:

```bash
cd ~/lab/4.22-ga
rm -f .openshift_install_state.json agent.x86_64.iso
openshift-install agent create cluster-manifests --dir .
openshift-install agent create image --dir .
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
```

### Copy ISO to Proxmox (NFS)

**Ansible** (from Mac, after ISO generation on bastion) — in `inventory/group_vars/all.yml`:

```yaml
ocp_push_iso_to_proxmox: true
# optional: ocp_proxmox_host, ocp_proxmox_iso_dir (defaults = lab NUC)
```

Prerequisite: the **Mac** can `ssh root@192.168.1.147` (ProxyJump). Ansible installs the **bastion** pubkey into Proxmox `authorized_keys` (via `lab-infra` / before ISO push) — no manual `ssh-copy-id` from bastion.

Re-run: `ansible-playbook playbooks/bastion-ocp-install.yml`

**Manual** on bastion:

```bash
scp ~/lab/4.22-ga/agent.x86_64.iso \
  root@192.168.1.147:/mnt/pve/nfs_iso/template/iso/
```

In Proxmox UI: datastore **`nfs_iso`** → ISO **`agent.x86_64.iso`** → attach as **ide2** on the SNO VM (or rely on Terraform `sno_agent_iso`).

Then boot — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md).

## Troubleshooting

| Ansible error | Cause |
|---------------|--------|
| Invalid `ocp_sno_mac` | Empty MAC or wrong `group_vars` file |
| Missing CA | Registry play failed or `ca.crt` missing on `172.16.10.20` |
| pull-secret / ssh key | Missing files under `ansible/files/` on the Mac |
| `Host key changed` registry | `ssh-keygen -R 172.16.10.20` on bastion after VM reinstall |

Sync scripts to bastion **without** re-running `lab-infra`:

```bash
cd ansible
ansible-playbook playbooks/bastion-scripts.yml
```

## See also

- [ansible/README.md](../ansible/README.md) — inventory, registry, SSH jump
- [mirror/README.md](../mirror/README.md) — `oc-mirror` after imageset is deployed

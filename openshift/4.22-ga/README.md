# OpenShift 4.22 GA — agent-based air-gap (SNO or compact3)

| Parameter | Value |
|-----------|--------|
| Version | **4.22.12** |
| Cluster name | `ocp422` |
| Base domain | `lab.local` → API `api.ocp422.lab.local` |
| Topology | `ocp_topology`: **sno** (`.100`, `platform: none`) or **compact3** (`.100`–`.102`, `platform: baremetal`, API VIP `.50`, ingress VIP `.49`) |
| Mirror | `registry.lab.local:5000/ocp4-422` |

**Do not** set `baseDomain: ocp422.lab.local` (double subdomain → `api.ocp422.ocp422.lab.local`).

## Recommended order

1. Terraform + `lab-infra.yml`
2. **`bastion-ocp-install.yml`** with ISO generate + upload to Proxmox (configs do not need the mirror yet)
3. **`oc-mirror`** — [mirror/README.md](../../mirror/README.md)
4. Verify mirror, **then** boot the SNO (this doc from §3)

Do **not** start the SNO until the mirror is OK — the ISO only embeds URLs/CA; image blobs come from `oc-mirror`.

Install YAML on bastion: `~/lab/4.22-ga/config-backup/`. Prefer Ansible over hand-editing `.example` files.

## 1. Agent ISO via Ansible (preferred)

**Mac** — in `ansible/inventory/group_vars/all.yml`:

```yaml
ocp_topology: compact3   # or sno — match terraform/lab-ocp
ocp_agent_generate_iso: true
ocp_push_iso_to_proxmox: true
```

Prerequisite for push: Mac can SSH `root@192.168.1.147`. Ansible places the bastion pubkey on Proxmox (`lab-infra` role bastion / before ISO scp).

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/bastion-ocp-install.yml
```

Details: [docs/ansible-ocp-install.md](../../docs/ansible-ocp-install.md).

### Fallback — ISO by hand on bastion

Only if the flags above were `false`. `create image` **deletes** work-dir YAML — restore from `config-backup/`:

```bash
cd ~/lab/4.22-ga
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
rm -f .openshift_install_state.json agent.x86_64.iso

openshift-install agent create cluster-manifests --dir .
openshift-install agent create image --dir . --log-level info

cp config-backup/install-config.yaml config-backup/agent-config.yaml .
scp ~/lab/4.22-ga/agent.x86_64.iso \
  root@192.168.1.147:/mnt/pve/nfs_iso/template/iso/
```

## 2. Mirror (after ISO is ready)

On bastion — [mirror/README.md](../../mirror/README.md). Then:

```bash
~/lab/scripts/verify-mirror-before-sno.sh ~/lab/4.22-ga
~/lab/scripts/lab-startup-check.sh
```

Fix any `[FAIL]` before booting.

## 3. Create / boot SNO (Proxmox)

**Host:** Mac — Terraform; then Proxmox UI / console if needed.

| Setting | Value |
|---------|--------|
| Disk | 120 GiB **VirtIO** → `rootDeviceHints` **by-path** (see agent-config) |
| NIC | `vmbr1`, VirtIO — MAC **`bc:24:11:e1:8f:82`** (`sno_mac` / `ocp_sno_mac`) |
| CD-ROM | `nfs_iso` → `agent.x86_64.iso` on **ide2** |
| LVMS (optional) | 2nd VirtIO disk → `/dev/vdb` |

In `terraform/lab-ocp/terraform.tfvars`: `ocp_topology = "sno"` (see `terraform.tfvars.sno.example`).

Create / apply:

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
terraform apply -auto-approve
```

Retry (recreate VM):

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
terraform apply -replace='proxmox_vm_qemu.node["sno"]' -auto-approve
```

Also documented in [terraform/lab-ocp/README.md](../../terraform/lab-ocp/README.md).

## 4. Wait for install

**Host:** bastion — `bernard@192.168.1.144`

Restore configs and refresh manifests first (avoids `panic: AgentHosts is nil` when `.openshift_install_state.json` is stale after ISO generation):

```bash
cd ~/lab/4.22-ga
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
rm -f .openshift_install_state.json
openshift-install agent create cluster-manifests --dir .
openshift-install agent wait-for install-complete --dir . --log-level info
```

Typical duration: **~30 min** with mirror already present.

`wait-for` may **timeout on TLS** while the cluster is already up. Confirm:

```bash
curl -k https://api.ocp422.lab.local:6443/healthz   # → ok
```

Success = `oc login` + node **Ready** + ClusterOperators **Available**.

### Watch from SNO (optional)

SSH **from bastion only** — [proxmox/access.md](../../proxmox/access.md) § OpenShift node SSH:

```bash
ssh-keygen -R 172.16.10.100   # after each reinstall
ssh core@172.16.10.100
sudo journalctl -u assisted-service -f
# later:
sudo journalctl -u bootkube -f
```

## 5. After install — `oc` and console

**Bastion:**

```bash
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig
oc get nodes
oc get clusteroperators
oc get co
```

Password (if needed): `cat ~/lab/4.22-ga/auth/kubeadmin-password`  
Console URL: `https://console-openshift-console.apps.ocp422.lab.local`

### Web console from the Mac

Forward ingress (`.49`) and API (`.50`) through the bastion, then open the console in the browser:

```bash
sudo ssh -L 443:172.16.10.49:443 -L 6443:172.16.10.50:6443 -N bernard@192.168.1.144
```

## Day-2 — ICSP replacements (IDMS / ITMS)

The agent ISO embeds **ImageContentSources** for the **platform** release only.  
After `oc-mirror`, apply the generated **ImageDigestMirrorSet** / **ImageTagMirrorSet** so OperatorHub / Virt / LVMS pull from `registry.lab.local:5000` instead of `registry.redhat.io` / `quay.io`:

```bash
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig
# Path may be workspace/ or workspace-*/ — use the dir from your last oc-mirror run
oc apply -f ~/lab/4.22-ga/workspace/working-dir/cluster-resources/idms-oc-mirror.yaml
oc apply -f ~/lab/4.22-ga/workspace/working-dir/cluster-resources/itms-oc-mirror.yaml
```

Do this **once the cluster is Ready**, **before** installing operators from the catalog.  
Then follow Virt + LVMS: [docs/openshift-virt-lab.md](../../docs/openshift-virt-lab.md).

# FAQ — tips and pitfalls

Index: [README.md](README.md) · Procedures: [../deploy/DAY0.md](../deploy/DAY0.md) · [DAY1](../deploy/DAY1.md) · [DAY2](../deploy/DAY2.md)

---

## Access and SSH

### Where do I run commands?

| Task | Host |
|------|------|
| Terraform, Ansible | **Mac** |
| `oc-mirror`, `oc`, `wait-for` | **Bastion** `bernard@192.168.1.144` |
| `qm` / Proxmox storage | **Proxmox** `root@192.168.1.147` |
| `core@` OCP nodes | **From bastion only** |

### After reinstall, SSH to core@ fails

On the **bastion**:

```bash
ssh-keygen -R 172.16.10.100
ssh-keygen -R 172.16.10.101
ssh-keygen -R 172.16.10.102
ssh -o StrictHostKeyChecking=accept-new core@172.16.10.100
```

### After Mac reboot

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh bernard@192.168.1.144
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig
oc get nodes
```

Power cycle: [../deploy/lab-power-cycle.md](../deploy/lab-power-cycle.md)

### ProxyJump / Permission denied

```bash
ssh-copy-id root@192.168.1.147
ssh -o ProxyJump=root@192.168.1.147 bernard@172.16.10.20
```

Bastion → dns/registry: `ansible-playbook playbooks/lab-ssh.yml --ask-become-pass`  
Mac key must be in Terraform `ssh_public_key_file` before clone — [../../proxmox/access.md](../../proxmox/access.md)

---

## Day 0 — Design

### Why Proxmox (not a RHEL-only host setup)?

**Temporary choice:** Proxmox is used **until RHEL / NAS NFS problems are resolved**. Heavy disks (OCP, registry) need local SSD I/O; putting them on the NAS was unstable.  
See [../architecture/architecture.md#why-proxmox](../architecture/architecture.md#why-proxmox).

### Why are OCP and registry not on the NAS NFS?

NFS on the home NAS is fine for **dns/bastion/ISOs**, but too slow for **etcd** (OCP) and **registry** write load. Those disks stay on NUC **`local-lvm`**.  
Full rationale: [../architecture/architecture.md#why-not-nas-nfs](../architecture/architecture.md#why-not-nas-nfs).

### Registry tar platform arm64 vs amd64

On the Mac, save with `--platform linux/amd64`:

```bash
podman pull --platform linux/amd64 docker.io/library/registry:2
podman save -o ~/Downloads/registry2-amd64.tar docker.io/library/registry:2
```

---

## Day 1 — Deployment

### “This host is not the rendezvous host”

Normal on masters `.101` / `.102`. Rendezvous is **`172.16.10.100`**.

### Which disk does the agent install to?

| Disk | by-path | Device | Role |
|------|---------|--------|------|
| virtio0 | `pci-0000:06:0a.0` | `/dev/vda` | **Install** |
| virtio1 | `pci-0000:06:0b.0` | `/dev/vdb` | LVMS (Day 2) |

### Should lvms_disk_gb be 0 during install?

No. Keep **`lvms_disk_gb = 100`** at VM create. `rootDeviceHints` pin OS to virtio0.

### oc x509 / wrong CA after reinstall

```bash
ssh core@172.16.10.100 \
  'sudo cat /etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/lb-ext.kubeconfig' \
  > ~/lab/4.22-ga/auth/kubeconfig
chmod 600 ~/lab/4.22-ga/auth/kubeconfig
```

### Do not boot OCP before the mirror

ISO embeds URLs/CA only. Run `verify-mirror-before-sno.sh` first.

### DNF no package / rhel10-baseos

Attach full RHEL DVD (`rhel_dvd_iso` in Terraform) as `ide0`, then re-run `lab-infra.yml`. Role `rhel_dvd` must run before `common`.

### Bastion Internet fails, lab registry OK

Default route stuck on lab (`172.16.10.1`). Gateway must be on admin NIC — [../architecture/bastion.md](../architecture/bastion.md). Re-run `lab-infra.yml --limit bastion`.

### curl registry.lab.local fails / oc no such host apps

`/etc/hosts` missing or wiped by cloud-init → re-run bastion role.

---

## Day 2 — Operations

### Packagemanifests empty after CatalogSource

```bash
oc delete pod -n openshift-marketplace \
  -l olm.catalogSource=cs-redhat-operator-index-v4-22 --wait=false
```

### OperatorHub must use the local catalog

Install from **`cs-redhat-operator-index-v4-22`**, not `redhat-operators`.

### Subscription installed but no lvms-vg1

Create **LVMCluster** on `/dev/vdb`. `ocp_day2_install_lvms=true` only creates the Subscription.

### Guest PVC NotEnoughCapacity

```bash
oc get lvmcluster -A
ssh core@172.16.10.100 'lsblk /dev/vdb'
```

### DV Succeeded but Catalog / Bootable volumes empty

Console project filter: select **`openshift-virtualization-os-images`** or **All Projects**.

```bash
oc get datasource -n openshift-virtualization-os-images
```

### fedora / rhel8 DataSource NotFound

Expected if not mirrored.

### No source digest / CDI FailedMount

CA ConfigMap in **both** `openshift-virtualization-os-images` and `openshift-cnv` — re-run guest boots tag.

### HyperConverged patch ignored (dataImportCronTemplates)

Patch **`hyperconvergeds.v1beta1.hco.kubevirt.io`** (playbook does this).

### Guest images still pulling quay/redhat.io

Run guest boots playbook — mirroring alone is not enough.

### Registry Exited after VM reboot

Ansible registry role enables `podman-restart.service` + `--restart=always`. Re-run `lab-infra.yml --limit registry`.

---

## SNO vs compact3

Same stack. Set `ocp_topology` in Terraform **and** Ansible; regenerate ISO via playbook.

---

## Where is the deep doc?

| Topic | Doc |
|-------|-----|
| Day path | [DAY0](../deploy/DAY0.md) · [DAY1](../deploy/DAY1.md) · [DAY2](../deploy/DAY2.md) |
| IaC | [../deploy/iac.md](../deploy/iac.md) |
| Virt extras | [../deploy/openshift-virt-lab.md](../deploy/openshift-virt-lab.md) |
| CLI detail | [../../openshift/4.22-ga/README.md](../../openshift/4.22-ga/README.md) |
| Mirror | [../../mirror/README.md](../../mirror/README.md) |

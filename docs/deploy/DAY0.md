# Day 0 — Design (official Red Hat)

**Official meaning:** *figure out what resources and requirements are needed before anything runs*  
([Red Hat — Day 0 / Day 1 / Day 2](https://www.redhat.com/en/blog/how-does-red-hat-support-day-2-operations))

In this lab: decide topology and versions, prepare Proxmox/storage/templates and local secrets. **No OpenShift cluster yet.**

Next: [DAY1.md](DAY1.md) (Deployment) · Tips: [../faq/README.md](../faq/README.md) · Architecture: [../architecture/architecture.md](../architecture/architecture.md)

---

## Design decisions

| Decision | Lab default | Reference |
|----------|-------------|-----------|
| Topology | **compact3** (or `sno`) | [../architecture/architecture.md](../architecture/architecture.md) |
| OpenShift version | **4.22.12** | [../architecture/versions.md](../architecture/versions.md) |
| Network | `vmbr1` / `172.16.10.0/24` | [../architecture/network.md](../architecture/network.md) |
| Bastion dual-NIC | LAN `.144` + lab `.10` | [../architecture/bastion.md](../architecture/bastion.md) |
| Mirror profile | `virt-lvms` (if Virt + guests) | [../../mirror/README.md](../../mirror/README.md) |
| OCP disks | OS 120G + LVMS 100G | Terraform `lvms_disk_gb = 100` |

---

## Checklist — prepare the platform

### 1. Proxmox network and storage

- [ ] Bridge **`vmbr1`** — [../../proxmox/network.md](../../proxmox/network.md)
- [ ] Storage: `nfs_vm` + `nfs_iso` (NAS) for light infra/ISOs; **`local-lvm`** for registry + OCP (NFS is too slow for etcd/registry — [../architecture/architecture.md](../architecture/architecture.md)#why-ocp--registry-are-not-on-the-nas-nfs) · [../../terraform/README.md](../../terraform/README.md)
- [ ] Snippets enabled on `local`

```bash
# Proxmox root@192.168.1.147
pvesm status
```

### 2. RHEL cloud-init templates

- [ ] `rhel10-tpl` (registry) · `rhel10-nfs` (dns/bastion)  
  [../../proxmox/rhel-cloudinit-template.md](../../proxmox/rhel-cloudinit-template.md)

### 3. Local config and secrets (Mac)

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy
cp versions.env.example versions.env
cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml
cp ansible/inventory/group_vars/all.yml.example ansible/inventory/group_vars/all.yml
cp terraform/lab-infra/terraform.tfvars.example terraform/lab-infra/terraform.tfvars
cp terraform/lab-ocp/terraform.tfvars.compact3.example terraform/lab-ocp/terraform.tfvars
# pull-secret → ansible/files/pull-secret.txt
```

Set Proxmox token, `ssh_public_key_file`, `ocp_topology`, **`lvms_disk_gb = 100`**.

### 4. SSH to Proxmox (Mac)

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
ssh-copy-id root@192.168.1.147
```

### 5. Registry image tar (once, Mac with Internet)

```bash
podman pull --platform linux/amd64 docker.io/library/registry:2
podman save -o ~/Downloads/registry2-amd64.tar docker.io/library/registry:2
# Point registry_image_tar in ansible inventory/group_vars/all.yml
```

---

## Done when

- Design choices recorded (topology, versions, mirror profile)
- Proxmox + templates ready
- Local secrets/config present (gitignored)
- Passwordless SSH to `root@192.168.1.147`

→ [DAY1.md](DAY1.md) — Deployment

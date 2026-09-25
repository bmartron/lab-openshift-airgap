# Lab versions

## Active track

| Track | OpenShift version | Use | Config |
|-------|-------------------|-----|--------|
| **GA** | **4.22.12** (Kubernetes 1.35) | Air-gap SNO lab | [openshift/4.22-ga/](../openshift/4.22-ga/) |

Check z-streams on [console.redhat.com](https://console.redhat.com/openshift/downloads).

## Stack alignment

Last review: **Proxmox VE 9.2** + **OCP 4.22.12**.

| Component | Version / choice | Where defined |
|-----------|------------------|---------------|
| Proxmox | **9.2.x** | NUC host |
| Terraform | ≥ 1.5 | Mac |
| Proxmox provider | **telmate/proxmox 3.0.2-rc10** | [terraform/lab-airgap/versions.tf](../terraform/lab-airgap/versions.tf) |
| API token | `root@pam!terraform`, privilege separation off (lab) | Proxmox UI |
| Registry VM | virtio0 32G + virtio1 120G, clone `rhel10-tpl` | Terraform + [proxmox/rhel-cloudinit-template.md](../proxmox/rhel-cloudinit-template.md) |
| Registry data | `/opt/registry` on **virtio1** (`/dev/vdb`) | Ansible `registry_data_device` |

### OpenShift GA

| Item | Value |
|------|-------|
| Release | **4.22.12** |
| Mirror namespace | `ocp4-422` |
| SNO IP | `172.16.10.100` |
| Bastion binaries | `oc`, `openshift-install`, **`oc-mirror`** |
| Mirror auth | `--authfile ~/lab/pull-secret-oc-mirror.txt` |
| Install configs | [ansible-ocp-install.md](ansible-ocp-install.md) |

### Do not use (obsolete)

| Obsolete | Use instead |
|----------|-------------|
| `oc mirror -c ...` | `oc-mirror -c ...` |
| `--src-pull-secret` | `--authfile …` |
| Provider telmate/proxmox **2.9** on PVE 9 | **3.0.2-rc10** |
| `disk { type = "scsi" }` (provider 3) | `type = "disk"`, slot `virtio0` / `virtio1` |

### Files to version

| File | Commit? |
|------|---------|
| `terraform/lab-airgap/.terraform.lock.hcl` | **Yes** |
| `terraform/lab-airgap/terraform.tfvars` | **No** |
| `versions.env` | **No** |

## Infra VM OS

| VM | OS |
|----|-----|
| dns / registry / bastion | **RHEL 10.x** |
| OpenShift node | **RHCOS** (from the OCP release) |

## Binaries (bastion)

```bash
export OCP_RELEASE=4.22.12-x86_64
curl -O https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.22.12/openshift-client-linux-4.22.12.tar.gz
curl -O https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.22.12/openshift-install-linux-4.22.12.tar.gz
```

(Or Ansible `lab-infra` bastion role.)

## Mirror

| Track | Registry path | Disk |
|-------|---------------|------|
| GA 4.22.12 | `registry.lab.local:5000/ocp4-422` | ≥ 120 GiB |

## Cluster DNS

| Cluster | Base domain | API | Node |
|---------|-------------|-----|------|
| GA | `ocp422.lab.local` | `api.ocp422.lab.local` | `172.16.10.100` |

## Updating versions

1. Edit [versions.env.example](../versions.env.example)
2. Update ImageSets under `mirror/`
3. Regenerate mirrors — [mirror/README.md](../mirror/README.md)
4. Note in [CHANGELOG.md](CHANGELOG.md)

Prefer full **Terraform + Ansible** rebuild — [docs/iac.md](iac.md).

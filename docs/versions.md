# Lab versions

## Dual-track strategy

The lab supports **two OpenShift environments** in parallel (separate clusters and mirrors):

| Track | OpenShift version | Use | Config directory |
|-------|-------------------|-----|------------------|
| **GA** | **4.22.12** (Kubernetes 1.35) | Stable lab, install / day-2 training | [openshift/4.22-ga/](../openshift/4.22-ga/) |
| **RC** | **5.0.0-ec.6** (Release Candidate) | OCP 5 testing, migration prep | [openshift/5-rc/](../openshift/5-rc/) |

> Check z-streams on [console.redhat.com](https://console.redhat.com/openshift/downloads) and the [5-dev-preview](https://amd64.ocp.releases.ci.openshift.org/#5-dev-preview) stream for RCs.

## Stack alignment (audit)

Last review: **Proxmox VE 9.2** + **OCP 4.22.12**.

| Component | Version / choice | Where defined |
|-----------|------------------|---------------|
| Proxmox | **9.2.x** (e.g. 9.2.18) | NUC host |
| Terraform | ≥ 1.5 | Mac / bastion |
| Proxmox provider | **telmate/proxmox 3.0.2-rc10** | [terraform/lab-airgap/versions.tf](../terraform/lab-airgap/versions.tf) + `.terraform.lock.hcl` |
| API token | `root@pam!terraform`, **Privilege Separation: off** (lab) | Proxmox UI |
| PVE 9 | **No `VM.Monitor`** in custom roles | [terraform/README.md](../terraform/README.md) |
| Registry VM | virtio0 32G + virtio1 120G (`/dev/vda`+`/dev/vdb`), clone `rhel10-tpl`, `vmbr1` | Terraform + [proxmox/rhel-cloudinit-template.md](../proxmox/rhel-cloudinit-template.md) |
| Registry data | `/opt/registry` on **virtio1** (`/dev/vdb`) | Ansible `registry_data_device` |

### OpenShift GA (active track)

| Item | Value |
|------|-------|
| Release | **4.22.12** |
| Mirror namespace | `ocp4-422` |
| SNO IP | `172.16.10.100` |
| Bastion binaries | `oc`, `openshift-install`, **`oc-mirror`** (separate binary, not `oc mirror`) |
| Mirror pull auth | **`--authfile ~/lab/pull-secret-oc-mirror.txt`**; registry TLS via lab CA (`certs.d` / `update-ca-trust`) |
| ImageSet | `apiVersion: mirror.openshift.io/v1alpha2` — **GitOps pinned** (channel + min/max) |
| Bastion Mac (scp/ssh) | **`192.168.1.144`** — lab NIC **`172.16.10.10`** |
| Install configs (Ansible) | [ansible-ocp-install.md](ansible-ocp-install.md) — `playbooks/bastion-ocp-install.yml` |

Example ImageSets / deletes: [mirror/](../mirror/).

### Do not use (obsolete)

| Obsolete | Use instead |
|----------|-------------|
| `oc mirror -c ...` | `oc-mirror -c ...` |
| `--src-pull-secret` | `--authfile ~/lab/pull-secret.txt` |
| Provider **telmate/proxmox 2.9** on PVE 9 | **3.0.2-rc10** |
| `disk { type = "scsi" }` (provider 3) | `type = "disk"`, slot `scsi0`/`scsi1` (SNO) or `virtio0`/`virtio1` (RHEL clone) |
| `cores = N` (provider 3) | `cpu { cores = N }` |
| PVE role with **VM.Monitor** | Administrator / token without privilege separation |

### Files to version

| File | Commit? |
|------|---------|
| `terraform/lab-airgap/.terraform.lock.hcl` | **Yes** (pinned provider) |
| `terraform/lab-airgap/terraform.tfvars` | **No** (secrets) |
| `versions.env` | **No** |
| `~/lab/` on bastion | Outside the repo |

### Quick checks

```bash
# Mac — Terraform
cd terraform/lab-airgap && terraform validate

# Bastion — mirror binary
oc-mirror version 2>/dev/null || oc-mirror --v2 --help | head -1
```

## Infra VM OS

| VM | OS | Version |
|----|-----|---------|
| dns | RHEL | **10.x** (minimal) |
| registry | RHEL | **10.x** (minimal) |
| bastion | RHEL | **10.x** |
| OpenShift nodes | **RHCOS** | From the OCP release (not a manual RHEL install) |

## Binary alignment (bastion)

`oc` and `openshift-install` must match the cluster release **exactly**:

```bash
# GA
export OCP_RELEASE=4.22.12-x86_64

# RC 5 (pin the exact ec build)
export OCP_RELEASE=5.0.0-ec.6-x86_64
```

GA download:

```bash
curl -O https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.22.12/openshift-client-linux-4.22.12.tar.gz
curl -O https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.22.12/openshift-install-linux-4.22.12.tar.gz
```

RC 5 download:

```bash
oc adm release extract --tools quay.io/openshift-release-dev/ocp-release:5.0.0-ec.6-x86_64
```

## Mirror registries (GA / RC separation)

| Track | Registry path | Suggested disk |
|-------|---------------|----------------|
| GA 4.22.12 | `registry.lab.local:5000/ocp4-422` | ≥ 120 GiB |
| RC 5.0 | `registry.lab.local:5000/ocp5-rc` | ≥ 120 GiB |

Do not mix GA and RC images in the same registry namespace.

## Planned clusters

| Cluster | Base domain | API | SNO node |
|---------|-------------|-----|----------|
| GA | `ocp422.lab.local` | `api.ocp422.lab.local` | `172.16.10.100` |
| RC 5 | `ocp5.lab.local` | `api.ocp5.lab.local` | `172.16.10.110` |

> Only one SNO cluster at a time if NUC resources are limited (64 GiB RAM).

## Updating versions

1. Edit [versions.env.example](../versions.env.example)
2. Update `imageset-config` files under `mirror/`
3. Regenerate mirrors (`oc-mirror`) — [mirror/README.md](../mirror/README.md)
4. Update DNS (wildcard `*.apps`)
5. Note the change in [CHANGELOG.md](CHANGELOG.md)

## Out of scope / known

- **Mirror** (`oc-mirror`) and **pull-secret**: manual / [mirror/README.md](../mirror/README.md) — client binaries via Ansible (`lab-infra` bastion).
- **RC 5** (`ocp5-rc`): example configs; not the active lab track today.
- Prefer full **Terraform + Ansible** rebuild over one-off recovery guides — [docs/iac.md](iac.md).

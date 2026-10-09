# Day 1 — Deployment (official Red Hat)

**Official meaning:** *install, set up, and configure the software*  
([Red Hat — Day 0 / Day 1 / Day 2](https://www.redhat.com/en/blog/how-does-red-hat-support-day-2-operations))

In this lab: create VMs, configure lab services, mirror images, boot the agent ISO, wait until the cluster is **Ready**.

Prereq: [DAY0.md](DAY0.md) · Next: [DAY2.md](DAY2.md) · Tips: [../faq/README.md](../faq/README.md)

**Hosts:** Mac = Terraform/Ansible · Bastion `bernard@192.168.1.144` · OCP `core@` from bastion only — [../../proxmox/access.md](../../proxmox/access.md)

Do **not** boot OCP nodes until the mirror verifies OK.

---

## Checklist — deploy until Ready

### 1. Infra VMs (Mac)

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-infra
terraform init -upgrade && terraform apply
```

### 2. Clear SSH keys + check bastion (Mac)

```bash
ssh-keygen -R 192.168.1.144
ssh-keygen -R 172.16.10.11
ssh-keygen -R 172.16.10.20
ssh -o StrictHostKeyChecking=accept-new bernard@192.168.1.144 'hostname'
```

### 3. Lab services (Mac)

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/lab-infra.yml --ask-become-pass
```

### 4. Agent ISO (Mac)

In `ansible/inventory/group_vars/all.yml`: `ocp_topology: compact3`, ISO flags `true`.

```bash
ansible-playbook playbooks/bastion-ocp-install.yml
```

Detail: [ansible-ocp-install.md](ansible-ocp-install.md)

### 5. Mirror (bastion)

Follow [../../mirror/README.md](../../mirror/README.md), then:

```bash
~/lab/scripts/verify-mirror-before-sno.sh ~/lab/4.22-ga
~/lab/scripts/lab-startup-check.sh
```

### 6. OCP VMs (Mac) — both disks

`terraform/lab-ocp/terraform.tfvars`: `lvms_disk_gb = 100`, agent ISO on CD-ROM.

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
terraform apply
```

| Disk | Guest | Role |
|------|-------|------|
| virtio0 120G | `/dev/vda` · `pci-0000:06:0a.0` | RHCOS (`rootDeviceHints`) |
| virtio1 100G | `/dev/vdb` · `pci-0000:06:0b.0` | LVMS (Day 2) |

### 7. Wait for install (bastion)

Rendezvous = **`172.16.10.100`**.

```bash
cd ~/lab/4.22-ga
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
rm -f .openshift_install_state.json
openshift-install agent create cluster-manifests --dir .
openshift-install agent wait-for install-complete --dir . --log-level info
```

### 8. Confirm Ready (bastion)

```bash
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig
oc get nodes
oc get co
```

---

## Rebuild OCP only

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
terraform destroy -auto-approve && terraform apply -auto-approve
```

Full rebuild notes: [iac.md](iac.md)

---

## Done when

Cluster **Ready** — nodes Ready, cluster operators available.

→ [DAY2.md](DAY2.md) — Operations

# Infrastructure as Code (Terraform + Ansible)

| Outil | Périmètre |
|-------|-----------|
| [Terraform](../terraform/README.md) | VMs Proxmox : dns, registry (+ disque données), bastion (2 NICs) |
| [Ansible](../ansible/README.md) | OS : NTP, dnsmasq (base), disque `/opt/registry`, bastion preflight |

OpenShift (ISO agent, SNO, `oc-mirror`) reste documenté dans `openshift/` et `mirror/`.

## Parcours recommandé

### Lab déjà en place (ton cas)

1. Ne pas `terraform apply` sur des VMs existantes sans plan précis.
2. `cp ansible/inventory/hosts.yml.example ansible/inventory/hosts.yml`
3. `cp ansible/group_vars/all.yml.example ansible/group_vars/all.yml`
4. `registry_data_device: ""` tant que la registry utilise `/home/registry` ou `/opt` manuel.
5. `ansible-playbook ansible/playbooks/lab-infra.yml` (depuis le Mac, repo cloné).

### Nouvelle registry propre

1. Token API Proxmox → `terraform/proxmox/terraform.tfvars`
2. `terraform apply` → registry avec **scsi1 120G**
3. `registry_data_device: /dev/sdb` dans Ansible
4. Playbook + certs TLS + mirror

## Variables partagées

Aligner avec [versions.env.example](../versions.env.example) (`DNS_IP`, `REGISTRY_IP`, `PROXMOX_HOST`).

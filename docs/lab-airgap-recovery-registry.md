# Récupération — registry lab air-gap 4.22

La VM **registry** a pu être supprimée par **Terraform** (`create_registry = false` dans le mauvais state).  
Tu peux aussi **arrêter** le lab air-gap volontairement — voir [lab-airgap-teardown.md](lab-airgap-teardown.md).

## Ordre de récupération

### 1. Isoler les futurs tests OCP5 connecté

Utiliser **uniquement** :

```bash
cd terraform/assisted-ocp-bma
```

**Ne plus** mélanger OCP5 dans `terraform/lab-airgap/`.

### 2. Recréer la VM registry (Terraform lab infra)

**Mac** :

```bash
cd terraform/lab-airgap
```

Dans **`terraform.tfvars`** :

```hcl
create_registry = true
create_dns      = false
create_bastion  = false
```

Vérifier **plan** : `+ registry` ou recreate, **aucun** `- registry`.

```bash
terraform plan
terraform apply
```

Référence : [registry-reinstall-terraform.md](registry-reinstall-terraform.md) — ISO RHEL `registry_install_iso` ou template selon ton tfvars.

### 3. Réinstaller RHEL + disque données

Console Proxmox → VM **registry** (clone template) :

- **virtio0** : OS (`/dev/vda`)
- **virtio1** : ~120 Go → `/opt/registry` (Ansible `registry_data_device: /dev/vdb`)

Si install **ISO Anaconda** : scsi0 + scsi1 → `/dev/sda` + `/dev/sdb`.

Suivre [registry/README.md](../registry/README.md) (réseau `172.16.10.20`, podman, TLS).

### 4. Ansible registry

**Mac** :

```bash
cd ansible
ansible-playbook playbooks/registry.yml --ask-become-pass
```

(`registry_data_device` dans `group_vars/all.yml` — clone : `/dev/vdb`.)

### 5. Re-mirror OCP 4.22 (obligatoire si disques NFS recréés)

Les images **~22 Go** sur l’ancien disque VM sont **perdues** si les volumes Proxmox ont été recréés vides.

**Bastion** (Internet via `vmbr0` / phase préparation) :

```bash
# Reprendre mirror GA — mirror/README.md
oc-mirror … → registry.lab.local:5000/ocp4-422
```

Puis vérifier depuis bastion : `curl -sk https://registry.lab.local:5000/v2/_catalog`

### 6. Cluster 4.22

Si le SNO tourne encore : `oc` peut échouer sur pull tant que registry vide. Après mirror OK, pas de réinstall SNO nécessaire sauf si tu as cassé IDMS / certs.

## Prévention

| Règle |
|--------|
| OCP5 connecté → **`terraform/assisted-ocp-bma/`** seulement |
| Lab infra → **`terraform/lab-airgap/`** — ne jamais `create_registry = false` si registry dans le state |
| Avant tout `apply` : lire **`Plan:`** — **0 destroy** sur registry/dns/bastion |
| Ne pas `cp … terraform.tfvars` sans backup |

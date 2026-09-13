# Ansible — configuration lab infra

Configure **DNS**, **registry** (disque données + Podman), **bastion** (NTP client, script preflight).  
À lancer **depuis le Mac** (ProxyJump Proxmox) ou depuis la bastion pour les hôtes lab uniquement.

## Prérequis

```bash
python3 -m pip install --user ansible
# ou : dnf install ansible-core  (sur bastion / RHEL)
```

## Inventaire

```bash
cd ansible
cp inventory/hosts.yml.example inventory/hosts.yml
cp group_vars/all.yml.example group_vars/all.yml
# Éditer hosts.yml : IP admin bastion, user SSH
```

Connexion typique depuis le **Mac** :

- `bastion` : SSH direct sur IP LAN (`vmbr0`)
- `dns`, `registry` : `ansible_host` = IP lab + `ProxyJump` via Proxmox (voir `hosts.yml.example`)

## Playbooks

| Playbook | Rôle |
|----------|------|
| `playbooks/lab-infra.yml` | DNS → registry → bastion (ordre boot lab) |
| `playbooks/registry-data-disk.yml` | Seulement disque `/opt/registry` sur registry |

```bash
cd ansible
ansible-playbook playbooks/lab-infra.yml
```

Check sans modifier :

```bash
ansible-playbook playbooks/lab-infra.yml --check --diff
```

## Registry : disque données

Si Terraform a créé **scsi1** (120 Go), le rôle `registry` formate et monte `/opt/registry`.  
Sur une VM **existante** sans second disque, définir dans `group_vars/all.yml` :

```yaml
registry_data_device: ""   # vide = pas de mkfs ; utiliser migration manuelle /home
```

## Certificats registry

Les clés TLS ne sont **pas** générées par Ansible (secrets). Après le rôle registry :

1. Générer les certs — [registry/README.md](../registry/README.md) §4  
2. Ou placer `ca.crt`, `registry.crt`, `registry.key` dans `files/registry-certs/` (gitignoré) et activer `registry_manage_certs: true` dans `group_vars/all.yml`

## Relation Terraform

1. `terraform apply` (nouvelles VMs)  
2. `ansible-playbook playbooks/lab-infra.yml`  
3. Mirror / install OCP — docs existantes

Pour le lab **déjà en place** : sauter Terraform, ajuster `inventory/hosts.yml` et lancer Ansible.

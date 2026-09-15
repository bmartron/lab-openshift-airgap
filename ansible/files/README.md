# Fichiers locaux (Mac) — non versionnés

À placer ici avant `ansible-playbook playbooks/bastion-ocp-install.yml` :

| Fichier | Source |
|---------|--------|
| `pull-secret.txt` | [console.redhat.com — pull secret](https://cloud.redhat.com/openshift/install/pull-secret) |
| `install_ssh_key.pub` | Clé publique **bastion** pour `ssh core@172.16.10.100` — convention lab : **pas** la clé Mac ([docs/sno-ssh-convention.md](../../docs/sno-ssh-convention.md)) |

```bash
cp ~/Downloads/pull-secret.txt ansible/files/pull-secret.txt
scp bernard@192.168.1.144:~/.ssh/id_ed25519.pub ansible/files/install_ssh_key.pub
```

Optionnel si tu n’inclus pas l’hôte `registry` dans l’inventaire :

| `registry-ca.crt` | `scp bernard@172.16.10.20:/opt/registry/certs/ca.crt ansible/files/registry-ca.crt` |

Dans **`ansible/inventory/group_vars/all.yml`** (pas `ansible/group_vars/`) :

```yaml
ocp_sno_mac: "BC:24:11:aa:bb:cc"   # qm config <VMID> | grep net sur Proxmox
```

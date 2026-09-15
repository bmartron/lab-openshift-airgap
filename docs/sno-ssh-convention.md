# Convention SSH — nœud SNO (`core@172.16.10.100`)

Une seule règle lab : **toutes les connexions `core@172.16.10.100` passent par la bastion**, pas un coup Mac direct, un coup clé bastion.

| Rôle | Accès `core@SNO` |
|------|------------------|
| **Mac** | **Non** — pas de `ssh core@172.16.10.100` (ni jump Proxmox direct pour le day‑2) |
| **Bastion** | **Oui** — `ssh core@172.16.10.100` avec la clé définie dans `install-config` |

Console web / `oc` : bastion avec **`KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig-admin`** (API via lb-ext, cert valide). Ne pas utiliser `auth/kubeconfig` généré à l’install pour le day‑2 si erreurs TLS.

Ansible / git : Mac → bastion LAN `bernard@192.168.1.144` uniquement.

Le champ **`sshKey`** doit contenir **uniquement la clé publique de la bastion** (pas la clé Mac).

**Bastion** — générer si besoin :

```bash
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

**Mac** — alimenter Ansible (fichier gitignoré) :

```bash
scp bernard@192.168.1.144:~/.ssh/id_ed25519.pub \
  /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible/files/install_ssh_key.pub

cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass
```

Puis regénérer ISO / réinstall si le cluster existant n’a pas cette clé (ou ajout ponctuel via `oc debug node` — voir [proxmox/sno-vm.md](../proxmox/sno-vm.md)).

## Connexion quotidienne

**Mac** → session bastion :

```bash
ssh bernard@192.168.1.144
```

**Bastion** → SNO :

```bash
ssh-keygen -R 172.16.10.100    # après chaque réinstall SNO
ssh-keygen -R '[172.16.10.100]:22'
ssh core@172.16.10.100
```

**Bastion** — `~/.ssh/config` (recommandé) :

```text
Host sno
  HostName 172.16.10.100
  User core
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
```

```bash
ssh sno
```

## Réinstall SNO

1. Mettre à jour `install_ssh_key.pub` depuis la bastion (ci‑dessus) si la clé bastion a changé.
2. `ansible-playbook playbooks/bastion-ocp-install.yml` → regénérer ISO / install.
3. Sur la **bastion** uniquement : `ssh-keygen -R 172.16.10.100` puis `ssh sno`.

## Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/bastion-ocp-install.yml` |
| **Fichier** | `ansible/files/install_ssh_key.pub` (= pubkey **bastion**) |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass` |

Voir aussi [ansible/files/README.md](../ansible/files/README.md), [docs/ansible-manual-parity.md](ansible-manual-parity.md).

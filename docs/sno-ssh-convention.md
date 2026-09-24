# SSH convention — SNO node (`core@172.16.10.100`)

One lab rule: **all `core@172.16.10.100` sessions go through the bastion** — never Mac direct one day and bastion key the next.

| Role | `core@SNO` access |
|------|-------------------|
| **Mac** | **No** — do not `ssh core@172.16.10.100` (and do not jump via Proxmox for day-2) |
| **Bastion** | **Yes** — `ssh core@172.16.10.100` with the key set in `install-config` |

Web console / `oc`: on bastion with **`KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig-admin`** (API via lb-ext, valid cert). Do not use the install-time `auth/kubeconfig` for day-2 if you hit TLS errors.

Ansible / git: Mac → bastion LAN `bernard@192.168.1.144` only.

The **`sshKey`** field must contain **only the bastion public key** (not the Mac key). Cloud-init SSH keys on RHEL VMs (`bernard@`) are separate from this SNO rule.

**Bastion** — generate if needed:

```bash
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

**Mac** — feed Ansible (gitignored file):

```bash
scp bernard@192.168.1.144:~/.ssh/id_ed25519.pub \
  /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible/files/install_ssh_key.pub

cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass
```

Then regenerate the ISO / reinstall if the existing cluster does not have this key (or add it once via `oc debug node`). Recreate the SNO VM with Terraform if needed — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md).

## Daily connection

**Mac** → bastion session:

```bash
ssh bernard@192.168.1.144
```

**Bastion** → SNO:

```bash
ssh-keygen -R 172.16.10.100    # after every SNO reinstall
ssh-keygen -R '[172.16.10.100]:22'
ssh core@172.16.10.100
```

**Bastion** — `~/.ssh/config` (recommended):

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

## SNO reinstall

1. Refresh `install_ssh_key.pub` from the bastion (above) if the bastion key changed.
2. `ansible-playbook playbooks/bastion-ocp-install.yml` → regenerate ISO / install.
3. On the **bastion** only: `ssh-keygen -R 172.16.10.100` then `ssh sno`.

## Ansible equivalent

| | |
|---|---|
| **Playbook** | `ansible/playbooks/bastion-ocp-install.yml` |
| **File** | `ansible/files/install_ssh_key.pub` (= **bastion** pubkey) |
| **Command (Mac)** | `cd ansible && ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass` |

See also [ansible/files/README.md](../ansible/files/README.md).

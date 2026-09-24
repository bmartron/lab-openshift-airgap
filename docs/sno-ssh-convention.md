# SSH convention — SNO node (`core@172.16.10.100`)

One lab rule: **all `core@172.16.10.100` sessions go through the bastion** — never Mac direct one day and bastion key the next.

| Role | `core@SNO` access |
|------|-------------------|
| **Mac** | **No** — do not `ssh core@172.16.10.100` (and do not jump via Proxmox for day-2) |
| **Bastion** | **Yes** — `ssh core@172.16.10.100` with the key set in `install-config` |

Web console / `oc`: on bastion with **`KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig-admin`** (API via lb-ext, valid cert). Do not use the install-time `auth/kubeconfig` for day-2 if you hit TLS errors.

Ansible / git: Mac → bastion LAN `bernard@192.168.1.144` only.

The **`sshKey`** field must contain **only the bastion public key** (not the Mac key). Cloud-init SSH keys on RHEL VMs (`bernard@`) are separate from this SNO rule.

## How the key is embedded

`bastion-ocp-install` **slurps** `/home/<lab_user>/.ssh/id_ed25519.pub` on the bastion and writes it into `install-config` / the agent ISO. No Mac `install_ssh_key.pub` copy.

`lab-infra` (`proxmox_ssh`) creates that key if missing (also used for ISO scp to Proxmox).

**Bastion recreated** (Terraform): a **new** keypair is generated → re-run `bastion-ocp-install` with `ocp_agent_generate_iso: true` (and push ISO) before reinstalling the SNO. An old ISO keeps the previous pubkey → `Permission denied (publickey)`.

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass
```

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

1. If the bastion was recreated, regenerate the agent ISO via Ansible (live key).
2. Recreate / wipe the SNO VM if needed — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md).
3. On the **bastion** only: `ssh-keygen -R 172.16.10.100` then `ssh sno`.

## Ansible equivalent

| | |
|---|---|
| **Playbook** | `ansible/playbooks/bastion-ocp-install.yml` |
| **Key source** | Bastion `~/.ssh/id_ed25519.pub` (live) |
| **Mac file** | `ansible/files/pull-secret.txt` only |
| **Command (Mac)** | `cd ansible && ansible-playbook playbooks/bastion-ocp-install.yml --ask-become-pass` |

See also [ansible/files/README.md](../ansible/files/README.md).

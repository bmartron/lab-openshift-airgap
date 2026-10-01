# Local files (Mac) — not versioned

Place here before `ansible-playbook playbooks/bastion-ocp-install.yml`:

| File | Source |
|------|--------|
| `pull-secret.txt` | [console.redhat.com — pull secret](https://cloud.redhat.com/openshift/install/pull-secret) |

```bash
cp ~/Downloads/pull-secret.txt ansible/files/pull-secret.txt
```

**SNO `sshKey`**: not a Mac file. `bastion-ocp-install` reads the live bastion pubkey
`/home/<lab_user>/.ssh/id_ed25519.pub` (created by `lab-infra` / this role).
See [docs/sno-ssh-convention.md](../../docs/sno-ssh-convention.md).

Optional if the inventory does not include host `registry`:

| `registry-ca.crt` | `scp bernard@172.16.10.20:/opt/registry/certs/ca.crt ansible/files/registry-ca.crt` |

In **`ansible/inventory/group_vars/all.yml`** (not `ansible/group_vars/`):

```yaml
ocp_sno_mac: "bc:24:11:aa:bb:cc"   # qm config <VMID> | grep net on Proxmox
```

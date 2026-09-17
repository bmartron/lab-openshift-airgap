# VM SNO OpenShift — Proxmox

Gestion de la VM `ocp-sno` (172.16.10.100) sur `vmbr1`.

Option Terraform : [terraform/lab-airgap/vm-sno.tf](../terraform/lab-airgap/vm-sno.tf) (`create_sno = true` dans `terraform.tfvars.airgap.example`).

## Spécifications (validées lab)

| Paramètre | Valeur |
|-----------|--------|
| Disque | 120 Go, bus **SCSI** → `/dev/sda` dans `agent-config.yaml` |
| NIC | `vmbr1`, VirtIO — noter la **MAC** pour l'agent config |
| Boot install | ISO `agent.x86_64.iso` (NFS / datastore Proxmox) |

Install agent validée : **~30 min** (mirror déjà présent sur le registry).

## Réinstall sans recréer la VM

Le **mirror registry ne se refait pas**. Sur le bastion : restaurer `config-backup/`, régénérer l'ISO si besoin, `wait-for install-complete`.

Voir [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) § Réinstall.

## Effacer le disque d'installation

### Option A — Wipe depuis l'ISO agent (souvent suffisant)

Boot sur l'ISO, SSH `core@172.16.10.100` :

```bash
sudo wipefs -a /dev/sda
```

Relancer l'install (l'installer formate aussi le disque cible).

### Option B — Remplacer le disque dans Proxmox

> **Detach seul ne supprime pas le volume** : Proxmox déplace le disque en **Unused Disk** ; la VM garde une référence tant que `unused0` existe.

1. **Arrêter** la VM (`stopped`).
2. **Hardware** → disque `scsi0` → **Detach**.
3. **Hardware** → **Unused Disk 0** → **Remove** → cocher **Delete from storage** si proposé.
4. **Add** → Hard Disk → `scsi0`, 120 Go, même storage NFS.
5. Attacher l'ISO agent, démarrer.

Sans l'étape 3, la suppression dans **Datacenter → Storage → Content** est souvent **refusée** (volume encore lié à la VM via `unused0`).

### CLI Proxmox (`root@pve`)

```bash
VMID=XXX   # ID de la VM SNO

qm stop $VMID
qm detach $VMID scsi0
qm config $VMID                    # doit montrer unused0: ...

qm disk unlink $VMID --idlist unused0 --force

qm set $VMID --scsi0 VOTRE-STORAGE:120,format=raw
# ISO agent (adapter le chemin)
qm set $VMID --ide2 VOTRE-STORAGE:iso/agent.x86_64.iso,media=cdrom
qm start $VMID
```

Adapter `VOTRE-STORAGE`, bus (`scsi0` / `virtio0`) et `VMID`.

## SSH SNO après réinstall (`core@172.16.10.100`)

Convention : **bastion uniquement** — [docs/sno-ssh-convention.md](../docs/sno-ssh-convention.md).

Chaque réinstall → *REMOTE HOST IDENTIFICATION HAS CHANGED* → sur la **bastion** :

```bash
ssh-keygen -R 172.16.10.100
ssh-keygen -R '[172.16.10.100]:22'
ssh core@172.16.10.100
```

`sshKey` = clé publique **bastion** (`ansible/files/install_ssh_key.pub`). **Mac** : pas de SSH `core` direct.

Voir [access.md](access.md) § SSH nœud SNO.

## Dépannage disque

| Symptôme | Cause | Action |
|----------|-------|--------|
| Impossible de supprimer le disque dans Content | Disque encore en **Unused** sur la VM | Remove **Unused Disk** sur la VM |
| Impossible de Detach | VM encore running | `qm stop` / arrêt forcé |
| OpenShift `/dev/not-found-by-hints` | Mauvais `rootDeviceHints` | SCSI Proxmox → `/dev/sda` — voir [4.22-ga](../openshift/4.22-ga/README.md) |

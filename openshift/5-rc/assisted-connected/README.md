# OpenShift 5 — Assisted Installer connecté (`ocp-bma.home.arpa`)

Déploiement **Internet** via [console.redhat.com](https://console.redhat.com/openshift/create), **3 VMs Proxmox** sur **`vmbr0` (LAN maison)**.  
**Hors** périmètre lab air-gap : pas de `vmbr1`, pas de VM **bastion**, pas de **dns** `172.16.10.11`, pas de registry mirror pour ce test.

| Paramètre | Valeur **ce test** |
|-----------|---------------------|
| **Cluster name** | `ocp-bma` |
| **Base domain** | `home.arpa` |
| **API** | `api.ocp-bma.home.arpa` |
| **Apps** | `*.apps.ocp-bma.home.arpa` |
| **DNS** | **DNS maison** (box, ex. `192.168.1.1`) — voir [dns-records.example](dns-records.example) |
| **Réseau nœuds** | Proxmox **`vmbr0`** — DHCP LAN + accès Internet |
| **Version** | OpenShift **5** (RC choisi dans la console, ex. `5.0.0-ec.6`) |
| **Topologie** | **3 nœuds** compact (CP + worker) |
| **VMs Terraform** | `ocp-bma-ai-0` … `ocp-bma-ai-2` |

Paramètres copiables : [cluster-params.env.example](cluster-params.env.example).

> **Important** : OCP5 connecté → **`terraform/assisted-ocp-bma/`** seulement. Infra air-gap 4.22 → **`terraform/lab-airgap/`** (states **séparés**). Ne pas mélanger.

## Périmètre explicite

| Utilisé | Non utilisé (lab air-gap 4.22) |
|---------|--------------------------------|
| Mac → Proxmox `192.168.1.147` | Bastion `bernard@192.168.1.144` / `172.16.10.10` |
| DNS box `home.arpa` | `dnsmasq` `172.16.10.11` / `*.lab.local` |
| Pull images Red Hat / Quay (Internet) | `registry.lab.local`, IDMS, `oc-mirror` |
| Bridge **`vmbr0`** | Bridge **`vmbr1`** |

## Prérequis

| Élément | Détail |
|---------|--------|
| Compte Red Hat | Assisted Installer |
| Proxmox + token | [terraform/README.md](../../terraform/README.md) |
| ISO discovery | Téléchargée depuis la console (1 par cluster) → stockage ISO Proxmox |
| Clé SSH publique | **Mac** : `cat ~/.ssh/id_ed25519.pub` — [ssh-key.notes.example](ssh-key.notes.example) |
| **API VIP** | `192.168.1.49` — DNS + console Assisted |
| **Ingress VIP** | `192.168.1.48` — `*.apps` |
| DNS maison | Enregistrements **avant** preflight — [dns-records.example](dns-records.example) |
| Ressources / VM | Terraform : **8 vCPU, 24 GiB, 120 Go + 50 Go** par nœud |

## 1. Console Red Hat

1. **Create cluster** → **Assisted Installer**.
2. Version **OpenShift 5**.
3. **3 hosts** HA / compact.
4. **Cluster name** : `ocp-bma` — **Base domain** : `home.arpa`  
   (l’API attendue est `api.ocp-bma.home.arpa`, pas un seul champ « ocp-bma.home.arpa »).
5. **SSH public key** : clé **Mac**.
6. **API VIP** : `192.168.1.49` — **Ingress VIP** : `192.168.1.48`.
7. Télécharger l’**ISO discovery**.

## 2. DNS maison (obligatoire)

Sur la **box** ou serveur DNS du LAN (pas le lab) :

- `api.ocp-bma.home.arpa` / `api-int` → **`192.168.1.49`**
- `*.apps.ocp-bma.home.arpa` → **`192.168.1.48`**

Modèle : [dns-records.example](dns-records.example).

Vérification **Mac** :

```bash
dig +short api.ocp-bma.home.arpa @192.168.1.1
dig +short console-openshift-console.apps.ocp-bma.home.arpa @192.168.1.1
```

## 3. ISO sur Proxmox

```bash
scp ~/Downloads/discovery*.iso root@192.168.1.147:/mnt/pve/nfs_iso/template/iso/ocp-bma-discovery.iso
```

Terraform : **`storage = "nfs_vm"`**, **`discovery_iso = "nfs_iso:iso/ocp-bma-discovery.iso"`**

## 4. Terraform (Mac) — stack **isolée**

**Répertoire** : `terraform/assisted-ocp-bma/` (state **séparé** — ne touche pas registry/dns/bastion).

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/assisted-ocp-bma
cp terraform.tfvars.example terraform.tfvars
# Token Proxmox + discovery_iso

terraform init
terraform plan    # uniquement 3 VMs ocp-bma-ai-* ; aucun destroy registry
terraform apply
```

Doc stack : [terraform/assisted-ocp-bma/README.md](../../terraform/assisted-ocp-bma/README.md).

**Interdit** : mélanger OCP5 et infra 4.22 dans le **même** `terraform.tfstate`.

## 5. Démarrage discovery

1. Allumer **`ocp-bma-ai-0`**, **`-1`**, **`-2`** (ISO ide2, boot UEFI).
2. Console Red Hat : hôtes **Ready**.
3. Rôles : **3 × control plane** (et worker si topology compacte).
4. **DNS** dans l’assistant : serveur **`192.168.1.1`** (ou IP DNS maison) — pas `172.16.10.11`.
5. Lancer l’installation (preflight doit valider **DNS** + **connectivité Internet**).

## 6. Après install

- Récupérer **kubeadmin** / **kubeconfig** depuis la console.
- `oc login` / console : `https://console-openshift-console.apps.ocp-bma.home.arpa` (résolution via DNS maison).
- `ssh core@<ip-lan-nœud>` depuis le **Mac** (clé enregistrée à la création du cluster).

## Nettoyage

```bash
cd terraform/assisted-ocp-bma && terraform destroy
```

Supprimer le cluster dans console.redhat.com ; retirer les enregistrements DNS `home.arpa` sur la box.

## Autre doc lab

- Air-gap SNO / agent 5 RC : [../README.md](../README.md)  
- Réseau lab isolé `172.16.10.0/24` : [docs/network.md](../../docs/network.md) (non utilisé pour **ocp-bma**)

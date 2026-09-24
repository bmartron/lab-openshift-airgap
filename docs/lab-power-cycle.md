# Arrêt et démarrage du lab (coupure quotidienne)

Procédure pour éteindre et rallumer le lab sans casser le SNO (DNS, registry, NTP, certs kubelet).

> **Ansible** : équivalents playbook dans les sections ci-dessous — [ansible/README.md](../ansible/README.md).

## VMs et IPs (`vmbr1`)

| Ordre démarrage | VM | IP | Rôle |
|-----------------|-----|-----|------|
| 1 | `dns` | `172.16.10.11` | dnsmasq + **NTP** (chrony) |
| 2 | `registry` | `172.16.10.20` | mirror `registry:2` (Podman) |
| 3 | `bastion` | `172.16.10.10` | `oc`, contrôles |
| 4 | `ocp-sno` | `172.16.10.100` | OpenShift SNO GA |

Proxmox : `192.168.1.147` (LAN, `vmbr0`).

> **Ne pas** démarrer toutes les VMs en même temps : le SNO a besoin de DNS, registry et NTP stables **avant** son boot.

---

## Arrêt recommandé

Sur **Proxmox** (`192.168.1.147`) ou CLI :

1. **SNO** (`ocp-sno`) — Shutdown (ACPI), pas Stop sauf urgence.
2. **Registry** — Shutdown ou laisser tourner si tu n’éteins que le SNO.
3. **DNS** — Shutdown.
4. **Bastion** — optionnel (souvent laissée pour préparer le mirror).

Pas d’étape obligatoire sur le cluster avant coupure pour un lab perso ; un arrêt propre du SNO suffit.

---

## Démarrage recommandé

### 1. Proxmox + NAS NFS

Vérifier que le stockage NFS est monté (VMs sur NFS).

### 2. Démarrer les VMs dans l’ordre

| Étape | VM | Attendre |
|-------|-----|----------|
| A | **DNS** `172.16.10.11` | ~1–2 min, dnsmasq actif |
| B | **Registry** `172.16.10.20` | conteneur `ocp-registry` Up |
| C | **Bastion** `172.16.10.10` | SSH OK |
| D | **SNO** `172.16.10.100` | **seulement après** script OK |

### 3. Contrôle depuis la bastion

Copier le script du dépôt sur la bastion (une fois) :

Sur la **bastion** (ou en une ligne depuis le Mac) :

```bash
ssh -J root@192.168.1.147 bernard@172.16.10.10 'mkdir -p ~/lab/scripts'
```

Depuis le **Mac** :

```bash
scp -J root@192.168.1.147 \
  /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/bastion/scripts/lab-startup-check.sh \
  bernard@172.16.10.10:~/lab/scripts/
```

Puis sur la bastion :

```bash
chmod +x ~/lab/scripts/lab-startup-check.sh
```

Lancer **avant** de démarrer (ou juste après le démarrage de) le SNO :

```bash
~/lab/scripts/lab-startup-check.sh
```

Code de sortie **0** = prérequis OK pour démarrer ou laisser finir le boot du SNO.

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/bastion-scripts.yml` |
| **Hôte** | `bastion` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/bastion-scripts.yml --ask-become-pass` |
| **Couverture** | Déploie `~/lab/scripts/lab-startup-check.sh` (évite `scp` manuel) |
| **Hors Ansible** | Exécution du script sur la bastion après boot infra |

### 4. Après démarrage du SNO

Délai typique : **20–45 min** (RAM qui monte, CO qui passent au vert).

Sur la bastion :

```bash
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig-admin   # ou lb-ext copié depuis le nœud
oc get nodes
curl -k -s -o /dev/null -w "healthz %{http_code}\n" https://172.16.10.100:6443/healthz
```

Console : voir [proxmox/access.md](../proxmox/access.md) (tunnel depuis le Mac).

---

## NTP (obligatoire pour OpenShift)

- **Serveur NTP lab** : VM **DNS** `172.16.10.11` (chrony) — voir [dns/README.md](../dns/README.md) §6.
- **SNO** : `additionalNTPSources: [172.16.10.11]` dans `agent-config.yaml` (backup dans `config-backup/`).
- **Bastion** : doit synchroniser vers `172.16.10.11` (chrony client) pour des checks cohérents.

Le script `lab-startup-check.sh` vérifie l’horloge de la bastion et la joignabilité NTP sur le DNS.

Si le SNO affiche des erreurs de certificats après une coupure longue, voir **Dépannage** ci-dessous.

---

## Registry au boot

Le conteneur `ocp-registry` peut rester **Exited** après reboot de la VM registry.

Sur **registry** `172.16.10.20` :

```bash
sudo podman start ocp-registry
sleep 3
curl -k https://127.0.0.1:5000/v2/_catalog
```

Persistance au boot : `podman-restart.service` + `--restart=always` — voir [registry/README.md](../registry/README.md).

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/registry.yml` (conteneur `--restart=always` à la création) |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/registry.yml --limit registry --ask-become-pass` |
| **Hors Ansible** | `systemctl enable --now podman-restart.service` sur la VM si le conteneur reste **Exited** au reboot |

---

## DNS au boot

Si `dig @172.16.10.11` → *connection refused*, sur **DNS** `172.16.10.11` :

```bash
sudo systemctl start dnsmasq
```

Renforcer le boot : drop-in systemd `After=network-online.target` + `Restart=on-failure` — déployé par le rôle Ansible `dns` (`lab-infra.yml`) ; manuel : [dns/README.md](../dns/README.md).

### Équivalent Ansible

| | |
|---|---|
| **Playbook** | `ansible/playbooks/lab-infra.yml` |
| **Hôte** | `dns` |
| **Commande (Mac)** | `cd ansible && ansible-playbook playbooks/lab-infra.yml --limit dns --ask-become-pass` |
| **Couverture** | Drop-in `dnsmasq.service.d/after-network.conf`, enable dnsmasq |
| **Hors Ansible** | `systemctl start dnsmasq` ponctuel si la VM est up sans le service |

---

## Dépannage après mauvais démarrage

| Symptôme | Cause fréquente | Action |
|----------|-----------------|--------|
| SNO long, pas de 443 | DNS/registry down au boot | Ordre de démarrage + script bastion |
| `node NotReady`, CNI vide | OVN / patch OVS | Voir session debug ; reboot SNO **après** infra OK |
| CSR `Pending` (kubelet) | approve auto en retard | `oc adm certificate approve` (kubeconfig admin) |
| CSR `Denied` node-bootstrapper | mauvaises approbations | Ne pas approuver les CSR hors kubelet-serving ; `rm /var/lib/kubelet/kubeconfig` copie bootstrap |
| `oc` / console | kubeconfig install | `kubeconfig-admin` (lb-ext) sur bastion |

Admin cluster depuis bastion : copier `lb-ext.kubeconfig` depuis le SNO (une fois) :

```bash
# Sur SNO — core@172.16.10.100
sudo cp /etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/lb-ext.kubeconfig /tmp/lb-ext.kubeconfig
sudo chown core:core /tmp/lb-ext.kubeconfig
# Vers bastion
scp /tmp/lb-ext.kubeconfig bernard@172.16.10.10:~/lab/4.22-ga/auth/kubeconfig-admin
```

---

## Références

- [dns/README.md](../dns/README.md) — dnsmasq, NTP, firewall
- [registry/README.md](../registry/README.md) — Podman registry
- [proxmox/access.md](../proxmox/access.md) — SSH, console Mac
- [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) — post-install

# OpenShift Virtualization + LVMS — lab air-gap (SNO)

Retour d’expérience lab : opérateurs, stockage local, import ISO invitée.

## Prérequis

| Composant | Détail |
|-----------|--------|
| Mirror | Profil **LVMS** seul ou **virt-lvms** — [mirror/imageset-config-4.22-lvms.yaml.example](../mirror/imageset-config-4.22-lvms.yaml.example) |
| Cluster | `oc apply` **IDMS/ITMS** depuis `workspace-*/working-dir/cluster-resources/` |
| Catalogue OLM | Après mirror : `oc delete pod -n openshift-marketplace -l olm.catalogSource=cs-redhat-operator-index-v4-22` puis `oc get packagemanifest \| grep lvms` |
| LVMS | 2ᵉ disque SCSI sur VM SNO (Proxmox) — `sda` = OCP, **`sdb`** = LVMS |
| Nested virt | CPU **host** sur VM SNO — [proxmox/network.md](../proxmox/network.md) |
| `oc` | `KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig-admin` — [docs/sno-ssh-convention.md](sno-ssh-convention.md) |

## LVMS

1. Installer **`lvms-operator`** (Operator Hub ou Subscription, canal **`stable-4.22`**).
2. Créer **LVMCluster** (ex. nom **`lvms`**) sur device **`/dev/sdb`** (préférer `/dev/disk/by-id/...`).
3. StorageClass typique : **`lvms-vg1`** (`topolvm.io`, `WaitForFirstConsumer`).

Test PVC :

```bash
oc apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-lvms
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
  storageClassName: lvms-vg1
EOF
```

Avec `WaitForFirstConsumer`, lier un pod consommateur pour voir **Bound**.

## Operator Hub vs Software Catalog

| UI | Usage |
|----|--------|
| **Operators → Operator Hub** | **`lvms-operator`**, **`kubevirt-hyperconverged`** |
| **Software Catalog / HostPathProvisioner deployment** | Parcours CDI/HCO, pas un substitut ; erreurs **404** fréquentes en air-gap |

Sans **`packagemanifest`** pour le package : catalogue miroir pas rechargé (voir delete pod catalogue ci-dessus).

## Import ISO invitée (RHEL, etc.)

Objectif : PVC bootable sur **`lvms-vg1`**, pas un « repo » sur la bastion.

### Mac → bastion

```bash
scp /chemin/fichier.iso bernard@192.168.1.144:~/lab/isos/
```

### IDMS / ITMS (obligatoire)

Les pods CDI (`virt-cdi-uploadserver`, `virt-cdi-importer`) référencent **`registry.redhat.io/...`**. Les images sont sur **`registry.lab.local:5000/ocp4-422/container-native-virtualization/...`** après mirror Virt — sans miroirs cluster → **ImagePullBackOff** / timeout upload.

```bash
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig-admin
oc apply -f ~/lab/4.22-ga/workspace-lvms/working-dir/cluster-resources/idms-oc-mirror.yaml
oc apply -f ~/lab/4.22-ga/workspace-lvms/working-dir/cluster-resources/itms-oc-mirror.yaml
```

*(Utiliser le `cluster-resources/` du workspace du dernier `oc-mirror` opérateurs.)*

### `virtctl` (bastion)

Le chemin **`mirror.openshift.com/.../clients/virt/virtctl`** renvoie **404 HTML** — ne pas l’installer tel quel (`syntax error: '<html>'`).

Aligner la version client sur le cluster :

```bash
oc get kubevirt kubevirt -n openshift-cnv -o jsonpath='{.status.observedKubeVirtVersion}{"\n"}'
# ex. v1.8.4

curl -L -o /tmp/virtctl \
  https://github.com/kubevirt/kubevirt/releases/download/v1.8.4/virtctl-v1.8.4-linux-amd64
file /tmp/virtctl   # ELF, pas HTML
chmod +x /tmp/virtctl && sudo mv /tmp/virtctl /usr/local/bin/virtctl
```

Upload (syntaxe récente) :

```bash
virtctl image-upload default/rhel-10-2-dvd \
  --size=15Gi \
  --storage-class=lvms-vg1 \
  --image-path=$HOME/lab/isos/rhel-10.2-x86_64-dvd.iso \
  --insecure \
  --access-mode=ReadWriteOnce \
  --namespace=default
```

Suivi : `oc get pvc rhel-10-2-dvd -w`, pods `cdi-upload-*` en **Running**.

Nettoyage upload raté :

```bash
oc delete datavolume,pvc -n default --all   # ou noms ciblés
oc delete pod -n default -l cdi.kubevirt.io=uploadserver --force --grace-period=0
```

### Alternative HTTP (sans `virtctl`)

Terminal 1 :

```bash
cd ~/lab/isos && python3 -m http.server 8080 --bind 172.16.10.10
```

Terminal 2 : DataVolume `spec.source.http.url` → `http://172.16.10.10:8080/fichier.iso`, `storageClassName: lvms-vg1`, taille ≥ ISO.

### Console Mac + tunnel SSH

Tunnel : `sudo ssh -L 443:172.16.10.100:443 -N bernard@192.168.1.144`

`/etc/hosts` sur le **Mac** — FQDN apps en **`127.0.0.1`** (pas `172.16.10.100`) :

```text
127.0.0.1  console-openshift-console.apps.ocp422.lab.local
127.0.0.1  oauth-openshift.apps.ocp422.lab.local
127.0.0.1  cdi-uploadproxy-openshift-cnv.apps.ocp422.lab.local
```

Certificat : ouvrir  
`https://cdi-uploadproxy-openshift-cnv.apps.ocp422.lab.local/v1beta1/upload-form-async`  
(**404** sur `/` seul est normal), puis relancer l’upload console.

Détail tunnel : [proxmox/access.md](../proxmox/access.md) § Console OpenShift.

## Complétions bash (`oc`, `virtctl`)

Sur bastion : paquet **`bash-completion`** (repo DVD si pas d’Internet — [rhel/dvd-repo.md](../rhel/dvd-repo.md)), puis :

```bash
oc completion bash | sudo tee /etc/bash_completion.d/oc
virtctl completion bash | sudo tee /etc/bash_completion.d/virtctl
```

Charger **`/usr/share/bash-completion/bash_completion`** dans `~/.bashrc` **avant** toute source manuelle de `/etc/bash_completion.d/oc` (évite `_get_comp_words_by_ref: command not found`).

## Références

- [mirror/README.md](../mirror/README.md)
- [docs/sno-ssh-convention.md](sno-ssh-convention.md)
- [docs/ansible-manual-parity.md](ansible-manual-parity.md)

# OpenShift Virtualization + LVMS — air-gap lab (SNO)

Lab notes: operators, local storage, guest ISO import.

## Prerequisites

| Component | Detail |
|-----------|--------|
| Mirror | **LVMS**-only or **virt-lvms** profile — [mirror/imageset-config-4.22-lvms.yaml.example](../mirror/imageset-config-4.22-lvms.yaml.example) |
| Cluster | `oc apply` **IDMS/ITMS** from `workspace-*/working-dir/cluster-resources/` |
| OLM catalog | After mirror: `oc delete pod -n openshift-marketplace -l olm.catalogSource=cs-redhat-operator-index-v4-22` then `oc get packagemanifest \| grep lvms` |
| LVMS | 2nd VirtIO disk on SNO VM (Proxmox) — `vda` = OCP, **`vdb`** = LVMS |
| Nested virt | CPU **host** on SNO VM — [proxmox/network.md](../proxmox/network.md) |
| `oc` | `KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig-admin` — [sno-ssh-convention.md](sno-ssh-convention.md) |

## LVMS

1. Install **`lvms-operator`** (Operator Hub or Subscription, channel **`stable-4.22`**).
2. Create **LVMCluster** (e.g. name **`lvms`**) on device **`/dev/vdb`** (prefer `/dev/disk/by-id/...`).
3. Typical StorageClass: **`lvms-vg1`** (`topolvm.io`, `WaitForFirstConsumer`).

PVC test:

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

With `WaitForFirstConsumer`, bind a consumer pod to see **Bound**.

## Operator Hub vs Software Catalog

| UI | Usage |
|----|--------|
| **Operators → Operator Hub** | **`lvms-operator`**, **`kubevirt-hyperconverged`** |
| **Software Catalog / HostPathProvisioner deployment** | CDI/HCO path, not a substitute; **404** errors are common in air-gap |

If there is no **`packagemanifest`** for the package: mirror catalog not reloaded (see catalog pod delete above).

## Guest ISO import (RHEL, etc.)

Goal: bootable PVC on **`lvms-vg1`**, not a “repo” on the bastion.

### Mac → bastion

```bash
scp /path/to/file.iso bernard@192.168.1.144:~/lab/isos/
```

### IDMS / ITMS (required)

CDI pods (`virt-cdi-uploadserver`, `virt-cdi-importer`) reference **`registry.redhat.io/...`**. Images live on **`registry.lab.local:5000/ocp4-422/container-native-virtualization/...`** after a Virt mirror — without cluster mirrors → **ImagePullBackOff** / upload timeout.

```bash
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig-admin
# Operator (CNV) mirror — do not limit yourself to the LVMS-only workspace
oc patch imagedigestmirrorset idms-operator-0 --type=json -p='[
  {"op":"add","path":"/spec/imageDigestMirrors/-","value":{"source":"registry.redhat.io/container-native-virtualization","mirrors":["registry.lab.local:5000/ocp4-422/container-native-virtualization"]}}
]' 2>/dev/null || true
oc apply -f ~/lab/4.22-ga/workspace-operators/working-dir/cluster-resources/idms-oc-mirror.yaml
# Keep lvms4 if needed: merge idms-operator-0 entries; do not re-apply the LVMS-only file afterwards (it overwrites CNV).
```

### `virtctl` (bastion)

The path **`mirror.openshift.com/.../clients/virt/virtctl`** returns **404 HTML** — do not install that (`syntax error: '<html>'`).

Align the client version with the cluster:

```bash
oc get kubevirt kubevirt -n openshift-cnv -o jsonpath='{.status.observedKubeVirtVersion}{"\n"}'
# e.g. v1.8.4

curl -L -o /tmp/virtctl \
  https://github.com/kubevirt/kubevirt/releases/download/v1.8.4/virtctl-v1.8.4-linux-amd64
file /tmp/virtctl   # ELF, not HTML
chmod +x /tmp/virtctl && sudo mv /tmp/virtctl /usr/local/bin/virtctl
```

Upload (recent `virtctl` syntax: **`pvc`** or **`dv`**, then the name — not `namespace/name`):

```bash
virtctl image-upload pvc rhel-10-2-dvd \
  --size=15Gi \
  --storage-class=lvms-vg1 \
  --image-path=$HOME/lab/isos/rhel-10.2-x86_64-dvd.iso \
  --insecure \
  --access-mode=ReadWriteOnce \
  --force-bind \
  --namespace=default
```

**Bastion — `/etc/hosts`** (home DNS does not resolve `*.apps`):

```text
172.16.10.100  cdi-uploadproxy-openshift-cnv.apps.ocp422.lab.local
172.16.10.100  console-openshift-console.apps.ocp422.lab.local
172.16.10.100  oauth-openshift.apps.ocp422.lab.local
```

**ISO > ~8 GiB — upload OOM (600M limit)**: patch **`HyperConverged`**, not the `CDI` CR alone (HCO reconciles CDI).

```bash
oc patch hyperconverged kubevirt-hyperconverged -n openshift-cnv --type=merge -p '
{
  "spec": {
    "storage": {
      "workloadResourceRequirements": {
        "limits": { "cpu": "2", "memory": "4Gi" },
        "requests": { "cpu": "100m", "memory": "512Mi" }
      }
    }
  }
}'
```

Recreate the `cdi-upload-*` pod, confirm `limits.memory` ≠ `600M`, then rerun `virtctl --no-create`.

| Symptom | Cause | Action |
|---------|-------|--------|
| Upload pod not ready | ImagePullBackOff `registry.redhat.io` | IDMS **container-native-virtualization** |
| `no such host` cdi-uploadproxy | Bastion → DNS 192.168.1.1 | `/etc/hosts` → `172.16.10.100` |
| **502** / connection refused | Pod **OOMKilled** (600M) | HCO `workloadResourceRequirements` above |

PVC already created (console or YAML):

```bash
virtctl image-upload pvc rhel-10-2-dvd \
  --no-create \
  --image-path=$HOME/lab/isos/rhel-10.2-x86_64-dvd.iso \
  --insecure \
  --namespace=default
```

Watch: `oc get pvc rhel-10-2-dvd -w`, `cdi-upload-*` pods **Running**.

Cleanup failed upload:

```bash
oc delete datavolume,pvc -n default --all   # or targeted names
oc delete pod -n default -l cdi.kubevirt.io=uploadserver --force --grace-period=0
```

### HTTP alternative (no `virtctl`)

Terminal 1:

```bash
cd ~/lab/isos && python3 -m http.server 8080 --bind 172.16.10.10
```

Terminal 2: DataVolume `spec.source.http.url` → `http://172.16.10.10:8080/file.iso`, `storageClassName: lvms-vg1`, size ≥ ISO.

### Mac console + SSH tunnel

Tunnel: `sudo ssh -L 443:172.16.10.100:443 -N bernard@192.168.1.144`

`/etc/hosts` on the **Mac** — apps FQDNs as **`127.0.0.1`** (not `172.16.10.100`):

```text
127.0.0.1  console-openshift-console.apps.ocp422.lab.local
127.0.0.1  oauth-openshift.apps.ocp422.lab.local
127.0.0.1  cdi-uploadproxy-openshift-cnv.apps.ocp422.lab.local
```

Certificate: open  
`https://cdi-uploadproxy-openshift-cnv.apps.ocp422.lab.local/v1beta1/upload-form-async`  
(**404** on `/` alone is normal), then retry the console upload.

Tunnel detail: [proxmox/access.md](../proxmox/access.md) § OpenShift console.

## Bash completions (`oc`, `virtctl`)

On bastion: **`bash-completion`** package (DVD repo if no Internet — [ansible/README.md](../ansible/README.md) § RHEL DVD), then:

```bash
oc completion bash | sudo tee /etc/bash_completion.d/oc
virtctl completion bash | sudo tee /etc/bash_completion.d/virtctl
```

Load **`/usr/share/bash-completion/bash_completion`** in `~/.bashrc` **before** any manual source of `/etc/bash_completion.d/oc` (avoids `_get_comp_words_by_ref: command not found`).

## References

- [mirror/README.md](../mirror/README.md)
- [sno-ssh-convention.md](sno-ssh-convention.md)
- [docs/iac.md](iac.md)

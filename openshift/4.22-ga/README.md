# OpenShift 4.22 GA — agent-based air-gap (SNO or compact3)


| Parameter    | Value                                                                                                                                       |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Version      | **4.22.12**                                                                                                                                 |
| Cluster name | `ocp422`                                                                                                                                    |
| Base domain  | `lab.local` → API `api.ocp422.lab.local`                                                                                                    |
| Topology     | `ocp_topology`: **sno** (`.100`, `platform: none`) or **compact3** (`.100`–`.102`, `platform: baremetal`, API VIP `.50`, ingress VIP `.49`) |
| Mirror       | `registry.lab.local:5000/ocp4-422`                                                                                                          |


**Do not** set `baseDomain: ocp422.lab.local` (double subdomain → `api.ocp422.ocp422.lab.local`).

## Recommended order

1. Terraform + `lab-infra.yml`
2. `**bastion-ocp-install.yml**` with ISO generate + upload to Proxmox (configs do not need the mirror yet)
3. `**oc-mirror**` — [mirror/README.md](../../mirror/README.md)
4. Verify mirror, **then** boot the SNO (this doc from §3)

Do **not** start the SNO until the mirror is OK — the ISO only embeds URLs/CA; image blobs come from `oc-mirror`.

Install YAML on bastion: `~/lab/4.22-ga/config-backup/`. Prefer Ansible over hand-editing `.example` files.

## 1. Agent ISO via Ansible (preferred)

**Mac** — in `ansible/inventory/group_vars/all.yml`:

```yaml
ocp_topology: compact3   # or sno — match terraform/lab-ocp
ocp_agent_generate_iso: true
ocp_push_iso_to_proxmox: true
```

Prerequisite for push: Mac can SSH `root@192.168.1.147`. Ansible places the bastion pubkey on Proxmox (`lab-infra` role bastion / before ISO scp).

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/bastion-ocp-install.yml
```

Details: [docs/ansible-ocp-install.md](../../docs/ansible-ocp-install.md).

### Fallback — ISO by hand on bastion

Only if the flags above were `false`. `create image` **deletes** work-dir YAML — restore from `config-backup/`. On reinstall, also remove stale `auth/` (old kubeconfig CA):

```bash
cd ~/lab/4.22-ga
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
rm -rf .openshift_install_state.json agent.x86_64.iso cluster-manifests auth

openshift-install agent create cluster-manifests --dir .
openshift-install agent create image --dir . --log-level info

cp config-backup/install-config.yaml config-backup/agent-config.yaml .
scp ~/lab/4.22-ga/agent.x86_64.iso \
  root@192.168.1.147:/mnt/pve/nfs_iso/template/iso/
```

## 2. Mirror (after ISO is ready)

On bastion — [mirror/README.md](../../mirror/README.md). Then:

```bash
~/lab/scripts/verify-mirror-before-sno.sh ~/lab/4.22-ga
~/lab/scripts/lab-startup-check.sh
```

Fix any `[FAIL]` before booting.

## 3. Create / boot SNO (Proxmox)

**Host:** Mac — Terraform; then Proxmox UI / console if needed.


| Setting         | Value                                                                     |
| --------------- | ------------------------------------------------------------------------- |
| Disk            | 120 GiB **VirtIO** → `rootDeviceHints` **by-path** (see agent-config)     |
| NIC             | `vmbr1`, VirtIO — MAC `**bc:24:11:e1:8f:82**` (`sno_mac` / `ocp_sno_mac`) |
| CD-ROM          | `nfs_iso` → `agent.x86_64.iso` on **ide2**                                |
| LVMS (optional) | 2nd VirtIO disk → `/dev/vdb`                                              |


In `terraform/lab-ocp/terraform.tfvars`: `ocp_topology = "sno"` (see `terraform.tfvars.sno.example`).

Create / apply:

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
terraform apply -auto-approve
```

Retry (recreate VM):

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/terraform/lab-ocp
terraform apply -replace='proxmox_vm_qemu.node["sno"]' -auto-approve
```

Also documented in [terraform/lab-ocp/README.md](../../terraform/lab-ocp/README.md).

## 4. Wait for install

**Host:** bastion — `bernard@192.168.1.144`

Restore configs and refresh manifests first (avoids `panic: AgentHosts is nil` when `.openshift_install_state.json` is stale after ISO generation):

```bash
cd ~/lab/4.22-ga
cp config-backup/install-config.yaml config-backup/agent-config.yaml .
rm -f .openshift_install_state.json
openshift-install agent create cluster-manifests --dir .
openshift-install agent wait-for install-complete --dir . --log-level info
```

Typical duration: **~30 min** with mirror already present.

`wait-for` may **timeout on TLS** while the cluster is already up. Confirm:

```bash
curl -k https://api.ocp422.lab.local:6443/healthz   # → ok
```

Success = `oc login` + node **Ready** + ClusterOperators **Available**.

### Watch from SNO (optional)

SSH **from bastion only** — [proxmox/access.md](../../proxmox/access.md) § OpenShift node SSH:

```bash
ssh-keygen -R 172.16.10.100   # after each reinstall
ssh core@172.16.10.100
sudo journalctl -u assisted-service -f
# later:
sudo journalctl -u bootkube -f
```

## 5. After install — `oc` and console

**Bastion:**

```bash
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig
oc get nodes
oc get clusteroperators
oc get co
```

Password (if needed): `cat ~/lab/4.22-ga/auth/kubeadmin-password`  
Console URL: `https://console-openshift-console.apps.ocp422.lab.local`

### Web console from the Mac

Forward ingress (`.49`) and API (`.50`) through the bastion, then open the console in the browser:

```bash
sudo ssh -L 443:172.16.10.49:443 -L 6443:172.16.10.50:6443 -N bernard@192.168.1.144
```

## Day-2 — local Operator catalog (Virt / LVMS)

After the cluster is **Ready** and `oc-mirror` has populated `~/lab/4.22-ga/workspace/`.  
Resources live under `~/lab/4.22-ga/workspace/working-dir/cluster-resources/` (typical files: `idms-oc-mirror.yaml`, `itms-oc-mirror.yaml`, `cs-redhat-operator-index-v4-22.yaml`, `cc-redhat-operator-index-v4-22.yaml`, `signature-configmap.yaml`, `updateService.yaml`).

### Preferred — Ansible day-2 playbook

Automates §1–3, registry CA (§5a), and OSUS through ClusterVersion upstream (§5b–5e). Does **not** start `oc adm upgrade --to=…` (manual). LVMS/Virt install stays optional (UI or `-e`). Guest boot sources (§6): `-e ocp_day2_guest_boots=true` — [docs/openshift-virt-lab.md](../../docs/openshift-virt-lab.md).

**Mac:**

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/bastion-ocp-day2.yml
# Skip OSUS:     -e ocp_day2_osus=false
# Also LVMS sub: -e ocp_day2_install_lvms=true
# Tags only:     --tags mirrors,catalog
```

Role: [ansible/roles/ocp_day2/](../../ansible/roles/ocp_day2/). Manual steps below remain the reference if you prefer UI / step-by-step.

```bash
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig
```

If `oc` fails with `x509` / `kube-apiserver-lb-signer` after a **reinstall**, replace the stale file from a master (Ansible now wipes `auth/` on the next ISO gen):

```bash
ssh core@172.16.10.100 \
  'sudo cat /etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/lb-ext.kubeconfig' \
  > ~/lab/4.22-ga/auth/kubeconfig
chmod 600 ~/lab/4.22-ga/auth/kubeconfig
```

### 1. Disable default OperatorHub sources

Default catalogs pull from the Internet → `ImagePullBackOff` in air-gap:

```bash
oc patch OperatorHub cluster --type json \
  -p '[{"op":"add","path":"/spec/disableAllDefaultSources","value":true}]'

oc get catalogsource -n openshift-marketplace
oc get operatorhub cluster -o jsonpath='{.spec.disableAllDefaultSources}{"\n"}'
```

Expect `true` and no Ready `redhat-operators` / `certified-operators` / `community-operators` / `redhat-marketplace`.

### 2. Image mirrors (IDMS / ITMS)

Platform ICS in the ISO is not enough for operators:

```bash
oc apply -f ~/lab/4.22-ga/workspace/working-dir/cluster-resources/idms-oc-mirror.yaml
oc apply -f ~/lab/4.22-ga/workspace/working-dir/cluster-resources/itms-oc-mirror.yaml

oc get imagedigestmirrorset
oc get imagetagmirrorset
```

### 3. CatalogSource from the mirror

```bash
oc apply -f ~/lab/4.22-ga/workspace/working-dir/cluster-resources/cs-redhat-operator-index-v4-22.yaml
oc apply -f ~/lab/4.22-ga/workspace/working-dir/cluster-resources/cc-redhat-operator-index-v4-22.yaml
oc apply -f ~/lab/4.22-ga/workspace/working-dir/cluster-resources/signature-configmap.yaml
```

Check (refresh the catalog pod if packagemanifests are empty):

```bash
oc get catalogsource -n openshift-marketplace
oc delete pod -n openshift-marketplace -l olm.catalogSource=cs-redhat-operator-index-v4-22 --wait=false
oc get packagemanifest -n openshift-marketplace | grep -iE 'lvms|kubevirt|hyperconverged|cincinnati|update'
```

### 4. Install LVMS then OpenShift Virtualization

Order: **LVMS first**, then Virt. Source must be the **local** catalog `cs-redhat-operator-index-v4-22` (not `redhat-operators`).

**UI (console)** — tunnel from the Mac if needed (§5 above), then **Operators → OperatorHub**:

1. **LVMS Operator** (`lvms-operator`) → Install → namespace `openshift-storage`, channel `stable-4.22`, version pinned to the mirrored CSV (e.g. `4.22.0`).
2. **OpenShift Virtualization** (`kubevirt-hyperconverged`) → Install → namespace `openshift-cnv`, channel `stable`, version from the mirror (e.g. `4.22.0` for an upgrade-lab baseline).

**CLI** — LVMS example:

```bash
oc create ns openshift-storage 2>/dev/null || true

oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-og
  namespace: openshift-storage
spec:
  targetNamespaces:
  - openshift-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: lvms-operator
  namespace: openshift-storage
spec:
  channel: stable-4.22
  name: lvms-operator
  source: cs-redhat-operator-index-v4-22
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
  startingCSV: lvms-operator.v4.22.0
EOF

oc get csv,sub -n openshift-storage
```

After the LVMS CSV is **Succeeded**, install Virt the same way (UI or Subscription in `openshift-cnv`, `source: cs-redhat-operator-index-v4-22`).

Then create **LVMCluster** / HyperConverged as needed — [docs/openshift-virt-lab.md](../../docs/openshift-virt-lab.md).

### 5. Air-gap updates (Cincinnati / OSUS)

Prerequisite in the imageset: `platform.graph: true`, `cincinnati-operator`, and a platform span with `shortestPath: true` (e.g. install **4.22.0**, upgrade to **4.22.12**):

```yaml
ocp_platform_version: "4.22.0"
ocp_platform_min_version: "4.22.0"
ocp_platform_max_version: "4.22.12"
ocp_mirror_shortest_path: true
```

After remirror, `cluster-resources/` should include `updateService.yaml` and `signature-configmap.yaml`.

#### 5a. Trust the local registry CA (required for OSUS)

OSUS looks for a ConfigMap key named **`updateservice-registry`**. Keep also `registry.lab.local..5000` for general cluster pulls (`:` → `..` in the key):

```bash
oc create configmap registry-config -n openshift-config \
  --from-file=registry.lab.local..5000=/home/bernard/lab/ca.crt \
  --from-file=updateservice-registry=/home/bernard/lab/ca.crt \
  --dry-run=client -o yaml | oc apply -f -

oc patch image.config.openshift.io/cluster --type=merge \
  -p '{"spec":{"additionalTrustedCA":{"name":"registry-config"}}}'

oc get image.config.openshift.io/cluster -o jsonpath='{.spec.additionalTrustedCA.name}{"\n"}'
```

#### 5b. Install OpenShift Update Service operator

**UI:** OperatorHub → **OpenShift Update Service** / `cincinnati-operator` → Install  
(namespace `openshift-update-service`, source `cs-redhat-operator-index-v4-22`, channel `v1`).

**CLI:**

```bash
oc create ns openshift-update-service 2>/dev/null || true

oc apply -f - <<'EOF'
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-update-service-og
  namespace: openshift-update-service
spec:
  targetNamespaces:
  - openshift-update-service
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: update-service-operator
  namespace: openshift-update-service
spec:
  channel: v1
  name: cincinnati-operator
  source: cs-redhat-operator-index-v4-22
  sourceNamespace: openshift-marketplace
  installPlanApproval: Automatic
EOF

oc get csv,sub -n openshift-update-service
```

#### 5c. Create UpdateService

Values come from oc-mirror (`updateService.yaml`):

| Field | Value |
|-------|--------|
| Name | `update-service-oc-mirror` |
| Graph data image | `registry.lab.local:5000/ocp4-422/openshift/graph-image:latest` |
| Releases | `registry.lab.local:5000/ocp4-422/openshift/release-images` |
| Replicas | `1` (lab) or `2` |

**UI:** Installed Operators → OpenShift Update Service → **UpdateService** → Create.

**CLI:**

```bash
oc apply -n openshift-update-service \
  -f ~/lab/4.22-ga/workspace/working-dir/cluster-resources/updateService.yaml

oc get updateservice -n openshift-update-service
oc get pods -n openshift-update-service
```

Expect `RegistryCACertFound=True` and pods Ready. If `RegistryCACertFound` complains about missing key `updateservice-registry`, fix §5a and restart pods:

```bash
oc delete pod -n openshift-update-service -l updateservice=update-service-oc-mirror
```

#### 5d. Trust the OSUS route CA (ingress) for ClusterVersion

§5a trusts the **registry**. The CVO talks to OSUS over the **apps** route (`*.apps.ocp422.lab.local`), signed by the ingress CA. Without this step you get:

`tls: failed to verify certificate: x509: certificate signed by unknown authority`

```bash
oc -n openshift-ingress-operator get secret router-ca \
  -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/ingress-ca.crt

oc create configmap trusted-ca -n openshift-config \
  --from-file=ca-bundle.crt=/tmp/ingress-ca.crt \
  --dry-run=client -o yaml | oc apply -f -

oc patch proxy/cluster --type=merge \
  -p '{"spec":{"trustedCA":{"name":"trusted-ca"}}}'
```

Wait ~2–3 minutes for the CVO to pick up the new trust bundle (it only re-queries the graph periodically).

#### 5e. Point ClusterVersion at local Cincinnati

```bash
oc get updateservice update-service-oc-mirror -n openshift-update-service \
  -o jsonpath='{.status.policyEngineURI}{"\n"}'
# → https://update-service-oc-mirror-route-openshift-update-service.apps.ocp422.lab.local

oc patch clusterversion version --type merge -p '{
  "spec": {
    "upstream": "https://update-service-oc-mirror-route-openshift-update-service.apps.ocp422.lab.local/api/upgrades_info/v1/graph"
  }
}'

oc adm upgrade
```

Expect:

```text
Recommended updates:
  VERSION     IMAGE
  4.22.12     registry.lab.local:5000/ocp4-422/openshift/release-images@sha256:…
```

If you still see `RemoteFailed` / `unknown authority`, confirm §5d then wait and re-run `oc adm upgrade`.

To apply the upgrade:

```bash
oc adm upgrade --to=4.22.12
```

Console: **Administration → Cluster Settings**.

Reference: [Updating a cluster in a disconnected environment](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/disconnected_environments/updating-a-cluster-in-a-disconnected-environment).

### 6. Guest OS boot sources (RHEL / CentOS) — not automatic

Mirrored `additionalImages` appear only in the registry. Virt default boot sources still use `registry.redhat.io` / `quay.io` → **NoDigest** / empty PVC until HyperConverged is patched.

After LVMS (`lvms-vg1` **with capacity**) + Virt:

```bash
# Mac — preferred
ansible-playbook playbooks/bastion-ocp-day2.yml -e ocp_day2_guest_boots=true --tags guest_boots
```

Lab findings (4.22):

| Pitfall | Fix |
|---------|-----|
| `Warning: unknown field dataImportCronTemplates` | Patch `hyperconvergeds.v1beta1.hco.kubevirt.io` |
| Custom DICT never created | Annotation `ssp.kubevirt.io/dict.architectures: amd64` |
| `FailedMount` / `No source digest` | ConfigMap CA in **both** `openshift-virtualization-os-images` and `openshift-cnv` |
| `NotEnoughCapacity` / LVMCluster Failed | 2nd VirtIO disk + working VG on nodes |
| fedora / centos10 ImagePullBackOff | Disable those system crons (playbook does this) |

Full detail: [docs/openshift-virt-lab.md](../../docs/openshift-virt-lab.md) § Guest OS boot sources.

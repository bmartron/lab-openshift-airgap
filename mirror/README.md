# Mirror OpenShift images (air-gap)

**Prerequisite:** Terraform + `lab-infra.yml` + **`bastion-ocp-install.yml`** already done.  
That playbook deploys `~/lab/4.22-ga/imageset-config.yaml`, CA trust, `oc-mirror`, and `~/lab/pull-secret-oc-mirror.txt`.

## Choose the imageset (before oc-mirror)

Selection is done with Ansible — **not** by editing the file by hand on the bastion.

1. **Mac** — set `ocp_imageset_profile` in `ansible/inventory/group_vars/all.yml` (see table below).
2. Re-run the playbook so `~/lab/4.22-ga/imageset-config.yaml` is regenerated:

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/bastion-ocp-install.yml
```

3. Then run `oc-mirror` on the bastion (next section).

Default in role defaults: **`virt-lvms`**.

### Imageset profiles (GA 4.22 → namespace `ocp4-422`)

| `ocp_imageset_profile` | Example in repo | Contents |
|------------------------|-----------------|----------|
| `platform-only` | [imageset-config-4.22-platform-only.yaml.example](imageset-config-4.22-platform-only.yaml.example) | OCP platform only (smallest / fastest) |
| `gitops` | [imageset-config-4.22.yaml.example](imageset-config-4.22.yaml.example) | Platform + OpenShift GitOps |
| `virt-lvms` | [imageset-config-4.22-virt-lvms.yaml.example](imageset-config-4.22-virt-lvms.yaml.example) | Platform + Virt + LVMS + update **graph** / OSUS (**lab default**) |

### Two platform versions (upgrade)

One OpenShift install dir (`~/lab/4.22-ga`). The **imageset** can span z-streams so the registry holds both releases + Cincinnati graph:

```yaml
# ansible/inventory/group_vars/all.yml
ocp_platform_version: "4.22.0"          # installer / clients (install at this version)
ocp_platform_min_version: "4.22.0"      # oc-mirror channel span
ocp_platform_max_version: "4.22.12"
# optional operator ranges for day-2 upgrades:
# ocp_virt_operator_min_version: "4.22.0"
# ocp_virt_operator_max_version: "4.22.9"
```

Defaults keep `min == max == ocp_platform_version` (single release). Example file already shows a `4.22.0`→`4.22.12` span.

Verify on bastion before mirroring: `head -40 ~/lab/4.22-ga/imageset-config.yaml`

## Run oc-mirror

**Host:** bastion — `bernard@192.168.1.144` (LAN + Internet; lab NIC reaches the registry).

```bash
cd ~/lab/4.22-ga

oc-mirror -c imageset-config.yaml \
  --workspace file://$HOME/lab/4.22-ga/workspace \
  docker://registry.lab.local:5000/ocp4-422 \
  --authfile ~/lab/pull-secret-oc-mirror.txt \
  --v2
```

Typical duration: ~7+ minutes (platform-only); longer with Virt/LVMS/operators.  
Disk on registry (`/opt/registry`): plan **≥ 120 GiB**; ~22 GiB observed for GA 4.22.12 platform.

## After mirror

```bash
~/lab/scripts/verify-mirror-before-sno.sh ~/lab/4.22-ga
```

**Next:** boot the SNO (agent ISO should already be on Proxmox from `bastion-ocp-install.yml`) — [openshift/4.22-ga/README.md](../openshift/4.22-ga/README.md) § Boot SNO.

If the ISO was not generated yet, use that guide § Agent ISO (Ansible flags or hand commands), then boot.

Day-2 Virt/LVMS: [docs/openshift-virt-lab.md](../docs/openshift-virt-lab.md).

## See also

- Rebuild path: [docs/iac.md](../docs/iac.md)
- Versions / namespaces: [docs/versions.md](../docs/versions.md)

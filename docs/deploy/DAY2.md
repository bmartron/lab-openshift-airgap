# Day 2 — Operations (official Red Hat)

**Official meaning:** *maintenance / operations — keep the software healthy after install*  
([Red Hat blog](https://www.redhat.com/en/blog/how-does-red-hat-support-day-2-operations) · [OCP Day 2 operations](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/postinstallation_configuration/day-2-operations-for-openshift-container-platform-clusters))

In this lab: disconnected catalog, OSUS/updates, LVMS, Virtualization, guest boot sources, daily care.

Prereq: cluster **Ready** ([DAY1.md](DAY1.md)) · Tips: [../faq/README.md](../faq/README.md) · Virt detail: [openshift-virt-lab.md](openshift-virt-lab.md)

---

## Order

```text
Catalog + OSUS (day-2 playbook)
    → LVMS Subscription → LVMCluster (/dev/vdb) → lvms-vg1
    → OpenShift Virtualization (HCO Ready)
    → Guest boots playbook → Catalog / Bootable volumes
    → Optional: oc adm upgrade
```

---

## Checklist — postinstallation

### 1. Catalog + OSUS (Mac)

```bash
cd /Users/bmartron/Documents/Cursor/Projet-Airgap-deploy/ansible
ansible-playbook playbooks/bastion-ocp-day2.yml
```

### 2. Verify catalog (bastion)

```bash
export KUBECONFIG=~/lab/4.22-ga/auth/kubeconfig
oc get packagemanifest -n openshift-marketplace | grep -iE 'lvms|kubevirt|cincinnati'
```

### 3. LVMS (Mac or UI)

```bash
ansible-playbook playbooks/bastion-ocp-day2.yml -e ocp_day2_install_lvms=true --tags lvms
# Then create LVMCluster on /dev/vdb (not created by Subscription alone)
oc get csv -n openshift-storage
oc get lvmcluster -A && oc get sc lvms-vg1
```

### 4. Virtualization (UI)

Install `kubevirt-hyperconverged` from local catalog → HCO Ready.

```bash
oc get csv -n openshift-cnv
oc get hyperconverged -n openshift-cnv
```

### 5. Guest boot sources (Mac)

```bash
ansible-playbook playbooks/bastion-ocp-day2.yml \
  -e ocp_day2_guest_boots=true --tags guest_boots
```

### 6. Confirm imports (bastion)

```bash
oc get dv,pvc,datasource -n openshift-virtualization-os-images
```

Console: **Bootable volumes** → project **`openshift-virtualization-os-images`** or **All Projects**.

### 7. Optional — upgrade

```bash
oc adm upgrade
oc adm upgrade --to=4.22.12
```

### 8. Daily ops

Power cycle order: [lab-power-cycle.md](lab-power-cycle.md)

---

## Done when

- `lvms-vg1` has capacity · HCO Ready  
- DataSources `rhel9` / `rhel10` / `centos-stream9` Ready  
- Golden images visible with the correct console project filter

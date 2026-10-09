# FAQ — index

Tips and pitfalls, grouped by **official Red Hat Day** stage.  
Full answers: [FAQ.md](FAQ.md) · Procedures: [../deploy/DAY0.md](../deploy/DAY0.md) · [DAY1](../deploy/DAY1.md) · [DAY2](../deploy/DAY2.md)

## Official Day meanings

| Day | Meaning | Source |
|-----|---------|--------|
| Day 0 | Design | [RH blog](https://www.redhat.com/en/blog/how-does-red-hat-support-day-2-operations) |
| Day 1 | Deployment | same |
| Day 2 | Operations / postinstallation | [OCP Day 2 docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.22/html/postinstallation_configuration/day-2-operations-for-openshift-container-platform-clusters) |

---

## Access

- [Where do I run commands?](FAQ.md#where-do-i-run-commands)
- [SSH to core@ after reinstall](FAQ.md#after-reinstall-ssh-to-core-fails)
- [After Mac reboot](FAQ.md#after-mac-reboot)
- [ProxyJump / Permission denied](FAQ.md#proxyjump--permission-denied)

## Day 0 — Design

- [Registry tar wrong arch](FAQ.md#registry-tar-platform-arm64-vs-amd64)
- [What to prepare before deploy](../deploy/DAY0.md)

## Day 1 — Deployment

- [Rendezvous host message](FAQ.md#this-host-is-not-the-rendezvous-host)
- [Which disk for agent install](FAQ.md#which-disk-does-the-agent-install-to)
- [lvms_disk_gb during install](FAQ.md#should-lvms_disk_gb-be-0-during-install)
- [oc x509 after reinstall](FAQ.md#oc-x509--wrong-ca-after-reinstall)
- [Do not boot before mirror](FAQ.md#do-not-boot-ocp-before-the-mirror)
- [DNF / rhel10-baseos / DVD](FAQ.md#dnf-no-package--rhel10-baseos)
- [Bastion default route / no Internet](FAQ.md#bastion-internet-fails-lab-registry-ok)

## Day 2 — Operations

- [Packagemanifests empty](FAQ.md#packagemanifests-empty-after-catalogsource)
- [No lvms-vg1 after Subscription](FAQ.md#subscription-installed-but-no-lvms-vg1)
- [NotEnoughCapacity](FAQ.md#guest-pvc-notenoughcapacity)
- [Bootable volumes empty in console](FAQ.md#dv-succeeded-but-catalog--bootable-volumes-empty)
- [No source digest / CDI CA](FAQ.md#no-source-digest--cdi-failedmount)
- [HyperConverged patch ignored](FAQ.md#hyperconverged-patch-ignored-dataimportcrontemplates)

## Architecture

- [Bastion dual-NIC](../architecture/bastion.md) · [Network](../architecture/network.md) · [Versions](../architecture/versions.md)
- [Why Proxmox for now (RHEL/NFS pending)](../architecture/architecture.md#why-proxmox)
- [Why OCP/registry not on NAS NFS](../architecture/architecture.md#why-not-nas-nfs)

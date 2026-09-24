# OpenShift installs

Index of install tracks. Infra + mirror are already done via Terraform / Ansible / [mirror/README.md](../mirror/README.md).

| Track | Version | Topology | Guide |
|-------|---------|----------|-------|
| **GA air-gap** | OpenShift **4.22.12** | SNO agent-based | **[4.22-ga/](4.22-ga/)** ← next after mirror |
| **RC 5 connected** | OpenShift **5.0.0-ec.x** | 3-node Assisted | [5-rc/assisted-connected/](5-rc/assisted-connected/) |
| **RC 5 air-gap** | OpenShift **5.0.0-ec.x** | agent (optional) | [5-rc/](5-rc/) |

## After mirror (GA SNO)

Configs on bastion (`~/lab/4.22-ga/`) already come from **`bastion-ocp-install.yml`**. Do **not** start from the legacy YAML examples at the root of this folder.

1. Verify: `~/lab/scripts/verify-mirror-before-sno.sh ~/lab/4.22-ga`
2. Follow **[4.22-ga/README.md](4.22-ga/)** — generate agent ISO → attach on Proxmox → boot SNO → `wait-for` / `oc login`

Regenerate install YAML / ISO via Ansible only if something changed: [docs/ansible-ocp-install.md](../docs/ansible-ocp-install.md).

## Common agent pitfalls (GA)

| Problem | Fix |
|---------|-----|
| `api.ocp422.ocp422.lab.local` | `baseDomain: lab.local` + `metadata.name: ocp422` |
| `/dev/not-found-by-hints` | `rootDeviceHints.deviceName: "/dev/disk/by-path/…"` (VirtIO; not by-id) |
| `additionalNtpServers` unknown | NTP only in `agent-config.yaml` (`additionalNTPSources`) |
| `agent-config` `apiVersion: v1` | Use **`v1beta1`** |
| Partial ISO / stale state | `rm .openshift_install_state.json` then regenerate |
| Bootstrap stuck, no bootkube | Recreate SNO via Terraform |

## See also

- Versions: [docs/versions.md](../docs/versions.md)
- Rebuild path: [docs/iac.md](../docs/iac.md)
- SSH to SNO: [docs/sno-ssh-convention.md](../docs/sno-ssh-convention.md)

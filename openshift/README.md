# OpenShift install tracks

| Track | Version | Topology | Guide |
|-------|---------|----------|--------|
| **GA air-gap** | OpenShift **4.22.12** | SNO / compact3 agent-based | [4.22-ga/](4.22-ga/) |

One install directory (`~/lab/4.22-ga`). For upgrades, the **mirror** spans two z-streams via `ocp_platform_min_version` / `ocp_platform_max_version` — see [mirror/README.md](../mirror/README.md).

Root `install-config.yaml.example` / `agent-config.yaml.example` are thin copies of the GA examples.

| Symptom | Check |
|---------|--------|
| `/dev/not-found-by-hints` | `rootDeviceHints.deviceName: "/dev/disk/by-path/…"` (VirtIO; not by-id) |
| Mirror pull fail | Mirror finished? CA + `imageContentSources` in install-config |
| Permission denied `core@` | Bastion live key in ISO — [proxmox/access.md](../proxmox/access.md) § OpenShift node SSH |

Full rebuild: [docs/deploy/iac.md](../docs/deploy/iac.md).

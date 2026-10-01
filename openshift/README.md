# OpenShift install tracks

| Track | Version | Topology | Guide |
|-------|---------|----------|--------|
| **GA air-gap** | OpenShift **4.22.12** | SNO agent-based | [4.22-ga/](4.22-ga/) |

Root `install-config.yaml.example` / `agent-config.yaml.example` are thin copies of the GA examples.

| Symptom | Check |
|---------|--------|
| `/dev/not-found-by-hints` | `rootDeviceHints.deviceName: "/dev/disk/by-path/…"` (VirtIO; not by-id) |
| Mirror pull fail | Mirror finished? CA + `imageContentSources` in install-config |
| Permission denied `core@` | Bastion live key in ISO — [proxmox/access.md](../proxmox/access.md) § OpenShift node SSH |

Full rebuild: [docs/iac.md](../docs/iac.md).

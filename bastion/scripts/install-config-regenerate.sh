#!/usr/bin/env bash
# Reconstruit un install-config.yaml GA 4.22 air-gap (YAML propre).
# Machine : bastion 192.168.1.144
# Usage : install-config-regenerate.sh [destination.yaml]
# Prérequis : ~/lab/ca.crt, ~/lab/pull-secret.txt, clé SSH (argument ou ancien install-config)

set -euo pipefail

OUT="${1:-$HOME/lab/4.22-ga/config-backup/install-config.yaml}"
CA="${CA:-$HOME/lab/ca.crt}"
PS="${PS:-$HOME/lab/pull-secret.txt}"
OLD="${OLD:-$HOME/lab/4.22-ga/config-backup/install-config.yaml}"
SSH_KEY_FILE="${SSH_KEY_FILE:-}"

if [[ ! -f "$CA" ]]; then echo "Manquant : $CA" >&2; exit 1; fi
if [[ ! -f "$PS" ]]; then echo "Manquant : $PS" >&2; exit 1; fi

if [[ -f "$OUT" ]]; then
  cp -a "$OUT" "${OUT}.bak.regen.$(date +%Y%m%d%H%M%S)"
fi

export OUT CA PS OLD SSH_KEY_FILE
python3 << 'PY'
import json
import os
import re
import sys
from pathlib import Path

out = Path(os.environ["OUT"])
ca = Path(os.environ["CA"]).read_text().strip()
ps = json.dumps(json.loads(Path(os.environ["PS"]).read_text()), separators=(",", ":"))
old_path = Path(os.environ["OLD"])
ssh_key_file = os.environ.get("SSH_KEY_FILE") or ""

def extract_ssh_key(text: str) -> str:
    m = re.search(
        r"(ssh-(?:ed25519|rsa)\s+[A-Za-z0-9+/]+=*(?:\s+[^\s'\"\n]+)?)",
        text,
    )
    if m:
        return m.group(1).strip()
    return ""

ssh_key = ""
if ssh_key_file and Path(ssh_key_file).is_file():
    ssh_key = Path(ssh_key_file).read_text().strip()
elif old_path.is_file():
    ssh_key = extract_ssh_key(old_path.read_text())

if not ssh_key:
    for candidate in (
        Path.home() / ".ssh/id_ed25519.pub",
        Path.home() / ".ssh/id_rsa.pub",
    ):
        if candidate.is_file():
            ssh_key = candidate.read_text().strip()
            break

if not ssh_key:
    sys.exit(
        "Clé SSH introuvable. Exporter : SSH_KEY_FILE=~/.ssh/id_ed25519.pub "
        "ou mettre sshKey dans l'ancien install-config."
    )

indented_ca = "\n".join("  " + line for line in ca.splitlines())
pull_escaped = ps.replace("'", "''")
ssh_escaped = ssh_key.replace("'", "''")

body = f"""apiVersion: v1
baseDomain: lab.local
metadata:
  name: ocp422
compute:
- name: worker
  replicas: 0
controlPlane:
  name: master
  replicas: 1
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 172.16.10.0/24
  networkType: OVNKubernetes
additionalTrustBundle: |
{indented_ca}
imageContentSources:
- source: quay.io/openshift-release-dev/ocp-release
  mirrors:
  - registry.lab.local:5000/ocp4-422/openshift/release-images
- source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
  mirrors:
  - registry.lab.local:5000/ocp4-422/openshift/release
platform:
  none: {{}}
pullSecret: '{pull_escaped}'
sshKey: '{ssh_escaped}'
"""

out.write_text(body)
print(f"OK : install-config régénéré → {out}")
PY

python3 -c "import yaml; yaml.safe_load(open('${OUT}')); print('YAML OK')"

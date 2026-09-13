#!/usr/bin/env bash
# Réécrit pullSecret sur une seule ligne depuis ~/lab/pull-secret.txt
# Machine : bastion 192.168.1.144
# Usage : install-config-fix-pullsecret.sh [install-config.yaml] [pull-secret.txt]

set -euo pipefail

IC="${1:-$HOME/lab/4.22-ga/config-backup/install-config.yaml}"
PS="${2:-$HOME/lab/pull-secret.txt}"

if [[ ! -f "$PS" ]]; then
  echo "pull-secret introuvable : $PS" >&2
  exit 1
fi
if [[ ! -f "$IC" ]]; then
  echo "install-config introuvable : $IC" >&2
  exit 1
fi

cp -a "$IC" "${IC}.bak.pullsecret.$(date +%Y%m%d%H%M%S)"

python3 << PY
import json
import sys
from pathlib import Path

ic_path = Path("${IC}")
ps_path = Path("${PS}")
text = ic_path.read_text().splitlines()
try:
    secret = json.dumps(json.loads(ps_path.read_text()), separators=(",", ":"))
except json.JSONDecodeError as e:
    sys.exit(f"pull-secret.txt JSON invalide : {e}")

def is_toplevel_key(line: str) -> bool:
    s = line.strip()
    if not s or s.startswith("#"):
        return False
    if line.startswith((" ", "\t")):
        return False
    return ":" in line

out: list[str] = []
i = 0
while i < len(text):
    line = text[i]
    if line.startswith("pullSecret:"):
        out.append("pullSecret: '" + secret.replace("'", "''") + "'")
        i += 1
        while i < len(text) and not is_toplevel_key(text[i]):
            i += 1
        continue
    out.append(line)
    i += 1

if not any(l.startswith("pullSecret:") for l in out):
    sys.exit("pullSecret: absent dans install-config — ajouter avant sshKey")

ic_path.write_text("\n".join(out) + "\n")
print(f"OK : pullSecret réécrit (1 ligne) dans {ic_path}")
PY

python3 -c "import yaml; yaml.safe_load(open('${IC}')); print('YAML OK')"

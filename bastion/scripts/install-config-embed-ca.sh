#!/usr/bin/env bash
# Injecte ~/lab/ca.crt dans additionalTrustBundle (indentation YAML correcte).
# Machine : bastion 192.168.1.144
# Usage : install-config-embed-ca.sh [install-config.yaml] [ca.crt]

set -euo pipefail

IC="${1:-$HOME/lab/4.22-ga/config-backup/install-config.yaml}"
CA="${2:-$HOME/lab/ca.crt}"

if [[ ! -f "$CA" ]]; then
  echo "CA introuvable : $CA" >&2
  exit 1
fi
if [[ ! -f "$IC" ]]; then
  echo "install-config introuvable : $IC" >&2
  exit 1
fi

cp -a "$IC" "${IC}.bak.$(date +%Y%m%d%H%M%S)"

python3 << PY
import re
import sys
from pathlib import Path

ic_path = Path("${IC}")
ca_path = Path("${CA}")
text = ic_path.read_text()
ca = ca_path.read_text().strip()
if "BEGIN CERTIFICATE" not in ca:
    sys.exit("ca.crt ne ressemble pas à un PEM")

indented = "\n".join("  " + line for line in ca.splitlines())
block = f"additionalTrustBundle: |\n{indented}\n"

pat = r"additionalTrustBundle:\s*\|?\n(?:[ \t]+[^\n]*\n)*"
if re.search(pat, text):
    new_text = re.sub(pat, block, text, count=1)
else:
    marker = "imageContentSources:"
    if marker not in text:
        sys.exit("imageContentSources: absent — éditer le fichier manuellement")
    new_text = text.replace(marker, block + marker, 1)

ic_path.write_text(new_text)
print(f"OK : CA injectée dans {ic_path}")
PY

if python3 -c "import yaml; yaml.safe_load(open('${IC}'))" 2>/dev/null; then
  echo "OK : YAML valide (parse Python)"
else
  echo "ATTENTION : YAML invalide — souvent pullSecret multi-lignes. Sur la bastion :" >&2
  echo "  ~/lab/scripts/install-config-fix-pullsecret.sh ${IC}" >&2
  exit 1
fi

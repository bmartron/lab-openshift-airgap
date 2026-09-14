#!/usr/bin/env bash
# Fichier d'auth pour oc-mirror (rebuild catalogue) — bastion 192.168.1.144
#
# Ne pas utiliser ~/lab/pull-secret.txt tel quel après merge air-gap :
# - les clés avec chemin (…/release-images) ne sont pas du docker config valide
# - auth "Og==" (registry sans login) casse config.Load → invalid auth configuration file
#
# Usage : pull-secret-for-oc-mirror.sh [pull-secret.txt] [sortie]
# Sortie par défaut : ~/lab/pull-secret-oc-mirror.txt

set -euo pipefail

SRC="${1:-$HOME/lab/pull-secret.txt}"
DST="${2:-$HOME/lab/pull-secret-oc-mirror.txt}"

if [[ ! -f "$SRC" ]]; then
  echo "Fichier introuvable : $SRC" >&2
  exit 1
fi

python3 << PY
import base64
import json
import sys
from pathlib import Path

src = Path("${SRC}").expanduser()
dst = Path("${DST}").expanduser()
rh_hosts = (
    "cloud.openshift.com",
    "quay.io",
    "registry.connect.redhat.com",
    "registry.redhat.io",
)
ps = json.loads(src.read_text())
all_auths = ps.get("auths") or {}
out = {}
for host in rh_hosts:
    if host not in all_auths:
        continue
    entry = all_auths[host]
    if not isinstance(entry, dict) or "auth" not in entry:
        print(f"SKIP {host}: pas de champ auth", file=sys.stderr)
        continue
    try:
        raw = base64.b64decode(entry["auth"], validate=True).decode("utf-8", errors="replace")
    except Exception as e:
        print(f"SKIP {host}: auth base64 invalide ({e})", file=sys.stderr)
        continue
    if ":" not in raw or raw.split(":", 1)[0] == "":
        print(f"SKIP {host}: username vide (docker config v25+)", file=sys.stderr)
        continue
    out[host] = entry

if len(out) < 4:
    print(
        f"ERREUR: seulement {len(out)}/4 registres Red Hat — retélécharger pull-secret depuis console.redhat.com",
        file=sys.stderr,
    )
    sys.exit(1)

dst.write_text(json.dumps({"auths": out}, separators=(",", ":")) + "\n")
dst.chmod(0o600)
print(f"OK {dst} ({len(out)} entrées Red Hat, sans registry lab)")
PY

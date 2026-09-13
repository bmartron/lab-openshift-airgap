#!/usr/bin/env bash
# Vérifie registry + mirror OCP avant install SNO (bastion 172.16.10.10 ou 192.168.1.144).
# Le SNO échoue souvent sur quay.io si install-config (ISO) sans imageContentSources + CA.
# Usage : ~/lab/scripts/verify-mirror-before-sno.sh [répertoire install, ex. ~/lab/4.22-ga]

set -u

INSTALL_DIR="${1:-$HOME/lab/4.22-ga}"
LAB_DIR="${LAB_DIR:-$HOME/lab}"
CA_CERT="${CA_CERT:-$LAB_DIR/ca.crt}"
DNS_IP="${DNS_IP:-172.16.10.11}"
REGISTRY_HOST="${REGISTRY_HOST:-registry.lab.local}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
OCP_MIRROR_NS="${OCP_MIRROR_NS:-ocp4-422}"
OCP_RELEASE="${OCP_RELEASE:-4.22.12-x86_64}"

PASS=0
FAIL=0
ok() { echo "[OK]   $*"; PASS=$((PASS + 1)); }
bad() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }
info() { echo "[INFO] $*"; }

RELEASE_IMAGE="${REGISTRY_HOST}:${REGISTRY_PORT}/${OCP_MIRROR_NS}/openshift/release-images:${OCP_RELEASE}"

info "Répertoire install : ${INSTALL_DIR}"
info "Release attendue   : ${RELEASE_IMAGE}"
echo

# --- DNS comme le SNO (agent-config → 172.16.10.11) ---
if command -v dig >/dev/null 2>&1; then
  reg_ip=$(dig +short @"${DNS_IP}" "${REGISTRY_HOST}" 2>/dev/null | head -1)
  if [[ -n "$reg_ip" ]]; then
    ok "DNS @${DNS_IP} : ${REGISTRY_HOST} -> ${reg_ip}"
  else
    bad "DNS @${DNS_IP} : ${REGISTRY_HOST} ne résout pas — le SNO ne trouvera pas le mirror"
  fi
else
  bad "dig absent"
fi

# --- CA bastion ---
if [[ -f "$CA_CERT" ]]; then
  ok "CA présente : ${CA_CERT}"
else
  bad "CA absente : ${CA_CERT} (scp depuis registry /opt/registry/certs/ca.crt)"
fi

# --- Release miroir (même test que l'installateur) ---
if command -v oc >/dev/null 2>&1; then
  if [[ -f "$CA_CERT" ]]; then
    if oc adm release info "$RELEASE_IMAGE" --registry-config="$LAB_DIR/pull-secret.txt" 2>/dev/null | head -5 | grep -q .; then
      ok "oc adm release info sur le mirror (avec pull-secret)"
    else
      if oc adm release info "$RELEASE_IMAGE" --insecure-skip-tls-verify=true 2>/dev/null | head -5 | grep -q .; then
        ok "oc adm release info (insecure) — préférer additionalTrustBundle dans install-config"
      else
        bad "oc adm release info échoue — mirror absent ou mauvais chemin/tag (${OCP_RELEASE})"
        info "Essayer : oc adm release info ${RELEASE_IMAGE} --insecure-skip-tls-verify=true"
      fi
    fi
  else
    bad "Skip oc adm release info (pas de CA)"
  fi
else
  bad "oc absent sur la bastion"
fi

echo
info "--- install-config (ISO) : config-backup/install-config.yaml ---"
IC="${INSTALL_DIR}/config-backup/install-config.yaml"
if [[ ! -f "$IC" ]]; then
  bad "Fichier absent : ${IC}"
else
  ok "Fichier présent : ${IC}"
  if grep -q 'imageContentSources:' "$IC" && grep -q 'ocp4-422/openshift/release' "$IC"; then
    ok "imageContentSources → ocp4-422"
  else
    bad "imageContentSources manquant ou chemin ocp4-422 absent — l'ISO tirera quay.io"
  fi
  if grep -q 'additionalTrustBundle:' "$IC" && grep -q 'BEGIN CERTIFICATE' "$IC"; then
    ok "additionalTrustBundle (CA registry) présent"
  else
    bad "additionalTrustBundle absent ou vide — échec TLS vers registry.lab.local"
  fi
  if grep -q 'pullSecret:' "$IC"; then
    ok "pullSecret présent (vérifier fusion Red Hat + registry.lab.local)"
  else
    bad "pullSecret absent"
  fi
fi

ITMS="${INSTALL_DIR}/workspace/working-dir/cluster-resources/itms-oc-mirror.yaml"
if [[ -f "$ITMS" ]]; then
  info "Comparer manuellement avec : grep -A2 mirrors ${ITMS}"
else
  info "ITMS absent (${ITMS}) — chemins par défaut ocp4-422/openshift/release*"
fi

echo
info "Résumé : ${PASS} OK, ${FAIL} FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo
  echo "=> Corriger config-backup/install-config.yaml puis régénérer l'ISO :"
  echo "   cd ${INSTALL_DIR}"
  echo "   cp config-backup/install-config.yaml config-backup/agent-config.yaml ."
  echo "   rm -f .openshift_install_state.json agent.x86_64.iso"
  echo "   openshift-install agent create cluster-manifests --dir ."
  echo "   openshift-install agent create image --dir ."
  echo "   cp config-backup/install-config.yaml config-backup/agent-config.yaml ."
  echo "   Doc : openshift/4.22-ga/README.md"
  exit 1
fi
echo "=> Prérequis mirror + install-config OK. Si le SNO échoue encore : wipe disque + nouvelle ISO."
exit 0

#!/usr/bin/env bash
# Contrôle des prérequis lab avant démarrage (ou boot) du SNO.
# Où l'exécuter : bastion 172.16.10.10
# Doc : docs/lab-power-cycle.md

set -u

LAB_DIR="${LAB_DIR:-$HOME/lab}"
VERSIONS_FILE="${VERSIONS_FILE:-$LAB_DIR/versions.env}"
CA_CERT="${CA_CERT:-$LAB_DIR/ca.crt}"

# Défauts alignés sur versions.env.example
DNS_IP="${DNS_IP:-172.16.10.11}"
REGISTRY_IP="${REGISTRY_IP:-172.16.10.20}"
BASTION_IP="${BASTION_IP:-172.16.10.10}"
SNO_IP="${SNO_IP:-172.16.10.100}"
REGISTRY_HOST="${REGISTRY_HOST:-registry.lab.local}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
API_FQDN="${API_FQDN:-api.ocp422.lab.local}"
OCP_MIRROR_NS="${OCP_MIRROR_NS:-ocp4-422}"

if [[ -f "$VERSIONS_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$VERSIONS_FILE"
fi

PASS=0
FAIL=0

ok() { echo "[OK]   $*"; PASS=$((PASS + 1)); }
bad() { echo "[FAIL] $*"; FAIL=$((FAIL + 1)); }
info() { echo "[INFO] $*"; }

info "Bastion $(hostname -f) — contrôle prérequis SNO (ne pas démarrer le SNO si FAIL)"
info "DNS=${DNS_IP} Registry=${REGISTRY_IP} SNO=${SNO_IP}"
echo

# --- NTP / horloge bastion ---
if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
  ok "Bastion : NTP synchronisé (timedatectl)"
else
  bad "Bastion : NTP non synchronisé — configurer chrony vers ${DNS_IP} (voir dns/README.md)"
fi

if command -v chronyc >/dev/null 2>&1; then
  if chronyc -h "${DNS_IP}" tracking >/dev/null 2>&1; then
    ok "NTP : chrony joignable sur DNS ${DNS_IP}"
  else
    bad "NTP : impossible d'interroger chrony sur ${DNS_IP} (chronyd / firewall ntp ?)"
  fi
else
  info "chronyc absent — skip sonde NTP vers DNS"
fi

info "Heure bastion : $(date -Is)"
echo

# --- Réseau lab ---
if ping -c 1 -W 2 "${DNS_IP}" >/dev/null 2>&1; then
  ok "Ping DNS ${DNS_IP}"
else
  bad "Ping DNS ${DNS_IP} — démarrer la VM dns sur Proxmox"
fi

if ping -c 1 -W 2 "${REGISTRY_IP}" >/dev/null 2>&1; then
  ok "Ping registry ${REGISTRY_IP}"
else
  bad "Ping registry ${REGISTRY_IP} — démarrer la VM registry"
fi

echo

# --- DNS lab ---
if command -v dig >/dev/null 2>&1; then
  reg_ip=$(dig +short @"${DNS_IP}" "${REGISTRY_HOST}" 2>/dev/null | head -1)
  api_ip=$(dig +short @"${DNS_IP}" "${API_FQDN}" 2>/dev/null | head -1)
  if [[ "$reg_ip" == "${REGISTRY_IP}" ]]; then
    ok "DNS : ${REGISTRY_HOST} -> ${reg_ip}"
  else
    bad "DNS : ${REGISTRY_HOST} via @${DNS_IP} (attendu ${REGISTRY_IP}, reçu ${reg_ip:-vide}) — dnsmasq ?"
  fi
  if [[ "$api_ip" == "${SNO_IP}" ]]; then
    ok "DNS : ${API_FQDN} -> ${api_ip}"
  else
    bad "DNS : ${API_FQDN} via @${DNS_IP} (attendu ${SNO_IP}, reçu ${api_ip:-vide})"
  fi
else
  bad "dig non installé sur la bastion"
fi

echo

# --- Registry HTTPS ---
catalog_url="https://${REGISTRY_HOST}:${REGISTRY_PORT}/v2/_catalog"
if [[ -f "$CA_CERT" ]]; then
  code=$(curl -s --cacert "$CA_CERT" -o /dev/null -w "%{http_code}" --connect-timeout 5 "$catalog_url" || echo "000")
else
  code=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 5 "$catalog_url" || echo "000")
  info "CA absente ($CA_CERT) — curl registry en -k"
fi

if [[ "$code" == "200" ]]; then
  ok "Registry HTTPS ${REGISTRY_HOST}:${REGISTRY_PORT} (_catalog HTTP 200)"
  if [[ -f "$CA_CERT" ]]; then
    repos=$(curl -s --cacert "$CA_CERT" "$catalog_url" | grep -c release || true)
    info "Registry : au moins des repos release présents (grep ~${repos})"
  fi
else
  bad "Registry HTTPS code ${code} — sur registry ${REGISTRY_IP} : sudo podman start ocp-registry"
fi

echo

# --- SNO (optionnel : déjà démarré) ---
if ping -c 1 -W 2 "${SNO_IP}" >/dev/null 2>&1; then
  ok "Ping SNO ${SNO_IP} (VM déjà up)"
  hz=$(curl -k -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "https://${SNO_IP}:6443/healthz" || echo "000")
  if [[ "$hz" == "200" ]]; then
    ok "API SNO healthz HTTP 200"
  else
    info "API healthz HTTP ${hz} — boot en cours ou kube-apiserver pas prêt"
  fi
else
  info "SNO ${SNO_IP} ne répond pas au ping — normal si VM pas encore démarrée"
fi

echo
info "Résumé : ${PASS} OK, ${FAIL} FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo
  echo "=> Corriger les FAIL avant de démarrer le SNO sur Proxmox (192.168.1.147)."
  echo "   Ordre : DNS -> registry (podman) -> bastion -> SNO"
  exit 1
fi

echo "=> Prérequis OK. Vous pouvez démarrer (ou laisser finir le boot) du SNO ${SNO_IP}."
exit 0

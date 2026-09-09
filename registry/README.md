# Mirror Registry

Registry local pour l'installation air-gap d'OpenShift.

## Prérequis VM

- OS : RHEL 9 ou Rocky/Alma 9
- IP : `172.16.10.20` sur `vmbr-lab`
- Disque : 120–200 Go (NFS via Proxmox)
- Hostname : `registry.lab.local`

## Déploiement rapide (registry:2 + TLS)

```bash
# Sur la VM registry
mkdir -p /opt/registry/{data,certs,auth}

# Générer une CA et un certificat (lab uniquement)
openssl req -newkey rsa:4096 -nodes -sha256 -keyout certs/ca.key -x509 -days 3650 -out certs/ca.crt -subj "/CN=Lab CA"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout certs/registry.key -out certs/registry.csr -subj "/CN=registry.lab.local"
openssl x509 -req -days 3650 -sha256 -in certs/registry.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/registry.crt

# Démarrer (voir docker-compose.yml.example)
docker compose up -d
```

## Vérification depuis la bastion (réseau lab)

```bash
curl --cacert /path/to/ca.crt https://registry.lab.local:5000/v2/_catalog
```

## Certificat dans install-config

Copier le contenu de `ca.crt` dans `additionalTrustBundle` de `install-config.yaml`.

Le fichier `ca.crt` peut être commité (certificat lab auto-signé). **Ne pas** committer `ca.key` ni `registry.key`.

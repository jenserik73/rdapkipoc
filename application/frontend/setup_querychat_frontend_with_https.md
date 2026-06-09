# QueryChat — Oppsett på OKE med HTTPS

## Arkitektur

```
Bruker (HTTPS)
    │
    ▼
GoDaddy DNS (querychat.elcarocloud.no → 158.179.57.162)
    │
    ▼
OCI Load Balancer (load-balancers-subnet · port 80/443)
    │
    ▼
ingress-nginx (TLS-terminering · cert-manager · Let's Encrypt)
    │
    ├── / → querychat-pod (nginx · index.html · rå JSON debug)
    └── /chat → querychat-pod (nginx · querychat.html · fullverdig UI)
    │
    ▼
OCI API Gateway (api.elcarocloud.no · CORS · rate limit 10 req/s)
    │
    ▼
sql-executor (OCI Functions · Python · Resource Principal)
    │
    ├── OCI Vault (wallet · secrets)
    └── Autonomous Database (ADB · port 1522)

Terraform styrer: OKE · cert-manager · ingress-nginx · godaddy-webhook · ClusterIssuer · OCIR secret
OCIR: ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat
```

---

## Forutsetninger

- OKE-cluster konfigurert i Terraform
- OCIR-tilgang med auth token
- GoDaddy API-nøkkel (regenerer jevnlig)
- `kubectl`, `helm`, `docker` tilgjengelig i Codespace
- Codespaces secrets: `TF_VAR_GODADDY_API_KEY`, `TF_VAR_GODADDY_API_SECRET`, `TF_VAR_OCIR_PASSWORD`

---

## Steg 1 — Bygg og push Docker-image

```bash
# Logg inn på Sovereign Cloud OCIR (gjøres som sudo)
sudo docker login ocir.eu-frankfurt-2.oci.oraclecloud.eu \
  --username 'axpqbvkhoxdj/<din-epost>'

# Bygg og push
sudo docker build -t ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest .
sudo docker push ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest
```

> **Tips:** Docker login med sudo bruker root sin konfigurasjon — du må logge inn separat med og uten sudo.

---

## Steg 2 — Koble kubectl til OKE

```bash
oci ce cluster create-kubeconfig \
  --cluster-id ocid1.cluster.oc19.eu-frankfurt-2.aaaaaaaacjtgtlnbpodzvnblfl5joj3dy6hcmqavrfvidptg2cburyzxciiq \
  --file ~/.kube/config \
  --region eu-frankfurt-2 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT

# Verifiser
kubectl get nodes
```

---

## Steg 3 — Terraform (infrastruktur)

Terraform håndterer: cert-manager, ingress-nginx, godaddy-webhook, ClusterIssuer, OCIR pull secret.

```bash
cd /workspaces/rdapkipoc/terraform/infra

# Verifiser at secrets er tilgjengelige
echo "GODADDY_API_KEY: ${TF_VAR_GODADDY_API_KEY:+satt}${TF_VAR_GODADDY_API_KEY:-MANGLER}"
echo "GODADDY_API_SECRET: ${TF_VAR_GODADDY_API_SECRET:+satt}${TF_VAR_GODADDY_API_SECRET:-MANGLER}"
echo "OCIR_PASSWORD: ${TF_VAR_OCIR_PASSWORD:+satt}${TF_VAR_OCIR_PASSWORD:-MANGLER}"

terraform init

# Steg 1: Helm-releases og secrets (CRDs må være klare før ClusterIssuer)
terraform apply \
  -target=helm_release.cert_manager \
  -target=helm_release.ingress_nginx \
  -target=helm_release.godaddy_webhook \
  -target=kubernetes_secret_v1.godaddy_api_key \
  -target=kubernetes_secret_v1.ocir_secret

# Steg 2: ClusterIssuer og resten
terraform apply
```

> **Tips:** To-stegs apply er nødvendig fordi Terraform validerer `kubernetes_manifest` mot Kubernetes API under plan, og cert-manager CRD-ene må være installert først.

---

## Steg 4 — Deploy querychat

```bash
kubectl apply -f /workspaces/rdapkipoc/application/frontend/k8s/querychat-k8s.yaml

# Følg med på sertifikatutstedelse
kubectl get certificate querychat-tls --watch

# Hent ingress IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

Oppdater A-record i GoDaddy: `querychat.elcarocloud.no → <ingress IP>`

---

## Steg 5 — Verifiser

```bash
# DNS
dig querychat.elcarocloud.no @8.8.8.8 +short

# CORS på API Gateway
curl -si -X OPTIONS https://api.elcarocloud.no/v1/ask \
  -H "Origin: https://querychat.elcarocloud.no" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type" | grep -i access-control

# API-test
curl -s -X POST https://api.elcarocloud.no/v1/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"hvilke helseforetak har vi"}'
```

---

## Oppdater image etter endringer

```bash
sudo docker build -t ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest .
sudo docker push ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest
kubectl rollout restart deployment querychat
kubectl rollout status deployment querychat
```

---

## Feilsøking

### kubectl kobler ikke til cluster
```bash
oci ce cluster create-kubeconfig \
  --cluster-id ocid1.cluster.oc19.eu-frankfurt-2.aaaaaaaacjtgtlnbpodzvnblfl5joj3dy6hcmqavrfvidptg2cburyzxciiq \
  --file ~/.kube/config \
  --region eu-frankfurt-2 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT
```

### Pod starter ikke (ImagePullBackOff)
```bash
kubectl describe pod <pod-navn>
# Sjekk at ocir-secret finnes
kubectl get secret ocir-secret
# Gjenopprett om nødvendig
kubectl delete secret ocir-secret
kubectl create secret docker-registry ocir-secret \
  --docker-server=ocir.eu-frankfurt-2.oci.oraclecloud.eu \
  --docker-username='axpqbvkhoxdj/<epost>' \
  --docker-password='<auth-token>'
```

### Sertifikat ikke utstedt
```bash
kubectl get certificate
kubectl get certificaterequest
kubectl get order
kubectl get challenge
kubectl describe challenge <navn>

# cert-manager logger
kubectl logs -n cert-manager deployment/cert-manager | tail -30

# godaddy-webhook logger
kubectl logs -n cert-manager deployment/godaddy-webhook | tail -30

# Test GoDaddy API-nøkkel
curl -s "https://api.godaddy.com/v1/domains/elcarocloud.no" \
  -H "Authorization: sso-key <KEY>:<SECRET>" | head -c 100

# Slett og start på nytt om nødvendig
kubectl delete certificate querychat-tls
kubectl delete order --all
kubectl delete challenge --all
kubectl delete certificaterequest --all
kubectl apply -f /workspaces/rdapkipoc/application/frontend/k8s/querychat-k8s.yaml
```

### Failed to fetch fra frontend
```bash
# Sjekk at CORS-headere returneres på POST
curl -si -X POST https://api.elcarocloud.no/v1/ask \
  -H "Content-Type: application/json" \
  -H "Origin: https://querychat.elcarocloud.no" \
  -d '{"question":"test"}' | head -20

# Sjekk at OPTIONS preflight fungerer
curl -si -X OPTIONS https://api.elcarocloud.no/v1/ask \
  -H "Origin: https://querychat.elcarocloud.no" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type"
```

### Terraform feil med eksisterende CRD/ClusterRole
```bash
# Slett gjenværende cert-manager ressurser
kubectl delete crd \
  certificaterequests.cert-manager.io \
  certificates.cert-manager.io \
  challenges.acme.cert-manager.io \
  clusterissuers.cert-manager.io \
  issuers.cert-manager.io \
  orders.acme.cert-manager.io

kubectl delete clusterrole -l app.kubernetes.io/instance=cert-manager
kubectl delete clusterrolebinding -l app.kubernetes.io/instance=cert-manager
kubectl delete role -n kube-system -l app.kubernetes.io/instance=cert-manager
kubectl delete rolebinding -n kube-system -l app.kubernetes.io/instance=cert-manager
kubectl delete mutatingwebhookconfiguration cert-manager-webhook
kubectl delete validatingwebhookconfiguration cert-manager-webhook
```

### Nyttige kubectl-kommandoer
```bash
# Se alle pods i alle namespaces
kubectl get pods -A

# Se logger for en pod
kubectl logs -f deployment/querychat
kubectl logs -n cert-manager deployment/cert-manager --since=5m
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --since=5m

# Se events
kubectl get events --sort-by=.lastTimestamp | tail -20

# Se ressursbruk
kubectl top pods
kubectl top nodes

# Restart deployment
kubectl rollout restart deployment querychat
kubectl rollout status deployment querychat

# Se ingress-status
kubectl describe ingress querychat

# Se secret-innhold (base64-dekodet)
kubectl get secret ocir-secret -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d
```

---

## Tips

**GoDaddy API-nøkler** bør roteres jevnlig og alltid etter eksponering. Oppdater `TF_VAR_GODADDY_API_KEY` og `TF_VAR_GODADDY_API_SECRET` i Codespaces secrets og kjør:
```bash
kubectl delete secret godaddy-api-key -n cert-manager
terraform apply -target=kubernetes_secret_v1.godaddy_api_key
```

**OCI auth token** for OCIR har maks 2 tokens per bruker. Oppdater `TF_VAR_OCIR_PASSWORD` i Codespaces secrets og kjør:
```bash
terraform apply -target=kubernetes_secret_v1.ocir_secret
```

**Let's Encrypt-sertifikatet** fornyes automatisk av cert-manager 30 dager før utløp (gyldig i 90 dager). Sjekk status:
```bash
kubectl get certificate querychat-tls
```

**Sykehuspartner-proxy** blokkerer `*.elcarocloud.no` fra jobbnett. Søk om hvitelisting via BAT. Fra privat nett fungerer alt.

**Terraform to-stegs deploy** — ved fullstendig reetablering må Helm-releases deployes før `terraform apply` for ClusterIssuer, siden Terraform validerer CRD-tilgjengelighet under plan.

**Docker og sudo** — i Codespaces har ikke brukeren tilgang til Docker socket uten sudo. Login og push må begge kjøres med sudo.

**Ingress IP endres** ved reetablering av ingress-nginx. Husk å oppdatere A-record i GoDaddy:
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
dig querychat.elcarocloud.no @8.8.8.8 +short
```

---

## URL-er

| URL | Beskrivelse |
|-----|-------------|
| https://querychat.elcarocloud.no | Enkel debug-frontend (rå JSON) |
| https://querychat.elcarocloud.no/chat | Fullverdig QueryChat (tabell/tekst/graf) |
| https://api.elcarocloud.no/v1/ask | SQL-executor API endpoint |
| https://api.elcarocloud.no/v1/feedback | Feedback endpoint |

---

## Filer i repoet

```
rdapkipoc/
├── terraform/infra/
│   ├── oke_addons.tf        # cert-manager, ingress-nginx, godaddy-webhook, secrets
│   ├── network.tf           # VCN, subnets, security lists (inkl. port 443)
│   ├── apigateway.tf        # API Gateway med CORS
│   └── versions.tf          # providers: oci, helm, kubernetes
└── application/frontend/
    ├── Dockerfile           # nginx med index.html og /chat
    ├── index.html           # enkel debug-frontend
    ├── querychat.html       # fullverdig frontend
    └── k8s/
        └── querychat-k8s.yaml  # Deployment, Service, Certificate, Ingress
```

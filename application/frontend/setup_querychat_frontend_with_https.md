# QueryChat — Oppsett på OKE med HTTPS

## Forutsetninger
- OKE-cluster konfigurert
- OCIR-tilgang
- GoDaddy API-nøkkel
- `kubectl`, `helm`, `docker` tilgjengelig

---

## 1. Bygg og push Docker-image til OCIR

```bash
# Logg inn på Sovereign Cloud OCIR
sudo docker login ocir.eu-frankfurt-2.oci.oraclecloud.eu \
  --username 'axpqbvkhoxdj/<din-epost>'

# Bygg image
sudo docker build -t ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest .

# Push image
sudo docker push ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest
```

---

## 2. Koble kubectl til OKE

```bash
oci ce cluster create-kubeconfig \
  --cluster-id <cluster-ocid> \
  --file ~/.kube/config \
  --region eu-frankfurt-2 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT
```

---

## 3. Opprett OCIR pull secret

```bash
kubectl create secret docker-registry ocir-secret \
  --docker-server=ocir.eu-frankfurt-2.oci.oraclecloud.eu \
  --docker-username='axpqbvkhoxdj/<din-epost>' \
  --docker-password='<auth-token>'
```

---

## 4. Deploy applikasjon

```yaml
# deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: querychat
spec:
  replicas: 1
  selector:
    matchLabels:
      app: querychat
  template:
    metadata:
      labels:
        app: querychat
    spec:
      imagePullSecrets:
      - name: ocir-secret
      containers:
      - name: querychat
        image: ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: querychat
spec:
  type: ClusterIP
  selector:
    app: querychat
  ports:
  - port: 80
    targetPort: 80
```

```bash
kubectl apply -f deploy.yaml
```

---

## 5. Installer cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Vent til alle pods er oppe
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=120s
```

---

## 6. Installer ingress-nginx

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

# Hent ekstern IP
kubectl get svc -n ingress-nginx ingress-nginx-controller --watch
# → Oppdater DNS A-record for querychat.elcarocloud.no til denne IP-en
```

---

## 7. Installer GoDaddy webhook for cert-manager

```bash
helm repo add godaddy-webhook https://snowdrop.github.io/godaddy-webhook
helm repo update
helm install godaddy-webhook godaddy-webhook/godaddy-webhook \
  --namespace cert-manager \
  --set logging.level=info
```

---

## 8. Opprett GoDaddy API secret

```bash
# Format: token=<API_KEY>:<API_SECRET>
kubectl create secret generic godaddy-api-key \
  --namespace cert-manager \
  --from-literal=token='<GODADDY_API_KEY>:<GODADDY_API_SECRET>'
```

---

## 9. Opprett ClusterIssuer

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-godaddy
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: <din-epost>
    privateKeySecretRef:
      name: letsencrypt-godaddy-key
    solvers:
    - dns01:
        webhook:
          groupName: acme.mycompany.com
          solverName: godaddy
          config:
            apiKeySecretRef:
              name: godaddy-api-key
              key: token
            production: true
            ttl: 600
EOF
```

---

## 10. Opprett sertifikat og Ingress

```bash
kubectl apply -f - <<'EOF'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: querychat-tls
  namespace: default
spec:
  secretName: querychat-tls-secret
  issuerRef:
    name: letsencrypt-godaddy
    kind: ClusterIssuer
  dnsNames:
  - querychat.elcarocloud.no
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: querychat
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - querychat.elcarocloud.no
    secretName: querychat-tls-secret
  rules:
  - host: querychat.elcarocloud.no
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: querychat
            port:
              number: 80
EOF
```

---

## 11. Verifiser

```bash
# Sjekk sertifikatstatus
kubectl get certificate querychat-tls

# Sjekk pods
kubectl get pods

# Sjekk ingress
kubectl get ingress
```

Sertifikatet er gyldig når `READY = True`.
Tjenesten er tilgjengelig på: **https://querychat.elcarocloud.no**

---

## Feilsøking

```bash
# Se challenge-status
kubectl get challenge
kubectl describe challenge <navn>

# Se cert-manager logger
kubectl logs -n cert-manager deployment/cert-manager | tail -30

# Se godaddy-webhook logger
kubectl logs -n cert-manager deployment/godaddy-webhook | tail -30

# Test CORS
curl -si -X OPTIONS https://api.elcarocloud.no/v1/ask \
  -H "Origin: https://querychat.elcarocloud.no" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type"
```

---

## Viktig
- Regenerer GoDaddy API-nøkler jevnlig
- Sertifikatet fornyes automatisk av cert-manager
- Sykehuspartner-proxy blokkerer tilgang fra jobbnett — søk om hvitelisting av `querychat.elcarocloud.no` og `api.elcarocloud.no`

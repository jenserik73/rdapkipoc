# Frontend – Dokumentasjon

QueryChat frontend er en single-page applikasjon bygget med vanilla HTML/CSS/JS,
servert via nginx på OKE (Oracle Kubernetes Engine).

## URLer

| URL | Beskrivelse |
|-----|-------------|
| `https://querychat.elcarocloud.no/` | Enkel gammel testside (`index.html`) |
| `https://querychat.elcarocloud.no/chat/` | Hovedapplikasjon (`querychat.html`) |

## Deploy

### Bruk alltid deploy-scriptet
```bash
cd application/frontend
./deploy.sh
```

Scriptet tagger image med git SHA for å unngå cache-problemer med `latest`-tag.

### Manuell deploy med spesifikk tag
```bash
TAG=$(git rev-parse --short HEAD)
sudo docker build --no-cache \
  -t ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:$TAG .
sudo docker push ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:$TAG
kubectl set image deployment/querychat \
  querychat=ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:$TAG
kubectl rollout status deployment querychat
```

### Verifiser at riktig image kjører
```bash
kubectl describe pod -l app=querychat | grep "Image ID"
```
Digest skal matche det som ble pushet.

## Feilsøking

### Sjekk at pods kjører
```bash
kubectl get pods -l app=querychat
```

### Sjekk pod-logger
```bash
kubectl logs -l app=querychat --tail=50
```

### Sjekk ingress
```bash
kubectl describe ingress querychat
```

### Hent kubeconfig (hvis kubectl ikke fungerer)
```bash
oci ce cluster create-kubeconfig \
  --cluster-id ocid1.cluster.oc19.eu-frankfurt-2.aaaaaaaacjtgtlnbpodzvnblfl5joj3dy6hcmqavrfvidptg2cburyzxciiq \
  --file ~/.kube/config \
  --region eu-frankfurt-2 \
  --token-version 2.0.0 \
  --kube-endpoint PUBLIC_ENDPOINT
```

### Restart deployment
```bash
kubectl rollout restart deployment querychat
kubectl rollout status deployment querychat
```

### Tving ny image-pull (hvis latest-cache er et problem)
```bash
# Bruk spesifikk digest i stedet for latest
kubectl set image deployment/querychat \
  querychat=ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat@sha256:<digest>
```

### Hard refresh i nettleser
`Ctrl+Shift+R` – tvinger nettleseren til å hente ny versjon av siden.

### Sjekk TLS-sertifikat
```bash
kubectl get certificate -A
kubectl describe certificate querychat-tls -n default
```

## Autentisering

### Token-håndtering
- **Access token**: Lagres i `sessionStorage` – utløper etter 15 min
- **Refresh token**: Lagres i `localStorage` – utløper etter 30 dager
- Auto-refresh skjer automatisk ved 401-respons fra API
- Ved oppstart sjekkes om access token er gyldig via JWT `exp`-felt

### Glemt passord
- Bruker klikker "Glemt passord?" → skriver inn e-post
- Backend sender reset-lenke til e-post
- Lenke format: `https://querychat.elcarocloud.no/chat/#/reset?token=<token>`
- Frontend leser token fra URL-hash ved oppstart og viser reset-skjerm
- Token er gyldig i 60 minutter og kan kun brukes én gang

## Lokale innstillinger (localStorage)

| Nøkkel | Beskrivelse |
|--------|-------------|
| `qc_url` | API Gateway URL for spørringer |
| `qc_fb` | Feedback endpoint URL |
| `qc_refresh` | Refresh token |
| `qc_sessions` | Chat-historikk (maks 50 samtaler) |

### Tøm localStorage (nyttig ved feilsøking)
Åpne DevTools (F12) → Console:
```javascript
localStorage.clear()
sessionStorage.clear()
location.reload()
```

### Sjekk gjeldende tokens
```javascript
console.log('access:', sessionStorage.getItem('qc_access'))
console.log('refresh:', localStorage.getItem('qc_refresh'))
```

### Dekod JWT access token
```javascript
const token = sessionStorage.getItem('qc_access')
const payload = JSON.parse(atob(token.split('.')[1]))
console.log(payload)
// Viser: email, name, roles, permissions, exp (utløpstidspunkt)
```

## Viktige tekniske detaljer

### Cache-problem med latest-tag
OKE cacher `latest`-tag og henter ikke nytt image ved `kubectl rollout restart`.
Bruk alltid `deploy.sh` som tagger med git SHA, eller sett image eksplisitt med digest.

### Feedback og logId
- Feedback fungerer kun på nye meldinger i samme sesjon
- Gamle meldinger fra `localStorage`-historikk har ikke `logId`
- `logId` hentes fra `ask_nl()`-responsen og lagres i chat-session

### Admin-panel
- Vises kun for brukere med `admin:users` eller `admin:roles` permission
- Sjekkes via JWT-payload ved innlogging

### Sykehuspartner-nett
Sykehuspartners bedriftsproxy blokkerer nyregistrerte domener.
Test alltid fra privat nettverk (mobil hotspot eller hjemmenett).

## Docker-image

```
OCIR: ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat
```

### Dockerfile
```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY querychat.html /usr/share/nginx/html/chat/index.html
```

## Linter-konfigurasjon

`pyrightconfig.json` i repo-rot:
```json
{
  "reportMissingImports": false,
  "reportMissingModuleSource": false,
  "typeCheckingMode": "off"
}
```

`.pylintrc` i repo-rot deaktiverer advarsler som ikke er relevante for OCI Functions-kode
(broad-exception-caught, import-error, invalid-name, global-statement, osv.)

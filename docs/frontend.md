# Frontend – Dokumentasjon

QueryChat frontend er en single-page applikasjon bygget med vanilla HTML/CSS/JS,
servert via nginx på OKE (Oracle Kubernetes Engine).

## URLer

| URL | Beskrivelse |
|-----|-------------|
| `https://querychat.elcarocloud.no/` | Enkel testside (`index.html`) |
| `https://querychat.elcarocloud.no/chat/` | Hovedapplikasjon (`querychat.html`) |

---

## Deploy

Bruk alltid deploy-scriptet fra `scripts/`:

```bash
bash scripts/deploy-frontend.sh
```

Scriptet gjør følgende automatisk:
1. `docker build --no-cache` fra `application/frontend/`
2. `docker push` til OCIR
3. `kubectl set image` – tvinger OKE til å registrere ny image-referanse
4. `kubectl rollout restart` – starter nye pods
5. `kubectl rollout status` – venter til rollout er fullført

### Hvorfor `kubectl set image` er nødvendig

OKE bruker `imagePullPolicy: IfNotPresent` som standard. Når deployment bruker
`:latest`-tag uten eksplisitt digest, antar OKE at imaget ikke har endret seg –
selv etter `kubectl rollout restart`. `kubectl set image` tvinger OKE til å
registrere en endring og hente nytt image.

### Manuell deploy (hvis scriptet ikke er tilgjengelig)

```bash
cd /workspaces/rdapkipoc/application/frontend

sudo docker build --no-cache \
  -t ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest .

sudo docker push ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest

kubectl set image deployment/querychat \
  querychat=ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest

kubectl rollout restart deployment querychat
kubectl rollout status deployment querychat
```

### Verifiser at riktig image kjører

```bash
kubectl get deployment querychat \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

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

### Sjekk TLS-sertifikat
```bash
kubectl get certificate -A
kubectl describe certificate querychat-tls -n default
```

### Hard refresh i nettleser
`Ctrl+Shift+R` – tvinger nettleseren til å hente ny versjon av siden.
Nødvendig etter deploy siden nettleseren cacher HTML/JS.

### Sjekk om riktig versjon er lastet (DevTools Console)
```javascript
// Sjekk om et kjent element finnes i DOM
document.getElementById('meta-tab-btn')
// null = gammel versjon, HTMLButtonElement = ny versjon

// Sjekk innholdet i admin-tabs
document.querySelector('.admin-tabs').innerHTML
```

### Tøm nettleser-cache (ved vedvarende cache-problemer)
```javascript
localStorage.removeItem('qc_refresh')
sessionStorage.removeItem('qc_access')
location.reload()
```

---

## Autentisering

### Token-håndtering
- **Access token**: Lagres i `sessionStorage` – utløper etter 15 min
- **Refresh token**: Lagres i `localStorage` – utløper etter 30 dager
- Auto-refresh skjer automatisk ved 401-respons fra API
- Ved oppstart sjekkes om access token er gyldig via JWT `exp`-felt

### Hent og dekod token (DevTools Console)
```javascript
// Sjekk permissions i gjeldende token
const token = sessionStorage.getItem('qc_access')
const payload = JSON.parse(atob(token.split('.')[1]))
console.log(payload.permissions)
// Forventet for admin: ["admin:metadata","query:execute","query:read",
//                       "feedback:write","admin:users","admin:roles"]
```

### Glemt passord
- Bruker klikker "Glemt passord?" → skriver inn e-post
- Backend sender reset-lenke til e-post
- Lenke format: `https://querychat.elcarocloud.no/chat/#/reset?token=<token>`
- Frontend leser token fra URL-hash ved oppstart og viser reset-skjerm
- Token er gyldig i 60 minutter og kan kun brukes én gang

### must_change_password
- Nye brukere og brukere som har fått passord reset av admin får `must_change_password = 1`
- Ved innlogging returnerer backend `must_change_password: true` i login-responsen
- Frontend viser automatisk "Passordbytte påkrevd"-modal – kan ikke lukkes uten å bytte passord
- Etter vellykket passordbytte nullstilles flagget i databasen

### Bytt passord (frivillig)
- Alle innloggede brukere ser "Bytt passord"-knapp i sidebar-footer
- Krever gammelt passord + nytt passord + bekreftelse
- Passordfeltene har øye-knapp for å vise/skjule passord

---

## Lokale innstillinger (localStorage)

| Nøkkel | Beskrivelse |
|--------|-------------|
| `qc_url` | API Gateway URL for spørringer |
| `qc_fb` | Feedback endpoint URL |
| `qc_refresh` | Refresh token |
| `qc_sessions` | Chat-historikk (maks 50 samtaler) |

---

## Admin-panel

Vises kun for brukere med `admin:users` eller `admin:roles` permission.
Sjekkes via JWT-payload ved innlogging via `updateAdminNav()`.

### Faner

| Fane | Rettighet | Beskrivelse |
|------|-----------|-------------|
| **Brukere** | `admin:users` | Administrer brukere og roller |
| **Roller** | `admin:roles` | Administrer roller og rettigheter |
| **Metadata** | `admin:metadata` | Administrer NL2SQL-annotasjoner |

### Metadata-fanen
Metadata-fanen vises kun for brukere med `admin:metadata`-permission (tilhører `admin`-rollen).
Den lar administrator legge til, redigere og arkivere Oracle-annotasjoner og COMMENT ON
for tabellene i QUERYCHAT-skjemaet. Se `docs/admin-handler.md` for API-dokumentasjon
og `docs/querychat_brukerdokumentasjon.md` for brukerveiledning.

### Metadata-fanen vises ikke etter deploy
Hvis Metadata-fanen ikke vises for admin-bruker etter deploy:
1. Sjekk at token inneholder `admin:metadata`:
```javascript
const p = JSON.parse(atob(sessionStorage.getItem('qc_access').split('.')[1]))
console.log(p.permissions)
```
2. Hvis `admin:metadata` mangler: logg ut, tøm localStorage/sessionStorage, logg inn igjen
3. Hvis `admin:metadata` er i token men fanen ikke vises: hard refresh (`Ctrl+Shift+R`)
4. Hvis fanen fortsatt ikke vises: sjekk at `meta-tab-btn`-elementet finnes i DOM

### Roller tildeles/fjernes
Via checkboxer i "Roller"-modal per bruker. Endringer lagres umiddelbart.

---

## Docker-image

```
OCIR: ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat
```

### Dockerfile
```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
COPY querychat.html /usr/share/nginx/html/chat/index.html
COPY logo.png /usr/share/nginx/html/logo.png
COPY favicon.png /usr/share/nginx/html/favicon.png
COPY logo_emptystate.png /usr/share/nginx/html/logo_emptystate.png
```

### Filer i `application/frontend/`

| Fil | Beskrivelse |
|-----|-------------|
| `index.html` | Enkel testside på rotnivå |
| `querychat.html` | Hovedapplikasjon – all logikk i én fil |
| `logo.png` | "Datasjø KI" robot-logo for sidebar |
| `logo_emptystate.png` | Større versjon for tom chat-tilstand |
| `favicon.png` | Favicon |
| `Dockerfile` | nginx:alpine med alle filer kopiert inn |

---

## Viktige tekniske detaljer

### OCIR 500-feil ved push
OCIR returnerer av og til `500 Internal Server Error` ved manifest-opplasting,
selv når alle lag er pushet korrekt. Dette er en kjent OCIR-plattformfeil i oc19.
`deploy-frontend.sh` ignorerer dette og fortsetter – rollout lykkes likevel.

### Nettlesercache
Etter deploy må nettleseren tvinges til å hente ny HTML med `Ctrl+Shift+R`.
Vanlig F5/reload er ikke nok hvis nettleseren har cachet siden.

### Feedback og logId
- Feedback fungerer kun på nye meldinger i samme sesjon
- Gamle meldinger fra `localStorage`-historikk har ikke `logId`
- `logId` hentes fra `ask_nl()`-responsen og lagres i chat-session

### Sykehuspartner-nett
Sykehuspartners bedriftsproxy blokkerer nyregistrerte domener.
Test alltid fra privat nettverk (mobil hotspot eller hjemmenett).

---

## Relatert dokumentasjon

- `docs/admin-handler.md` – API-dokumentasjon for admin-endepunkter inkl. metadata
- `docs/deploy_dokumentasjon.md` – Komplett deploy-rutine og feilsøking
- `docs/querychat_brukerdokumentasjon.md` – Brukerveiledning for alle funksjoner
- `docs/metadata_gui_testcaser.md` – Manuell testplan for Metadata-fanen

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

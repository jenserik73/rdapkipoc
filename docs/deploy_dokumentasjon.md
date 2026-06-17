# Deploy-prosess og feilsøking – QueryChat

Dokumentasjon av deploy-rutiner for QueryChat på OCI Sovereign Cloud (oc19, eu-frankfurt-2).
Inkluderer lærdom fra feilsøking av vanlige deploy-problemer.

---

## Oversikt over komponenter

| Komponent | Type | Deploy-metode |
|---|---|---|
| `querychat` (frontend) | OKE Deployment | `deploy-frontend.sh` |
| `admin-handler` | OCI Function | `deploy-function.sh admin-handler` |
| `auth-handler` | OCI Function | `deploy-function.sh auth-handler` |
| `sql-executor` | OCI Function | `deploy-function.sh sql-executor` |
| `feedback-executor` | OCI Function | `deploy-function.sh feedback-executor` |

---

## Deploy-scripts

Begge scriptene ligger i `scripts/` og gjøres kjørbare med:

```bash
chmod +x scripts/deploy-frontend.sh
chmod +x scripts/deploy-function.sh
```

### Frontend (OKE)

```bash
bash scripts/deploy-frontend.sh
```

Scriptet gjør følgende i rekkefølge:
1. `docker build --no-cache` fra `application/frontend/`
2. `docker push` til OCIR
3. `kubectl set image` – tvinger OKE til å registrere ny image-referanse
4. `kubectl rollout restart` – starter nye pods
5. `kubectl rollout status` – venter til rollout er fullført

### OCI Functions

```bash
bash scripts/deploy-function.sh <funksjonsnavn>

# Eksempler:
bash scripts/deploy-function.sh admin-handler
bash scripts/deploy-function.sh auth-handler
bash scripts/deploy-function.sh sql-executor
bash scripts/deploy-function.sh feedback-executor
```

Scriptet gjør følgende i rekkefølge:
1. `docker build --no-cache` fra `application/<funksjonsnavn>/`
2. `docker push` til OCIR
3. `terraform apply -auto-approve` fra `terraform/infra/` – Terraform plukker opp ny digest automatisk

---

## Viktige lærdommer

### `kubectl rollout restart` er ikke nok for `:latest`-tag

OKE bruker `imagePullPolicy: IfNotPresent` som standard. Når deployment bruker `:latest`-tag
uten en eksplisitt digest, antar OKE at imaget ikke har endret seg og henter ikke ny versjon –
selv etter `kubectl rollout restart`.

**Løsning:** Alltid bruk `kubectl set image` FØR `kubectl rollout restart`:

```bash
kubectl set image deployment/querychat \
  querychat=ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/querychat:latest
kubectl rollout restart deployment querychat
```

`deploy-frontend.sh` håndterer dette automatisk.

### OCIR 500-feil ved `docker push` er vanligvis ufarlige

OCIR i oc19 returnerer av og til `received unexpected HTTP status: 500 Internal Server Error`
ved manifest-opplasting, selv når alle lag er pushet korrekt. Dette er en kjent OCIR-plattformfeil.

Tegn på at push likevel gikk gjennom:
- Alle lag viser `Pushed` eller `Layer already exists`
- `docker push` returnerer en digest (`sha256:...`) før feilmeldingen
- `terraform apply` (for Functions) rapporterer endring i `image_digest`

**Løsning:** Ignorer 500-feilen og fortsett med neste steg. Hvis det er tvil, re-push én gang til.

### `PYTHONPATH` må inkludere `/function` i OCI Functions Dockerfile

OCI Functions bruker `fnproject/python:3.12` med `fdk` som custom module loader.
`fdk` legger ikke automatisk til `/function` i `sys.path`, så lokale Python-moduler
(f.eks. `metadata_sync.py`) er ikke importerbare selv om de er kopiert inn i imaget.

**Korrekt Dockerfile:**
```dockerfile
FROM fnproject/python:3.12-dev AS build-stage
WORKDIR /function
COPY requirements.txt .
RUN pip3 install -r requirements.txt --target /python
FROM fnproject/python:3.12
WORKDIR /function
COPY --from=build-stage /python /python
COPY *.py .
ENV PYTHONPATH=/python:/function   # <-- /function må være med
ENTRYPOINT ["/python/bin/fdk", "/function/func.py", "handler"]
```

Merk: `COPY *.py .` (ikke `COPY func.py .`) sørger for at alle lokale moduler inkluderes.

---

## Feilsøkingskommandoer

### Verifiser hva som kjører i OKE

```bash
# Hvilken image/digest kjører deployment?
kubectl get deployment querychat -o jsonpath='{.spec.template.spec.containers[0].image}'

# Status og alder på pods
kubectl get pods -l app=querychat

# Detaljert pod-info (image, restart-count, events)
kubectl describe pod -l app=querychat
```

### Verifiser hva som kjører i OCI Functions

```bash
# Hvilken image og digest er deployet?
oci fn function get \
  --function-id <function-ocid> \
  --query 'data.{image: image, digest: "image-digest", state: "lifecycle-state"}'
```

### Test OCI Function direkte (bypasser API Gateway)

```bash
# Tom body – bør gi 401 (Mangler Authorization-header), ikke 502
echo '{}' | fn invoke rdap-chatbot-application admin-handler

# Hvis 502: funksjonen krasjer ved oppstart/import
# Hvis 401/404: funksjonen er oppe, routing fungerer
```

### Hent OCI Function-logger (traceback ved 502)

```bash
# 1. Noter starttid
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 2. Trigger en invokasjon
echo '{}' | fn invoke rdap-chatbot-application admin-handler

# 3. Sett sluttid (2 minutter frem)
END=$(date -u -d '+2 minutes' +%Y-%m-%dT%H:%M:%SZ)

# 4. Søk i loggene
oci logging-search search-logs \
  --search-query "search \"<compartment-ocid>/<log-group-ocid>/<log-ocid>\" | sort by datetime desc" \
  --time-start "$START" \
  --time-end "$END" \
  --query 'data.results[*].data.message'
```

Kjente OCID-er for rdap-chatbot-application:
- Compartment: `ocid1.compartment.oc19..aaaaaaaaw7nfek7szdgjrdidzqhkjzx7bw4txy2y3kdydjryavxmei52t5xq`
- Log group: `ocid1.loggroup.oc19.eu-frankfurt-2.amaaaaaalgam66yahday4p735relhngwczxtaxupdokojjq5nnyt4rykxvpq`
- Log (invoke): `ocid1.log.oc19.eu-frankfurt-2.amaaaaaalgam66yaoe6etudhjgonkqohyavnbs4v4ckstanu55h2cjisgz2a`

### Sjekk Python-syntaks og import lokalt

```bash
cd application/admin-handler

# Syntakssjekk (fanger ikke runtime-feil)
python3 -m py_compile func.py metadata_sync.py
echo "exit: $?"

# Verifiser at moduler er i Docker-imaget
sudo docker run --rm \
  --entrypoint ls \
  ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/admin-handler:latest \
  /function
```

### Nettleser-cache ved frontend-deploy

Etter deploy av ny frontend: bruk **Ctrl+Shift+R** (hard refresh) for å tvinge nettleseren
til å hente ny HTML/JS – ikke bare F5.

Sjekk hvilken versjon nettleseren faktisk kjører (i DevTools Console):

```javascript
// Sjekk om et kjent element finnes i DOM
document.getElementById('meta-tab-btn')   // null = gammel versjon

// Sjekk innholdet i admin-tabs
document.querySelector('.admin-tabs').innerHTML
```

Sjekk hvilken digest OKE-deployment bruker:

```bash
kubectl get deployment querychat \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Hvis digest er gammel etter rollout: kjør `kubectl set image`-kommandoen manuelt (se over).

---

## OCIR-endepunkt og namespace

```
Registry:  ocir.eu-frankfurt-2.oci.oraclecloud.eu
Namespace: axpqbvkhoxdj
Realm:     oc19 (OCI Sovereign Cloud)
```

Docker login ved behov:
```bash
sudo docker login ocir.eu-frankfurt-2.oci.oraclecloud.eu
```

---

## Terraform

```bash
cd terraform/infra

# Se planlagte endringer uten å kjøre dem
terraform plan

# Kjør endringer (deploy-function.sh bruker -auto-approve)
terraform apply

# Sjekk nåværende tilstand for en funksjon
terraform state show oci_functions_function.admin_handler | grep -iE "image|digest"
```

OCI Functions-ressurser i Terraform: `oci_functions_function.admin_handler`,
`.auth_handler`, `.sql_executor`, `.feedback_executor`.
Digest oppdateres automatisk av Terraform etter push til OCIR.

# admin-handler – Dokumentasjon

OCI Function som håndterer administrasjons-endepunkter for QueryChat.
Krever gyldig JWT med riktig permission per endepunktsgruppe.

Kildekode: `application/admin-handler/func.py` + `application/admin-handler/metadata_sync.py`

---

## Endepunkter

### Brukere
Krever permission: `admin:users`

| Metode | URL | Beskrivelse |
|--------|-----|-------------|
| GET | `/v1/admin/users` | List alle brukere med roller |
| POST | `/v1/admin/users` | Opprett ny bruker |
| GET | `/v1/admin/users/{id}` | Hent enkelt bruker |
| PUT | `/v1/admin/users/{id}` | Oppdater bruker (navn, aktiv-status) |
| DELETE | `/v1/admin/users/{id}` | Deaktiver bruker |
| POST | `/v1/admin/users/{id}/roles` | Tildel rolle til bruker |
| DELETE | `/v1/admin/users/{id}/roles/{role_id}` | Fjern rolle fra bruker |
| POST | `/v1/admin/users/{id}/reset-password` | Tilbakestill brukers passord |

### Roller
Krever permission: `admin:roles`

| Metode | URL | Beskrivelse |
|--------|-----|-------------|
| GET | `/v1/admin/roles` | List alle roller med rettigheter |
| POST | `/v1/admin/roles` | Opprett ny rolle |
| PUT | `/v1/admin/roles/{id}` | Oppdater rolle (beskrivelse) |
| DELETE | `/v1/admin/roles/{id}` | Slett rolle |

### Metadata (NL2SQL-annotasjoner)
Krever permission: `admin:metadata`

| Metode | URL | Beskrivelse |
|--------|-----|-------------|
| GET | `/v1/admin/metadata/objects/{owner}/{name}` | Hent kolonner, COMMENT ON, Oracle annotations og qc_object_annotations-rader for ett objekt |
| POST | `/v1/admin/metadata/annotations` | Opprett eller oppdater annotasjon (synker DDL til Oracle) |

---

## Request/Response-format

### GET /admin/metadata/objects/{owner}/{name}

**Respons:**
```json
{
  "ok": true,
  "object_owner": "QUERYCHAT",
  "object_name": "KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK",
  "columns": [
    {"column_name": "HELSEFORETAK", "data_type": "VARCHAR2", "data_length": 64, "nullable": true}
  ],
  "existing_comments": {
    "table": "Tabell-kommentar fra COMMENT ON TABLE...",
    "columns": {
      "HELSEFORETAK": "Kolonne-kommentar fra COMMENT ON COLUMN..."
    }
  },
  "existing_annotations": [
    {"column_name": "BELOEP", "annotation_name": "DESCRIPTION", "annotation_value": "..."}
  ],
  "qc_annotations": [
    {
      "id": "46D9099CF6B1E8A19780D0095B7FE363",
      "column_name": "LOENNSGRUPPE",
      "sync_target": "ANNOTATION",
      "annotation_name": "DESCRIPTION",
      "annotation_value": "...",
      "notat_type": null,
      "status": "AKTIV",
      "updated_by": "53EE2EEF08ACF3BCE063BE18000A7186",
      "updated_at": "2026-06-17 13:14:57.083915"
    }
  ]
}
```

### POST /admin/metadata/annotations

**Request body – opprett ny:**
```json
{
  "object_owner": "QUERYCHAT",
  "object_name": "KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK",
  "column_name": "LOENNSGRUPPE",
  "sync_target": "ANNOTATION",
  "annotation_name": "DESCRIPTION",
  "annotation_value": "Tekst her...",
  "notat_type": null,
  "status": "AKTIV"
}
```

**Request body – oppdater eksisterende (send `id`):**
```json
{
  "id": "46D9099CF6B1E8A19780D0095B7FE363",
  "object_owner": "QUERYCHAT",
  "object_name": "KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK",
  "column_name": "LOENNSGRUPPE",
  "sync_target": "ANNOTATION",
  "annotation_name": "DESCRIPTION",
  "annotation_value": "Oppdatert tekst...",
  "status": "AKTIV"
}
```

**Felter:**

| Felt | Påkrevd | Beskrivelse |
|------|---------|-------------|
| `object_owner` | Ja | Skjema-eier, f.eks. `QUERYCHAT` |
| `object_name` | Ja | Tabellnavn |
| `column_name` | Nei | Kolonnenavn – null for tabellnivå |
| `sync_target` | Ja | `ANNOTATION`, `COMMENT` eller `NONE` |
| `annotation_name` | Ja for ANNOTATION | `DESCRIPTION`, `ALIASES`, `UNITS`, `JOIN COLUMN` |
| `annotation_value` | Ja | Innholdet som synkes eller lagres |
| `notat_type` | Ja for NONE | `DATAKVALITET`, `VIEW_KANDIDAT`, `TODO` |
| `status` | Ja | `AKTIV`, `UTKAST` eller `ARKIVERT` |
| `id` | Nei | Sett ved oppdatering av eksisterende rad |

**Respons ved suksess:**
```json
{
  "ok": true,
  "id": "46D9099CF6B1E8A19780D0095B7FE363",
  "ddl": [
    "ALTER TABLE \"QUERYCHAT\".\"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK\" MODIFY \"LOENNSGRUPPE\" ANNOTATIONS (ADD DESCRIPTION '...')"
  ]
}
```

**DDL-logikk per status-overgang:**

| Gammel status | Ny status | sync_target=ANNOTATION | sync_target=COMMENT |
|---------------|-----------|------------------------|---------------------|
| – (ny rad) | AKTIV | `ADD <name> '...'` | `COMMENT ON ... IS '...'` |
| – (ny rad) | UTKAST | ingen DDL | ingen DDL |
| AKTIV | AKTIV (samme navn) | `REPLACE <name> '...'` | `COMMENT ON ... IS '...'` |
| AKTIV | AKTIV (nytt navn) | `DROP <gammelt>, ADD <nytt> '...'` | – |
| AKTIV | ARKIVERT | `DROP <name>` | `COMMENT ON ... IS ''` |
| UTKAST | AKTIV | `ADD <name> '...'` | `COMMENT ON ... IS '...'` |

**NB:** Oracle tillater ikke `DROP` og `ADD` av samme annotasjonsnavn i én setning (`ORA-11602`).
Bruk `REPLACE` (automatisk håndtert av `build_ddl_statements()` i `metadata_sync.py`).

---

## Test-kommandoer

### Forutsetning: hent token
```bash
TOKEN=$(curl -s -X POST "https://api.elcarocloud.no/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "jemyhr@sykehuspartner.no", "password": "<passord>"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

Token utløper etter 15 minutter – kjør denne på nytt ved `401`.

### Brukere

```bash
# List alle brukere
curl -s "https://api.elcarocloud.no/v1/admin/users" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Opprett ny bruker
curl -s -X POST "https://api.elcarocloud.no/v1/admin/users" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"email":"ny@sykehuspartner.no","display_name":"Ny Bruker","password":"Passord123"}' \
  | python3 -m json.tool

# Hent enkelt bruker
USER_ID="<bruker_id>"
curl -s "https://api.elcarocloud.no/v1/admin/users/$USER_ID" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Deaktiver bruker
curl -s -X PUT "https://api.elcarocloud.no/v1/admin/users/$USER_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"active": false}' | python3 -m json.tool

# Tildel rolle
ROLE_ID="<rolle_id>"
curl -s -X POST "https://api.elcarocloud.no/v1/admin/users/$USER_ID/roles" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw "{\"role_id\": \"$ROLE_ID\"}" | python3 -m json.tool

# Fjern rolle
curl -s -X DELETE "https://api.elcarocloud.no/v1/admin/users/$USER_ID/roles/$ROLE_ID" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Tilbakestill passord (autogenerert)
curl -s -X POST "https://api.elcarocloud.no/v1/admin/users/$USER_ID/reset-password" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{}' | python3 -m json.tool
```

### Roller

```bash
# List alle roller
curl -s "https://api.elcarocloud.no/v1/admin/roles" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Opprett ny rolle
curl -s -X POST "https://api.elcarocloud.no/v1/admin/roles" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"name":"analyst","description":"Kan kjøre spørringer"}' \
  | python3 -m json.tool

# Slett rolle
ROLE_ID="<rolle_id>"
curl -s -X DELETE "https://api.elcarocloud.no/v1/admin/roles/$ROLE_ID" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

### Metadata

```bash
# Hent objektdata (kolonner, comments, annotations, qc-rader)
curl -s "https://api.elcarocloud.no/v1/admin/metadata/objects/QUERYCHAT/KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# Opprett ny ANNOTATION
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK","column_name":"LOENNSGRUPPE","sync_target":"ANNOTATION","annotation_name":"DESCRIPTION","annotation_value":"Aarsak til utbetaling.","status":"AKTIV"}' \
  | python3 -m json.tool

# Oppdater eksisterende (hent id fra qc_annotations i GET-svaret)
ID="<annotasjon_id>"
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw "{\"id\":\"$ID\",\"object_owner\":\"QUERYCHAT\",\"object_name\":\"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK\",\"column_name\":\"LOENNSGRUPPE\",\"sync_target\":\"ANNOTATION\",\"annotation_name\":\"DESCRIPTION\",\"annotation_value\":\"Oppdatert tekst.\",\"status\":\"AKTIV\"}" \
  | python3 -m json.tool

# Arkiver
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw "{\"id\":\"$ID\",\"object_owner\":\"QUERYCHAT\",\"object_name\":\"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK\",\"column_name\":\"LOENNSGRUPPE\",\"sync_target\":\"ANNOTATION\",\"annotation_name\":\"DESCRIPTION\",\"annotation_value\":\"Tekst.\",\"status\":\"ARKIVERT\"}" \
  | python3 -m json.tool

# Internt notat (ingen DDL)
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER","column_name":"AKUTTMOTTAK","sync_target":"NONE","notat_type":"DATAKVALITET","annotation_value":"Kjent ETL-feil.","status":"AKTIV"}' \
  | python3 -m json.tool
```

---

## Deploy

Bruk deploy-scriptet fra `scripts/`:

```bash
bash scripts/deploy-function.sh admin-handler
```

Scriptet gjør automatisk:
1. `docker build --no-cache`
2. `docker push` til OCIR
3. Oppdaterer `image_digest` i `terraform/infra/functions.tf`
4. `terraform apply`

Se `docs/deploy_dokumentasjon.md` for detaljer og feilsøkingskommandoer.

---

## Feilsøking

### Aktiver DEBUG-logging
I `terraform/infra/functions.tf`:
```hcl
LOG_LEVEL = "DEBUG"
```
Kjør `bash scripts/deploy-function.sh admin-handler`.

### Hent logger ved 502

```bash
START=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo '{}' | fn invoke rdap-chatbot-application admin-handler
END=$(date -u -d '+2 minutes' +%Y-%m-%dT%H:%M:%SZ)

oci logging-search search-logs \
  --search-query "search \"ocid1.compartment.oc19..aaaaaaaaw7nfek7szdgjrdidzqhkjzx7bw4txy2y3kdydjryavxmei52t5xq/ocid1.loggroup.oc19.eu-frankfurt-2.amaaaaaalgam66yahday4p735relhngwczxtaxupdokojjq5nnyt4rykxvpq/ocid1.log.oc19.eu-frankfurt-2.amaaaaaalgam66yaoe6etudhjgonkqohyavnbs4v4ckstanu55h2cjisgz2a\" | sort by datetime desc" \
  --time-start "$START" \
  --time-end "$END" \
  --query 'data.results[*].data.message'
```

### Test funksjon direkte (bypasser API Gateway)
```bash
# Tom body – bør gi 401, ikke 502
echo '{}' | fn invoke rdap-chatbot-application admin-handler
```
- `401` = funksjonen er oppe, JWT-validering fungerer
- `502` = funksjonen krasjer ved oppstart/import

### Vanlige feil

| Feil | Årsak | Løsning |
|------|-------|---------|
| `502 Bad Gateway` | Funksjonen krasjer ved oppstart | Sjekk OCI Logging for Python-traceback |
| `No module named 'metadata_sync'` | `PYTHONPATH` mangler `/function` | Sjekk at Dockerfile har `ENV PYTHONPATH=/python:/function` og `COPY *.py .` |
| `403 Forbidden` | Mangler riktig permission i JWT | Sjekk at brukeren har riktig rolle, logg ut og inn igjen |
| `400 En annotasjon finnes allerede` | Duplikat i `qc_object_annotations` | Send `id` for oppdatering i stedet for ny rad |
| `ORA-11602` | DROP+ADD av samme annotasjonsnavn | Bruk `REPLACE` – håndteres automatisk av `metadata_sync.py` |
| `ORA-00904 "OWNER"` | `ALL_ANNOTATIONS_USAGE` mangler OWNER-kolonne i ADB | Bruk `USER_ANNOTATIONS_USAGE` (allerede implementert) |
| `502` etter ny deploy | OKE kjører gammel image | Bruk `deploy-function.sh` som oppdaterer digest i Terraform |
| Velkomst-e-post sendes ikke | SMTP-konfig feil | Sjekk `SMTP_*`-miljøvariabler i `functions.tf` |

---

## Viktige tekniske detaljer

### Modulstruktur
- `func.py` – HTTP-ruting, JWT-validering, DB-pool, alle handler-funksjoner
- `metadata_sync.py` – DDL-generering og kjøring for metadata-endepunktene

### Dockerfile – kritiske innstillinger
```dockerfile
COPY *.py .                          # Kopierer ALLE .py-filer, ikke bare func.py
ENV PYTHONPATH=/python:/function     # /function MÅ være med for lokale moduler
```

### RBAC-modell
- Tabeller: `qc_roles`, `qc_permissions`, `qc_role_permissions`, `qc_user_roles`
- Permissions på formatet `perm_resource || ':' || perm_action` (f.eks. `admin:users`)

### Forhåndsdefinerte roller

| Rolle | Rettigheter |
|-------|-------------|
| `admin` | `admin:users`, `admin:roles`, `admin:metadata`, `query:execute`, `query:read`, `feedback:write` |
| `analyst` | `query:execute`, `query:read`, `feedback:write` |
| `viewer` | `query:read` |

### Brukeropprettelse
- Nye brukere får `must_change_password = 1` automatisk
- Velkomst-e-post sendes med midlertidig passord
- Autogenerert passord: 20 tilfeldige hex-tegn (`secrets.token_hex(10)`)

### Passord-reset via admin
- `must_change_password` settes til `1`
- Alle brukerens refresh tokens revokeres
- Passordet vises ikke i responsen

### Metadata-synk
- `sync_target='NONE'` – ingen DDL, kun lagring i `qc_object_annotations`
- `sync_target='COMMENT'` – `COMMENT ON TABLE/COLUMN ... IS '...'`
- `sync_target='ANNOTATION'` – `ALTER TABLE ... [MODIFY <col>] ANNOTATIONS (...)`
- Duplikat-blokkering via `QC_OA_UQ`-indeks + `IntegrityError`-fangst
- `REPLACE`-syntaks brukes ved oppdatering av aktiv annotasjon (ikke DROP+ADD)

### Path-parsing
Ruting skjer via parsing av `fn-http-request-url`-header. Støtter paths under `/admin/`.

---

## Miljøvariabler

| Variabel | Beskrivelse |
|----------|-------------|
| `DB_USER` | Oracle DB-bruker (`querychat`) |
| `DB_DSN` | Oracle DSN (`rdapkipocdb_high`) |
| `WALLET_SECRET_OCID` | Vault OCID for wallet zip |
| `DBPASS_SECRET_OCID` | Vault OCID for DB-passord |
| `WALLETPASS_SECRET_OCID` | Vault OCID for wallet-passord |
| `JWT_SECRET_OCID` | Vault OCID for JWT secret |
| `SMTP_PASSWORD_SECRET_OCID` | Vault OCID for SMTP-passord |
| `SMTP_HOST` | `smtp.email.eu-frankfurt-2.oci.oraclecloud.eu` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | OCI SMTP-brukernavn (langt OCID-format) |
| `EMAIL_SENDER` | `noreply@elcarocloud.no` |
| `FRONTEND_URL` | `https://querychat.elcarocloud.no` |
| `LOG_LEVEL` | `INFO` (sett `DEBUG` ved feilsøking) |

---

## Relatert dokumentasjon

- `docs/deploy_dokumentasjon.md` – deploy-rutiner og feilsøking
- `docs/metadata_api_testdokumentasjon.md` – API-testresultater
- `docs/metadata_gui_testcaser.md` – GUI-testcaser
- `docs/arkitektur_qc_object_annotations.md` – arkitektur og designbeslutninger

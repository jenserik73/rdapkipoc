# feedback-executor – Dokumentasjon

OCI Function som tar imot tilbakemeldinger fra QueryChat-frontend og lagrer dem i ADB.

## Endepunkt

| Metode | URL | Beskrivelse |
|--------|-----|-------------|
| POST | `/v1/feedback` | Lagre tilbakemelding på en spørring |

### Request
```json
{
  "logId": 42,
  "vote": 1,
  "feedbackText": "Bra svar!",
  "correctedSql": "SELECT ..."
}
```

| Felt | Type | Påkrevd | Beskrivelse |
|------|------|---------|-------------|
| `logId` | int | Ja | ID fra `ask_nl()`-responsen |
| `vote` | int | Ja | `1` = positiv, `-1` = negativ |
| `feedbackText` | string | Nei | Fritekst-kommentar |
| `correctedSql` | string | Nei | Korrigert SQL hvis svaret var feil |

### Response
```json
{ "ok": true }
```

## Test-kommandoer

### Forutsetning: hent token og logId
```bash
TOKEN=$(curl -s -X POST https://api.elcarocloud.no/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@elcarocloud.no", "password": "NyttPassord123"}' \
  | jq -r '.access_token')

# Hent logId fra en spørring
RESPONSE=$(curl -s -X POST https://api.elcarocloud.no/v1/ask \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"question": "Vis alle tabeller"}')

LOG_ID=$(echo $RESPONSE | jq -r '.logId')
echo "logId: $LOG_ID"
```

### Send positiv tilbakemelding
```bash
curl -s -X POST https://api.elcarocloud.no/v1/feedback \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"logId\": $LOG_ID,
    \"vote\": 1,
    \"feedbackText\": \"Bra svar!\"
  }" | jq
```

### Send negativ tilbakemelding med korrigert SQL
```bash
curl -s -X POST https://api.elcarocloud.no/v1/feedback \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"logId\": $LOG_ID,
    \"vote\": -1,
    \"feedbackText\": \"Feil tabell brukt\",
    \"correctedSql\": \"SELECT * FROM riktig_tabell\"
  }" | jq
```

### Test uten token (skal gi 401)
```bash
curl -s -X POST https://api.elcarocloud.no/v1/feedback \
  -H "Content-Type: application/json" \
  -d "{\"logId\": 1, \"vote\": 1}" | jq
```

### Test med ugyldig vote (skal gi 400)
```bash
curl -s -X POST https://api.elcarocloud.no/v1/feedback \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"logId\": $LOG_ID, \"vote\": 2}" | jq
```

## Feilsøking

### Aktiver DEBUG-logging
I `terraform/infra/functions.tf`, finn feedback-executor og endre:
```hcl
LOG_LEVEL = "DEBUG"
```
Kjør deretter:
```bash
cd terraform/infra && terraform apply
```

### Deaktiver DEBUG-logging
Sett tilbake til:
```hcl
LOG_LEVEL = "INFO"
```
og kjør `terraform apply`.

### Sjekk logger i OCI Console
**Functions → querychat-app → feedback-executor → Logs**

### Vanlige feil

**Mangler logId** – Frontend lagret ikke `logId` fra `ask_nl()`-responsen.
Sjekk at `sql-executor` returnerer `logId` i responsen.

**400 vote må være 1 eller -1** – Ugyldig vote-verdi sendt.

**Feedback fungerer ikke på gamle meldinger** – Meldinger fra `localStorage`-historikk
har ikke `logId` og kan ikke ha feedback. Gjelder kun nye meldinger i samme sesjon.

### Sjekk feedback i ADB
```sql
SELECT * FROM querychat.qc_query_log
WHERE feedback_vote IS NOT NULL
ORDER BY created_at DESC
FETCH FIRST 10 ROWS ONLY;
```

### Bygg og deploy ny versjon
```bash
cd application/feedback-executor
sudo docker build --no-cache \
  -t ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/feedback-executor:latest .
sudo docker push ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/feedback-executor:latest
# Kopier digest og oppdater functions.tf, deretter:
cd ../../terraform/infra && terraform apply
```

## Viktige tekniske detaljer

### Kobling til spørring
- `logId` må matche en rad i `querychat_pkg` sin log-tabell
- Frontend henter `logId` fra `ask_nl()`-responsen og lagrer det i chat-historikk

### Separasjon fra sql-executor
- `feedback-executor` er en separat function fra `sql-executor`
- Begge har egne OCIR-images og Terraform-ressurser

## Miljøvariabler

| Variabel | Beskrivelse |
|----------|-------------|
| `DB_USER` | Oracle DB bruker |
| `DB_DSN` | Oracle DSN |
| `WALLET_SECRET_OCID` | Vault OCID for wallet zip |
| `DBPASS_SECRET_OCID` | Vault OCID for DB passord |
| `WALLETPASS_SECRET_OCID` | Vault OCID for wallet passord |
| `JWT_SECRET_OCID` | Vault OCID for JWT secret |
| `LOG_LEVEL` | `INFO` (sett `DEBUG` ved feilsøking) |

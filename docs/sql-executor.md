# sql-executor – Dokumentasjon

OCI Function som tar imot naturlige spørsmål og returnerer SQL-resultater via ADB og DBMS_CLOUD_AI.

## Endepunkt

| Metode | URL | Beskrivelse |
|--------|-----|-------------|
| POST | `/v1/ask` | Still et naturlig spørsmål til databasen |

### Request
```json
{
  "question": "Hvor mange dagsverk har SIHF?",
  "history": [
    { "role": "user", "content": "..." },
    { "role": "assistant", "content": "..." }
  ]
}
```

### Response
```json
{
  "ok": true,
  "text": "SIHF har 784 646 dagsverk.",
  "sql": "SELECT SUM(...) FROM ...",
  "logId": 42,
  "columns": ["TOTAL_DAGSVERK"],
  "rows": [{ "TOTAL_DAGSVERK": 784646.54 }]
}
```

## Test-kommandoer

### Forutsetning: hent token
```bash
TOKEN=$(curl -s -X POST https://api.elcarocloud.no/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@elcarocloud.no", "password": "NyttPassord123"}' \
  | jq -r '.access_token')
```

### Still et spørsmål
```bash
curl -s -X POST https://api.elcarocloud.no/v1/ask \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"question": "Vis alle tabeller i databasen"}' | jq
```

### Spørsmål med historikk
```bash
curl -s -X POST https://api.elcarocloud.no/v1/ask \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "question": "Hvor mange rader er det?",
    "history": [
      {"role": "user", "content": "Vis alle tabeller i databasen"},
      {"role": "assistant", "content": "Her er tabellene..."}
    ]
  }' | jq
```

### Test uten token (skal gi 401)
```bash
curl -s -X POST https://api.elcarocloud.no/v1/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "test"}' | jq
```

## Feilsøking

### Aktiver DEBUG-logging
I `terraform/infra/functions.tf`, finn sql-executor og endre:
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
**Functions → querychat-app → sql-executor → Logs**

### Vanlige feil

**Connection pool timeout** – ADB er ikke tilgjengelig eller NAT Gateway er nede.
Sjekk at NAT Gateway IP er hvitelistet i ADB Access Control.

**ORA-01484** – `oracledb` prøver å binde bytes til RAW-kolonne.
Alle ID-kolonner skal være `VARCHAR2(32)`, ikke `RAW(16)`.

**Tom CLOB-respons** – `ask_nl()` returnerte tomt.
Sjekk at `DBMS_CLOUD_AI`-profilen `OCI_GEN_AI_CRED` er konfigurert i ADB.

**401 Ugyldig token** – Access token er utløpt (15 min levetid).
Frontend skal automatisk refreshe, men ved manuell testing: logg inn på nytt.

### Test ADB-tilkobling fra Functions
Sjekk logger etter `Initialiserer connection pool` og `Connection pool klar`.

### Sjekk wallet-filer
```bash
# Inne i Docker-containeren eller på compute-instans:
ls -la /tmp/wallet/
```
Skal inneholde: `ewallet.pem`, `tnsnames.ora`, `sqlnet.ora`

### Bygg og deploy ny versjon
```bash
cd application/sql-executor
sudo docker build --no-cache \
  -t ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/sql-executor:latest .
sudo docker push ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/sql-executor:latest
# Kopier digest og oppdater functions.tf, deretter:
cd ../../terraform/infra && terraform apply
```

## Viktige tekniske detaljer

### NL2SQL-flyt
1. Frontend sender naturlig spørsmål med JWT
2. `sql-executor` validerer JWT
3. Kaller `querychat.querychat_pkg.ask_nl()` i ADB via PL/SQL
4. ADB bruker `DBMS_CLOUD_AI` med profil `OCI_GEN_AI_CRED`
5. Returnerer JSON med SQL, tekst og resultater

### DBMS_CLOUD_AI
- `OCI$RESOURCE_PRINCIPAL` fungerer **ikke** i realm oc19 uten SR
- Bruk API-nøkkel-basert credential: `OCI_GEN_AI_CRED`

### Oracle-driver
- `oracledb` Python-driver kan **ikke** binde `bytes` til RAW-kolonner i vanlig SQL
- Løsning: bruk `VARCHAR2(32)` for ID-kolonner med `RAWTOHEX(SYS_GUID())`
- PL/SQL-kall fungerer med CLOB-output via `cur.var(oracledb.DB_TYPE_CLOB)`

### Wallet
- Slim wallet lagres i OCI Vault (kun `ewallet.pem`, `tnsnames.ora`, `sqlnet.ora`)
- Full wallet overskrider Vault sin ~24KB grense

## Miljøvariabler

| Variabel | Beskrivelse |
|----------|-------------|
| `DB_USER` | Oracle DB bruker |
| `DB_DSN` | Oracle DSN |
| `AI_PROFILE` | DBMS_CLOUD_AI profil |
| `MAX_ROWS` | Maks antall rader i resultat |
| `WALLET_SECRET_OCID` | Vault OCID for wallet zip |
| `DBPASS_SECRET_OCID` | Vault OCID for DB passord |
| `WALLETPASS_SECRET_OCID` | Vault OCID for wallet passord |
| `JWT_SECRET_OCID` | Vault OCID for JWT secret |
| `LOG_LEVEL` | `INFO` (sett `DEBUG` ved feilsøking) |

# auth-handler – Dokumentasjon

OCI Function som håndterer alle autentiserings-endepunkter for QueryChat.

## Endepunkter

| Metode | URL | Beskrivelse |
|--------|-----|-------------|
| POST | `/v1/auth/login` | Logg inn med e-post og passord |
| POST | `/v1/auth/refresh` | Forny access token med refresh token |
| POST | `/v1/auth/logout` | Logg ut og revokér refresh token |
| POST | `/v1/auth/forgot-password` | Send reset-lenke på e-post |
| POST | `/v1/auth/reset-password` | Sett nytt passord med token fra e-post |
| GET | `/v1/me` | Hent innlogget brukers info fra JWT |
| PUT | `/v1/me` | Endre eget passord |

## Test-kommandoer

### Login
```bash
curl -s -X POST https://api.elcarocloud.no/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@elcarocloud.no", "password": "NyttPassord123"}' | jq
```

### Lagre token i variabel
```bash
TOKEN=$(curl -s -X POST https://api.elcarocloud.no/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@elcarocloud.no", "password": "NyttPassord123"}' \
  | jq -r '.access_token')
echo $TOKEN
```

### Hent brukerinfo (/me)
```bash
curl -s https://api.elcarocloud.no/v1/me \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Refresh token
```bash
REFRESH=$(curl -s -X POST https://api.elcarocloud.no/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@elcarocloud.no", "password": "NyttPassord123"}' \
  | jq -r '.refresh_token')

curl -s -X POST https://api.elcarocloud.no/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\": \"$REFRESH\"}" | jq
```

### Logout
```bash
curl -s -X POST https://api.elcarocloud.no/v1/auth/logout \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\": \"$REFRESH\"}" | jq
```

### Glemt passord
```bash
curl -s -X POST https://api.elcarocloud.no/v1/auth/forgot-password \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@elcarocloud.no"}' | jq
```

### Reset passord (med token fra e-post)
```bash
curl -s -X POST https://api.elcarocloud.no/v1/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{"token": "<token_fra_epost>", "password": "NyttPassord123"}' | jq
```

## Feilsøking

### Aktiver DEBUG-logging
I `terraform/infra/functions.tf`, finn auth-handler og endre:
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
**Functions → querychat-app → auth-handler → Logs**

### Sjekk logger via CLI
```bash
oci logging-search search-logs \
  --search-query 'search "ocid1.compartment.oc19..aaaaaaaaw7nfek7szdgjrdidzqhkjzx7bw4txy2y3kdydjryavxmei52t5xq"' \
  --time-start "$(date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')" \
  --time-end "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  | jq '.data.results[].data.logContent.data.message'
```

### Test SMTP-tilkobling fra certbot-instansen
```bash
python3 -c "
import smtplib
HOST = 'smtp.email.eu-frankfurt-2.oci.oraclecloud.eu'
PORT = 587
with smtplib.SMTP(HOST, PORT, timeout=10) as smtp:
    smtp.ehlo()
    smtp.starttls()
    smtp.ehlo()
    print('SMTP OK')
"
```

### Bygg og deploy ny versjon
```bash
cd application/auth-handler
sudo docker build --no-cache \
  -t ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/auth-handler:latest .
sudo docker push ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/auth-handler:latest
# Kopier digest og oppdater functions.tf, deretter:
cd ../../terraform/infra && terraform apply
```

## Oppsett av OCI Email Delivery og e-post

Dette avsnittet dokumenterer alt som måtte gjøres for at e-postutsending skulle fungere.

### 1. OCI Email Delivery – godkjent avsender

Opprettet i Terraform (`email.tf`):
```hcl
resource "oci_email_sender" "querychat_sender" {
  compartment_id = local.compartment_id
  email_address  = "noreply@elcarocloud.no"
}
```

Sjekk status:
```bash
oci email sender get \
  --sender-id ocid1.emailsender.oc19.eu-frankfurt-2.amaaaaaalgam66ya4kax5gckitf4hzhajuhsuh2xrqa3kgpzzyv7w3ejav7q \
  --query "data.{status:\"lifecycle-state\", spf:\"is-spf\"}"
```

`is-spf` må være `true` for at e-poster ikke skal avvises eller havne i spam.

### 2. DNS-record – SPF (påkrevd!)

SPF-record må legges til i GoDaddy DNS for domenet `elcarocloud.no`:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| TXT | @ | `v=spf1 include:rp.oracleemaildelivery.com ~all` | 1 time |

Verifiser at SPF-recorden er på plass:
```bash
dig TXT elcarocloud.no +short
# Skal returnere: "v=spf1 include:rp.oracleemaildelivery.com ~all"
```

Verifiser at OCI har oppdaget SPF-recorden:
```bash
oci email sender get \
  --sender-id ocid1.emailsender.oc19.eu-frankfurt-2.amaaaaaalgam66ya4kax5gckitf4hzhajuhsuh2xrqa3kgpzzyv7w3ejav7q \
  --query "data.\"is-spf\""
# Skal returnere: true
```

### 3. SMTP-credentials

SMTP-brukernavn og passord genereres i OCI Console:
**Identity → Users → din bruker → SMTP Credentials → Generate SMTP Credentials**

SMTP-passordet lagres i OCI Vault som secret `querychat-smtp-password`.

### 4. Nettverksåpning – security list

Utgående port 587 må være tillatt i `seclist_functions` i `network.tf`:

```hcl
egress_security_rules {
  description      = "Allow SMTP outbound via NAT (OCI Email Delivery)"
  destination      = "0.0.0.0/0"
  destination_type = "CIDR_BLOCK"
  protocol         = "6"
  stateless        = false
  tcp_options {
    min = 587
    max = 587
  }
}
```

### 5. Riktig SMTP-hostname (kritisk!)

OCI Email Delivery i Sovereign Cloud (oc19) bruker `.eu`-domene, **ikke** `.com`:

| ❌ Feil | ✅ Riktig |
|--------|---------|
| `smtp.email.eu-frankfurt-2.oci.oraclecloud.com` | `smtp.email.eu-frankfurt-2.oci.oraclecloud.eu` |

DNS-oppslag for å verifisere:
```bash
nslookup smtp.email.eu-frankfurt-2.oci.oraclecloud.eu
# Skal returnere en IP-adresse (209.196.5.80)

nslookup smtp.email.eu-frankfurt-2.oci.oraclecloud.com
# Returnerer NXDOMAIN – finnes ikke!
```

### 6. Riktig tilkoblingsmetode (kritisk!)

| ❌ Feiler i OCI Functions | ✅ Fungerer i OCI Functions |
|--------------------------|---------------------------|
| `smtplib.SMTP_SSL(HOST, 465)` | `smtplib.SMTP(HOST, 587)` + `starttls()` |

`SMTP_SSL` på port 465 feiler med SSL-handshake-feil i OCI Functions-containermiljøet.
Port 587 med STARTTLS fungerer korrekt.

Korrekt kode:
```python
with smtplib.SMTP(SMTP_HOST, 587, timeout=30) as smtp:
    smtp.ehlo()
    smtp.starttls()
    smtp.ehlo()
    smtp.login(SMTP_USER, smtp_password)
    smtp.sendmail(EMAIL_SENDER, to_email, msg.as_string())
```

### 7. Feilsøking av SMTP

Test tilkoblingen fra certbot-instansen (ikke fra Codespaces – bruk en VM i VCN-et):
```bash
python3 -c "
import smtplib
HOST = 'smtp.email.eu-frankfurt-2.oci.oraclecloud.eu'
PORT = 587
print(f'Kobler til {HOST}:{PORT}...')
with smtplib.SMTP(HOST, PORT, timeout=10) as smtp:
    smtp.ehlo()
    smtp.starttls()
    smtp.ehlo()
    print('STARTTLS OK – tilkobling fungerer!')
"
```

Vanlige feil og årsaker:

| Feil | Årsak |
|------|-------|
| `OSError: [Errno 16] Device or resource busy` | Port er blokkert i security list |
| `gaierror: Name or service not known` | Feil hostname (`.com` i stedet for `.eu`) |
| `ssl.SSLError: SSLV3_ALERT_UNEXPECTED_MESSAGE` | Bruker SMTP_SSL på port som forventer STARTTLS |
| E-post sendes men havner i spam | SPF-record mangler eller `is-spf` er false |

## Viktige tekniske detaljer

### JWT
- Access token utløper etter **15 minutter**
- Refresh token utløper etter **30 dager**
- Refresh token roteres ved hver bruk
- Alle refresh tokens revokeres ved passordbytte

### Nettverkskrav (security list for functions-subnet)
Utgående trafikk som må være tillatt:
- Port **1522** – Oracle ADB
- Port **443** – OCI Vault (HTTPS)
- Port **587** – OCI Email Delivery SMTP
- Port **465** – OCI Email Delivery SMTP_SSL (backup)
- Oracle Services Network – alle tjenester

### Passord-reset
- Token er gyldig i **60 minutter**
- Token kan kun brukes **én gang**
- Reset-lenke format: `{FRONTEND_URL}/chat/#/reset?token={token}`

## Miljøvariabler

| Variabel | Beskrivelse |
|----------|-------------|
| `DB_USER` | Oracle DB bruker |
| `DB_DSN` | Oracle DSN |
| `WALLET_SECRET_OCID` | Vault OCID for wallet zip |
| `DBPASS_SECRET_OCID` | Vault OCID for DB passord |
| `WALLETPASS_SECRET_OCID` | Vault OCID for wallet passord |
| `JWT_SECRET_OCID` | Vault OCID for JWT secret |
| `REFRESH_SECRET_OCID` | Vault OCID for refresh secret |
| `SMTP_PASSWORD_SECRET_OCID` | Vault OCID for SMTP passord |
| `SMTP_HOST` | `smtp.email.eu-frankfurt-2.oci.oraclecloud.eu` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | OCI SMTP brukernavn (langt OCID-format) |
| `EMAIL_SENDER` | `noreply@elcarocloud.no` |
| `FRONTEND_URL` | `https://querychat.elcarocloud.no` |
| `LOG_LEVEL` | `INFO` (sett `DEBUG` ved feilsøking) |

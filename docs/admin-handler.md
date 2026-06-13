# admin-handler – Dokumentasjon

OCI Function som håndterer administrasjons-endepunkter for QueryChat.
Krever gyldig JWT med `admin:users` eller `admin:roles` permission.

## Endepunkter

### Brukere
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
| Metode | URL | Beskrivelse |
|--------|-----|-------------|
| GET | `/v1/admin/roles` | List alle roller med rettigheter |
| POST | `/v1/admin/roles` | Opprett ny rolle |
| PUT | `/v1/admin/roles/{id}` | Oppdater rolle |
| DELETE | `/v1/admin/roles/{id}` | Slett rolle |

## Test-kommandoer

### Forutsetning: hent token
```bash
TOKEN=$(curl -s -X POST https://api.elcarocloud.no/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@elcarocloud.no", "password": "NyttPassord123"}' \
  | jq -r '.access_token')
```

### List alle brukere
```bash
curl -s https://api.elcarocloud.no/v1/admin/users \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Opprett ny bruker
```bash
curl -s -X POST https://api.elcarocloud.no/v1/admin/users \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testbruker@elcarocloud.no",
    "display_name": "Test Bruker",
    "password": "Passord123"
  }' | jq
```

### Hent enkelt bruker
```bash
USER_ID="<bruker_id>"
curl -s https://api.elcarocloud.no/v1/admin/users/$USER_ID \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Deaktiver bruker
```bash
curl -s -X PUT https://api.elcarocloud.no/v1/admin/users/$USER_ID \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"active": false}' | jq
```

### Tildel rolle
```bash
ROLE_ID="<rolle_id>"
curl -s -X POST https://api.elcarocloud.no/v1/admin/users/$USER_ID/roles \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"role_id\": \"$ROLE_ID\"}" | jq
```

### Fjern rolle
```bash
curl -s -X DELETE https://api.elcarocloud.no/v1/admin/users/$USER_ID/roles/$ROLE_ID \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Tilbakestill passord (autogenerert)
```bash
curl -s -X POST https://api.elcarocloud.no/v1/admin/users/$USER_ID/reset-password \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}' | jq
```

### List alle roller
```bash
curl -s https://api.elcarocloud.no/v1/admin/roles \
  -H "Authorization: Bearer $TOKEN" | jq
```

### Opprett ny rolle
```bash
curl -s -X POST https://api.elcarocloud.no/v1/admin/roles \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "analyst",
    "description": "Kan kjøre spørringer og se resultater"
  }' | jq
```

### Slett rolle
```bash
curl -s -X DELETE https://api.elcarocloud.no/v1/admin/roles/$ROLE_ID \
  -H "Authorization: Bearer $TOKEN" | jq
```

## Feilsøking

### Aktiver DEBUG-logging
I `terraform/infra/functions.tf`, finn admin-handler og endre:
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
**Functions → querychat-app → admin-handler → Logs**

### Vanlige feil

**403 Forbidden** – Brukeren mangler `admin:users` eller `admin:roles` permission.
Sjekk at brukeren har admin-rollen tildelt.

**CORS-feil med DELETE** – Sjekk at `allowed_methods` i `apigateway.tf` inkluderer DELETE.

**404 på bruker/rolle** – Sjekk at ID-en er korrekt (VARCHAR2(32) format).

**Velkomst-e-post sendes ikke** – Sjekk SMTP-miljøvariabler i `functions.tf`.
Se også feilsøkingsseksjon i `auth-handler.md` for SMTP-testing.

### Bygg og deploy ny versjon
```bash
cd application/admin-handler
sudo docker build --no-cache \
  -t ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/admin-handler:latest .
sudo docker push ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/admin-handler:latest
# Kopier digest og oppdater functions.tf, deretter:
cd ../../terraform/infra && terraform apply
```

## Viktige tekniske detaljer

### Brukeropprettelse
- Nyopprettede brukere får `must_change_password = 1` automatisk
- Velkomst-e-post sendes automatisk med midlertidig passord
- E-posten informerer brukeren om at passordbytte kreves ved første innlogging
- Hvis autogenerert passord brukes (tomt passordfelt) genereres 20 tilfeldige hex-tegn

### Passord-reset via admin
- `must_change_password` settes til `1` ved reset
- Alle brukerens refresh tokens revokeres
- Passordet vises **ikke** i responsen – informer brukeren via annen kanal

### RBAC-modell
- Tabeller: `qc_roles`, `qc_permissions`, `qc_role_permissions`, `qc_user_roles`
- Permissions er på formatet `resource:action` (f.eks. `admin:users`, `query:execute`)

### Forhåndsdefinerte roller
| Rolle | Rettigheter |
|-------|-------------|
| `admin` | `admin:users`, `admin:roles`, `query:execute`, `query:read`, `feedback:write` |
| `analyst` | `query:execute`, `query:read`, `feedback:write` |
| `viewer` | `query:read` |

### CORS
DELETE-metoden må være med i API Gateway sin `allowed_methods` liste.

### Path-parsing
Ruting skjer via parsing av `fn-http-request-url` header.

## Miljøvariabler

| Variabel | Beskrivelse |
|----------|-------------|
| `DB_USER` | Oracle DB bruker |
| `DB_DSN` | Oracle DSN |
| `WALLET_SECRET_OCID` | Vault OCID for wallet zip |
| `DBPASS_SECRET_OCID` | Vault OCID for DB passord |
| `WALLETPASS_SECRET_OCID` | Vault OCID for wallet passord |
| `JWT_SECRET_OCID` | Vault OCID for JWT secret |
| `SMTP_PASSWORD_SECRET_OCID` | Vault OCID for SMTP passord |
| `SMTP_HOST` | `smtp.email.eu-frankfurt-2.oci.oraclecloud.eu` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | OCI SMTP brukernavn (langt OCID-format) |
| `EMAIL_SENDER` | `noreply@elcarocloud.no` |
| `FRONTEND_URL` | `https://querychat.elcarocloud.no` |
| `LOG_LEVEL` | `INFO` (sett `DEBUG` ved feilsøking) |

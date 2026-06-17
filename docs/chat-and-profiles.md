# chat-handler og profile-handler

## Filer

```
application/
  chat-handler/       func.py  requirements.txt  Dockerfile  func.yaml
  profile-handler/    func.py  requirements.txt  Dockerfile  func.yaml
  database/
    17_create_qc_chat_tables.sql
    18_create_qc_user_settings.sql
    19_seed_settings_defaults.sql
terraform/infra/
  functions_patch.tf          → limes inn i functions.tf
  apigateway_routes_patch.tf  → limes inn i apigateway.tf
```

---

## Deploy-rekkefølge

### 1. Database

```bash
# Kjør i ADB SQL*Plus eller SQLcl
@application/database/17_create_qc_chat_tables.sql
@application/database/18_create_qc_user_settings.sql
@application/database/19_seed_settings_defaults.sql
```

### 2. Terraform-patching

**functions.tf** – lim inn innholdet fra `functions_patch.tf` på slutten av filen (etter `admin_handler`-blokken, men før `# ── Variables`-kommentaren).

**apigateway.tf** – lim inn de fem `routes { ... }`-blokkene fra `apigateway_routes_patch.tf` inn i `oci_apigateway_deployment "v1" → specification`. `/admin/profiles/{path*}`-ruten MÅ plasseres **før** den eksisterende `/admin/{path*}`-ruten.

Deretter:
```bash
cd terraform/infra
terraform plan
terraform apply
```

### 3. Build og push

`deploy-function.sh` oppdaterer `image_digest` i `functions.tf` automatisk. Kjør i rekkefølge:

```bash
bash scripts/deploy-function.sh chat-handler
bash scripts/deploy-function.sh profile-handler
```

---

## API-referanse

### chat-handler

| Metode | Sti | Beskrivelse |
|--------|-----|-------------|
| GET | `/v1/chats` | List samtaler (maks 100, sortert nyeste øverst) |
| POST | `/v1/chats` | Opprett samtale `{"title?": "..."}` |
| DELETE | `/v1/chats/{id}` | Slett samtale + alle meldinger (CASCADE) |
| GET | `/v1/chats/{id}/messages` | Hent meldinger (kronologisk) |
| POST | `/v1/chats/{id}/messages` | Legg til melding `{"role": "user\|assistant\|error", "content": "..."}` |
| PUT | `/v1/chats/{id}/title` | Oppdater tittel `{"title": "..."}` |

`{id}` er 32-tegns lowercase hex (RAWTOHEX av RAW(16) UUID).

Auto-tittel: første `user`-melding settes som tittel (maks 80 tegn) hvis tittelen fortsatt er "Ny samtale".

### profile-handler

Krever `admin:profiles` i JWT `permissions`-arrayen.

| Metode | Sti | Beskrivelse |
|--------|-----|-------------|
| GET | `/v1/admin/profiles/settings` | Alle nøkler med defaults og metadata |
| GET | `/v1/admin/profiles/{user_id}` | Merged view for én bruker |
| PUT | `/v1/admin/profiles/{user_id}/{key}` | Sett verdi `{"value": "..."}` |
| DELETE | `/v1/admin/profiles/{user_id}/{key}` | Tilbakestill til standard (sletter rad) |

---

## Datamodell

### qc_chat_sessions
- `id` RAW(16) – SYS_GUID(), returneres som RAWTOHEX
- `user_id` VARCHAR2(32) – FK til qc_users.id
- `title` VARCHAR2(255) – auto-settes fra første melding
- `updated_at` – oppdateres ved hver nye melding

### qc_chat_messages
- `id` RAW(16)
- `session_id` RAW(16) – CASCADE DELETE
- `role` – user | assistant | error
- `content` CLOB

### qc_settings_defaults
- `key` – f.eks. `ui.theme`, `query.show_sql`
- `value` – standardverdi
- `category` – ui | query | notifications

### qc_user_settings
- PK: `(user_id, key)` – ingen rad = bruk default, DELETE = tilbakestill

---

## Merk: user_id-type

`qc_users.id` er VARCHAR2(32) hex (ikke RAW) basert på `08_auth_users.sql`-mønsteret i dette repoet. `qc_chat_sessions.user_id` arver denne typen. `qc_user_settings.user_id` likedan.

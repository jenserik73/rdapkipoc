# Testdokumentasjon – Metadata API

Verifisering av `GET /admin/metadata/objects/{owner}/{name}` og
`POST /admin/metadata/annotations` i `admin-handler`.

Alle tester kjørt mot `https://api.elcarocloud.no/v1` med Administrator-bruker.

---

## Oppsett

```bash
TOKEN=$(curl -s -X POST "https://api.elcarocloud.no/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "jemyhr@sykehuspartner.no", "password": "<passord>"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
```

Token utløper etter 15 minutter – kjør denne på nytt ved `401 Ugyldig eller utløpt token`.

---

## Test 1 – GET: Hent objektdata

### 1a. Tabell med eksisterende annotations og comments

```bash
curl -s -X GET "https://api.elcarocloud.no/v1/admin/metadata/objects/QUERYCHAT/KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

**Forventet:** `ok: true`, `columns` (11 kolonner), `existing_comments` (tabell + alle kolonner),
`existing_annotations` (BELOEP/DESCRIPTION, BELOEP/JOIN COLUMN, STILLINGSGRUPPE/DESCRIPTION),
`qc_annotations: []`

**Resultat:** ✅

---

### 1b. Tabell uten annotations

```bash
curl -s -X GET "https://api.elcarocloud.no/v1/admin/metadata/objects/QUERYCHAT/KI_GRUNNLAG_ORACLE_RDAP_BEMANNING" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

**Forventet:** `ok: true`, `existing_annotations: []`, `qc_annotations: []`

**Resultat:** ✅

---

### 1c. Ugyldig tabell

```bash
curl -s -X GET "https://api.elcarocloud.no/v1/admin/metadata/objects/QUERYCHAT/FINNES_IKKE" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

**Forventet:** `ok: false`, HTTP 404, feilmelding om at objektet ikke finnes

**Resultat:** ✅
```json
{"ok": false, "error": "Objekt QUERYCHAT.FINNES_IKKE finnes ikke eller har ingen kolonner"}
```

---

## Test 2 – POST: Ny ANNOTATION (ADD)

```bash
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK","column_name":"LOENNSGRUPPE","sync_target":"ANNOTATION","annotation_name":"DESCRIPTION","annotation_value":"Aarsak til utbetaling. Fast lonn = Grunnlonn/basislonn. Ekstraarbeid = Mertid/timeonn, Overtid.","status":"AKTIV"}' \
  | python3 -m json.tool
```

**Forventet:** `ok: true`, `ddl` inneholder `ALTER TABLE ... MODIFY "LOENNSGRUPPE" ANNOTATIONS (ADD DESCRIPTION '...')`

**Resultat:** ✅
```json
{
  "ok": true,
  "id": "46D9099CF6B1E8A19780D0095B7FE363",
  "ddl": ["ALTER TABLE \"QUERYCHAT\".\"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK\" MODIFY \"LOENNSGRUPPE\" ANNOTATIONS (ADD DESCRIPTION 'Aarsak til utbetaling. Fast lonn = Grunnlonn/basislonn. Ekstraarbeid = Mertid/timeonn, Overtid.')"]
}
```

---

## Test 3 – POST: Ny COMMENT (COMMENT ON TABLE)

```bash
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_BEMANNING","column_name":null,"sync_target":"COMMENT","annotation_value":"Bemanningsdata per helseforetak og stilling.","status":"AKTIV"}' \
  | python3 -m json.tool
```

**Forventet:** `ok: true`, `ddl` inneholder `COMMENT ON TABLE ... IS '...'`

**Resultat:** ✅
```json
{
  "ok": true,
  "id": "009B5A9337970F6BA0A9E6F0465E769E",
  "ddl": ["COMMENT ON TABLE \"QUERYCHAT\".\"KI_GRUNNLAG_ORACLE_RDAP_BEMANNING\" IS 'Bemanningsdata per helseforetak og stilling.'"]
}
```

---

## Test 4 – POST: UTKAST (ingen DDL)

```bash
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK","column_name":"FUNKSJONSOMRAADE","sync_target":"ANNOTATION","annotation_name":"DESCRIPTION","annotation_value":"Utkast - ikke publisert ennaa.","status":"UTKAST"}' \
  | python3 -m json.tool
```

**Forventet:** `ok: true`, `ddl: []` (ingen DDL for UTKAST-status)

**Resultat:** ✅
```json
{"ok": true, "id": "16E49CDF8654083DAE7E6F467DD669CA", "ddl": []}
```

---

## Test 5 – POST: Oppdater eksisterende AKTIV annotasjon (REPLACE)

Krever at raden fra test 2 er AKTIV. Bruker `id` fra test 2.

```bash
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"id":"46D9099CF6B1E8A19780D0095B7FE363","object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK","column_name":"LOENNSGRUPPE","sync_target":"ANNOTATION","annotation_name":"DESCRIPTION","annotation_value":"OPPDATERT: Aarsak til utbetaling. Fast lonn = Grunnlonn. Ekstraarbeid = Overtid, Mertid.","status":"AKTIV"}' \
  | python3 -m json.tool
```

**Forventet:** `ok: true`, `ddl` inneholder `REPLACE DESCRIPTION '...'`
(ikke `DROP+ADD` – Oracle `ORA-11602` forbyr kombinasjon av ADD/DROP for samme annotasjonsnavn i én setning)

**Resultat:** ✅
```json
{
  "ok": true,
  "id": "46D9099CF6B1E8A19780D0095B7FE363",
  "ddl": ["ALTER TABLE \"QUERYCHAT\".\"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK\" MODIFY \"LOENNSGRUPPE\" ANNOTATIONS (REPLACE DESCRIPTION 'OPPDATERT: Aarsak til utbetaling. Fast lonn = Grunnlonn. Ekstraarbeid = Overtid, Mertid.')"]
}
```

---

## Test 6 – POST: Arkiver AKTIV annotasjon (DROP)

```bash
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"id":"46D9099CF6B1E8A19780D0095B7FE363","object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK","column_name":"LOENNSGRUPPE","sync_target":"ANNOTATION","annotation_name":"DESCRIPTION","annotation_value":"OPPDATERT: Aarsak til utbetaling. Fast lonn = Grunnlonn. Ekstraarbeid = Overtid, Mertid.","status":"ARKIVERT"}' \
  | python3 -m json.tool
```

**Forventet:** `ok: true`, `ddl` inneholder kun `DROP DESCRIPTION`

**Resultat:** ✅
```json
{
  "ok": true,
  "id": "46D9099CF6B1E8A19780D0095B7FE363",
  "ddl": ["ALTER TABLE \"QUERYCHAT\".\"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK\" MODIFY \"LOENNSGRUPPE\" ANNOTATIONS (DROP DESCRIPTION)"]
}
```

---

## Test 7 – POST: Valideringsfeil

### 7a. Mangler annotation_name for ANNOTATION

```bash
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK","column_name":"BELOEP","sync_target":"ANNOTATION","annotation_value":"Test","status":"AKTIV"}' \
  | python3 -m json.tool
```

**Forventet:** `ok: false`, HTTP 400

**Resultat:** ✅
```json
{"ok": false, "error": "annotation_name er paakrevd for sync_target='ANNOTATION'"}
```

---

### 7b. Duplikat-blokkering (annotasjon finnes allerede)

Oracle tillater teknisk sett flere annotasjoner med samme navn på samme kolonne
(`ADD` kolliderer ikke i Oracle). Vi blokkerer dette på applikasjonsnivå via
`UNIQUE`-indeksen `QC_OA_UQ` på `qc_object_annotations`, og fanger
`oracledb.IntegrityError` med en forståelig feilmelding.

```bash
# BELOEP/DESCRIPTION finnes allerede fra verifiseringsarbeidet
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK","column_name":"BELOEP","sync_target":"ANNOTATION","annotation_name":"DESCRIPTION","annotation_value":"Duplikat-test.","status":"AKTIV"}' \
  | python3 -m json.tool
```

**Forventet:** `ok: false`, HTTP 400, forståelig feilmelding (ikke rå Oracle-feil)

**Resultat:** ✅
```json
{
  "ok": false,
  "error": "En annotasjon med samme type og navn finnes allerede for KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK.BELOEP. Bruk oppdatering (send id) i stedet for aa opprette ny."
}
```

---

## Test 8 – POST: NONE (internt notat, ingen DDL)

```bash
curl -s -X POST "https://api.elcarocloud.no/v1/admin/metadata/annotations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  --data-raw '{"object_owner":"QUERYCHAT","object_name":"KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER","column_name":"AKUTTMOTTAK","sync_target":"NONE","notat_type":"DATAKVALITET","annotation_value":"Kjent ETL-feil: ca 1-12% av radene har forskjovne/feilplasserte verdier.","status":"AKTIV"}' \
  | python3 -m json.tool
```

**Forventet:** `ok: true`, `ddl: []`

**Resultat:** ✅
```json
{"ok": true, "id": "F734530034B5D5522A760556F44650AA", "ddl": []}
```

---

## Sammendrag

| Test | Scenario | DDL-type | Status |
|---|---|---|---|
| 1a | GET tabell med annotations/comments | – | ✅ |
| 1b | GET tabell uten annotations | – | ✅ |
| 1c | GET ugyldig tabell | – | ✅ 404 |
| 2 | Ny ANNOTATION, status=AKTIV | `ADD` | ✅ |
| 3 | Ny COMMENT, tabellnivå | `COMMENT ON TABLE` | ✅ |
| 4 | Ny ANNOTATION, status=UTKAST | `[]` | ✅ |
| 5 | Oppdater AKTIV→AKTIV, samme navn | `REPLACE` | ✅ |
| 6 | Arkiver AKTIV→ARKIVERT | `DROP` | ✅ |
| 7a | Valideringsfeil: mangler annotation_name | – | ✅ 400 |
| 7b | Duplikat-blokkering via QC_OA_UQ | – | ✅ 400 |
| 8 | NONE/DATAKVALITET (internt notat) | `[]` | ✅ |

---

## Viktige Oracle-funn fra testingen

### ORA-11602: DROP+ADD av samme annotasjonsnavn ikke tillatt i én setning

Oracle tillater ikke å kombinere `DROP` og `ADD` for samme annotasjonsnavn
i én `ALTER TABLE ... ANNOTATIONS`-setning:

```sql
-- Feiler med ORA-11602:
ALTER TABLE t MODIFY col ANNOTATIONS (DROP DESCRIPTION, ADD DESCRIPTION 'ny verdi')
```

**Løsning:** Bruk `REPLACE` ved oppdatering av eksisterende aktiv annotasjon:

```sql
-- Korrekt:
ALTER TABLE t MODIFY col ANNOTATIONS (REPLACE DESCRIPTION 'ny verdi')
```

Implementert i `build_ddl_statements()` i `metadata_sync.py`:
- `was_active=True` + `is_active=True` + samme annotasjonsnavn → `REPLACE`
- `was_active=True` + `is_active=True` + ulikt annotasjonsnavn → `DROP` gammelt + `ADD` nytt
- `was_active=False` + `is_active=True` → `ADD`
- `was_active=True` + `is_active=False` → `DROP`

### Oracle tillater duplikate annotasjonsnavn (ADD kolliderer ikke)

Oracle's `ADD`-syntaks kolliderer ikke med eksisterende annotasjoner av samme navn –
den legger til en ekstra annotasjon. To `DESCRIPTION`-annotasjoner på samme kolonne
er teknisk mulig, men gir ikke-deterministisk LLM-oppførsel.

**Løsning:** `QC_OA_UQ`-indeksen på `qc_object_annotations` forhindrer duplikate
rader på DML-nivå. `oracledb.IntegrityError` fanges og returnerer HTTP 400 med
forståelig feilmelding i stedet for rå `ORA-00001`.

# Arkitekturplan: Databaseannotasjoner for NL2SQL (revidert)

**Status:** Revidert etter verifiseringsfase (se "Grunnlag" nedenfor)
**Prosjekt:** QueryChat, Sykehuspartner
**Repo:** jenserik73/rdapkipoc

---

## 1. Grunnlag - hva verifiseringen viste

Før denne revisjonen var planen å bygge `qc_object_annotations` rundt `COMMENT ON` som primær synk-mekanisme. Verifisering mot ADB (Oracle 23.26.2.2.0, oc19/eu-frankfurt-2) endret dette bildet:

- **`COMMENT ON` er allerede i omfattende bruk** for de fire `KI_GRUNNLAG_ORACLE_RDAP_*`-tabellene, med svært detaljert forretningslogikk, formler og filtreringshint. `comments: true` er satt på `QUERYCHAT_PROFILE`.
- **`ANNOTATIONS` (23ai) er aktivert** (`annotations: true`) men ubrukt (0 rader i `USER_ANNOTATIONS_USAGE`).
- **Test: `ANNOTATIONS (DESCRIPTION '...')` med direktiv/SQL-syntaks-fraseologi ga 100% korrekt SQL-generering** for en formel (`BELOEP`/`MAANEDSVERK_BRUTTO`-beregning) som `COMMENT` alene ikke fikset, selv om samme info lå i kommentaren.
- **Test: `ANNOTATIONS (DESCRIPTION ...)` for kategori→verdiliste-mapping** (`STILLINGSGRUPPE` "Sykepleiere totalt" → 8 spesifikke verdier, skrevet som ferdig `IN (...)`-syntaks) er **pålitelig i isolasjon** - 3 av 3 korrekte resultater på tvers av tre forskjellige prompt-formuleringer i en oppfølgingstest. Var **upålitelig** kun i det opprinnelige tilfellet der spørsmålet *samtidig* krevde en annen kompleks `DESCRIPTION`-annotasjon (BELOEP-formelen) på samme tabell. Konklusjon: slike annotasjoner er solide, men bør testes spesifikt mot prompts som kombinerer flere komplekse regler på samme tabell.
- **Non-determinisme er reell selv ved `temperature: 0`.** Et mønster som var 100% korrekt i en tidligere test (HELSEFORETAK-mapping fra fullt navn til forkortelse) **regredierte** i en senere, identisk gjentakelse av samme prompt (genererte `HELSEFORETAK = 'Oslo universitetssykehus HF'`, en verdi som ikke finnes i kolonnen). Ingen enkelttest - uansett hvor "100%" den ser ut - bør tolkes som en permanent garanti.
- **Dataprofilering avdekket reelle datakvalitetsproblemer** som ingen annotasjon kan fikse (se eget dokument `datakvalitet_liggetimer.md`/`.docx`, sendt til dataeier 2026-06-15): `POLIKLINISK_LT` har 11,6% ikke-numerisk innhold, `COLNAME_COL30/31/32_MISSING` er ikke tomme som kommentert, og flere kolonner i `LIGGETIMER` inneholder sannsynlig feilplasserte verdier fra en ETL-kolonneforskyvning.
- **sqlcl-quirk** (verdt å huske for fremtidige scripts/admin-handler-tester): en `PROMPT <tekst>`-linje rett før en `SELECT`-setning kan svelge setningen. Unngå `PROMPT` rett før `SELECT` - bruk SQL-kommentarer (`/* ... */`) inni setningen for inline-beskrivelser i scripts.

**Konklusjon:** Begge mekanismer beholdes og brukes komplementært, etter en beslutningsmatrise (avsnitt 4). `qc_object_annotations` generaliseres til å støtte begge synk-mål, pluss et tredje "ikke-synk"-utfall (flagg for view-kandidat / kjent datakvalitetsproblem).

---

## 2. Datamodell: `qc_object_annotations`

```sql
CREATE TABLE qc_object_annotations (
  id               VARCHAR2(32) PRIMARY KEY,        -- generert (ikke RAW - jf. oracledb-begrensning)
  object_owner     VARCHAR2(128) NOT NULL,
  object_name      VARCHAR2(128) NOT NULL,
  column_name      VARCHAR2(128),                   -- NULL = tabellnivå
  sync_target      VARCHAR2(16)  NOT NULL,           -- 'COMMENT' | 'ANNOTATION' | 'NONE'
  annotation_name  VARCHAR2(128),                    -- kun for sync_target='ANNOTATION':
                                                       -- DESCRIPTION, ALIASES, UNITS, "JOIN COLUMN", ...
  annotation_value VARCHAR2(4000) NOT NULL,
  notat_type       VARCHAR2(32),                     -- kun for sync_target='NONE':
                                                       -- 'DATAKVALITET' | 'VIEW_KANDIDAT' | 'TODO'
  status           VARCHAR2(16) DEFAULT 'AKTIV'      -- 'AKTIV' | 'UTKAST' | 'ARKIVERT'
                    CHECK (status IN ('AKTIV','UTKAST','ARKIVERT')),
  updated_by       VARCHAR2(32),
  updated_at       TIMESTAMP DEFAULT SYSTIMESTAMP,
  CONSTRAINT qc_oa_sync_target_chk
    CHECK (sync_target IN ('COMMENT','ANNOTATION','NONE')),
  CONSTRAINT qc_oa_annotation_name_chk
    CHECK (sync_target != 'ANNOTATION' OR annotation_name IS NOT NULL)
);

CREATE UNIQUE INDEX qc_oa_uq ON qc_object_annotations (
  object_owner, object_name,
  NVL(column_name, '*'),
  sync_target,
  NVL(annotation_name, '*')
);
```

**Endringer fra opprinnelig forslag:**

- `synonyms`-kolonnen er fjernet - synonymer dekkes nå av `sync_target='ANNOTATION'`, `annotation_name='ALIASES'`.
- Generalisert `annotation_name`/`annotation_value` istedenfor ett fast `annotation`-felt - tillater flere navngitte annotasjoner per objekt/kolonne (DESCRIPTION, ALIASES, UNITS, "JOIN COLUMN", osv.), slik Oracles AI-enrichment-konvensjon legger opp til.
- `sync_target='NONE'` + `notat_type` gir admin et sted å registrere observasjoner som *ikke* skal synkes til databasen - f.eks. "kjent datakvalitetsproblem, se [lenke]" eller "kandidat for view". Disse vises i UI men påvirker ikke `COMMENT`/`ANNOTATIONS`.
- `status='UTKAST'` lar admin lagre noe uten å synke det til databasen ennå (nyttig for nye tabeller under onboarding, der admin vil iterere før publisering).

---

## 3. Synk-prosess

Trigges ved lagring i admin-UI (rask DDL, ingen kø nødvendig):

| `sync_target` | DDL generert |
|---|---|
| `COMMENT`, tabellnivå | `COMMENT ON TABLE <owner>.<table> IS '<value>'` |
| `COMMENT`, kolonnenivå | `COMMENT ON COLUMN <owner>.<table>.<column> IS '<value>'` |
| `ANNOTATION`, tabellnivå | `ALTER TABLE <owner>.<table> ANNOTATIONS (ADD/DROP <annotation_name> '<value>')` |
| `ANNOTATION`, kolonnenivå | `ALTER TABLE <owner>.<table> MODIFY <column> ANNOTATIONS (ADD/DROP <annotation_name> '<value>')` |
| `NONE` | Ingen DDL - kun lagret i `qc_object_annotations` |

**Implementasjonsnotater:**

- `annotation_name`-verdier med mellomrom (f.eks. `JOIN COLUMN`) må kvotes med doble fnutter i generert DDL: `"JOIN COLUMN"`.
- Enkle fnutter i `annotation_value` escapes til `''` (standard SQL).
- Ved oppdatering av en eksisterende `ANNOTATION`-rad: generer `DROP <name>` + `ADD <name> '<ny_verdi>'` i samme `ALTER TABLE`-setning (annotations støtter ikke "REPLACE" direkte).
- `status='ARKIVERT'`: generer `DROP`-DDL for `ANNOTATION`/fjern `COMMENT` (sett til `NULL` via `COMMENT ON ... IS ''`), men behold raden i `qc_object_annotations` for historikk.

---

## 4. Beslutningsmatrise: hvilken kanal?

Admin-UI bør vise denne som hjelpetekst/wizard når en ny annotasjon lages:

| Type informasjon | Kanal | Eksempel | Begrunnelse |
|---|---|---|---|
| Generell beskrivelse av tabell/kolonne, forretningskontekst | `COMMENT` | "Bemanningsdata fra turnus/vaktplansystem per uke..." | Allerede etablert, fungerer godt for generell kontekst (Test 1: 100%) |
| Presis formel/beregning | `ANNOTATION` → `DESCRIPTION`, skrevet som SQL-syntaks | "Korrekt formel: SUM(beloep)/NULLIF(SUM(maanedsverk_brutto),0)" | `ANNOTATIONS` ga sterkere gjennomslag enn `COMMENT` for samme info (Test: 100% vs. feil) |
| "Bruk aldri X, bruk alltid Y"-regel | `ANNOTATION` → `DESCRIPTION`, direktiv fraseologi | "AVG(beloep) skal ALDRI brukes for gjennomsnittslønn" | Samme som over |
| Synonymer/alternative navn for kolonne/tabell | `ANNOTATION` → `ALIASES` | "rad-id, nøkkel" for en ID-kolonne | Offisiell Oracle-konvensjon for AI-enrichment |
| Måleenhet | `ANNOTATION` → `UNITS` | "NOK", "timer" | Offisiell Oracle-konvensjon |
| Foretrukket join-relasjon | `ANNOTATION` → `"JOIN COLUMN"` | "HELSEFORETAK joines mot DEPARTMENT.HELSEFORETAK" | Offisiell Oracle-konvensjon, ikke testet ennå men dokumentert use-case |
| Kategori → verdiliste-mapping (f.eks. "X totalt" = flere verdier) | `ANNOTATION` → `DESCRIPTION` med ferdig `IN (...)`-syntaks (SQL-literal, ikke forklarende setning) | "Sykepleiere totalt" → `STILLINGSGRUPPE IN (...)` | Pålitelig i isolasjon (3/3 i oppfølgingstest). **Test eksplisitt mot prompts som også trigger andre komplekse `DESCRIPTION`-annotasjoner på samme tabell** - det er der konflikt kan oppstå, ikke i selve kategori-annotasjonen |
| Kjent datakvalitetsproblem | `sync_target='NONE'`, `notat_type='DATAKVALITET'` | "11,6% av POLIKLINISK_LT er ikke-numerisk, se [rapport]" | Kan ikke løses med metadata - kun til internt bruk/dokumentasjon |
| "Denne logikken bør være en view" | `sync_target='NONE'`, `notat_type='VIEW_KANDIDAT'` | "STILLINGSGRUPPE-kategorisering bør være CASE-kolonne i view" | Markerer for fremtidig arbeid utenfor annotasjon-rammeverket |

---

## 5. Admin-UI: flow

### 5.1 Eksisterende fane-struktur
Ny fane "Metadata" legges til ved siden av "Brukere"/"Roller" i `querychat.html`, bak ny permission `admin:metadata`.

### 5.2 Hovedvisning: Objektliste
- Liste over tabeller/views fra `ALL_TABLES`/`ALL_TAB_COLUMNS` (filtrert til `object_list` i AI-profilen, pluss mulighet til å bla i hele skjemaet for "ikke-aktiverte" tabeller)
- Ekspanderbar til kolonner
- Per objekt/kolonne: viser eksisterende `COMMENT` (read-only visning, kan redigeres - skriver til `qc_object_annotations` med `sync_target='COMMENT'`) og eksisterende `ANNOTATIONS` fra `USER_ANNOTATIONS_USAGE`
- "Legg til annotasjon"-knapp → velg `sync_target` + `annotation_name` (dropdown med DESCRIPTION/ALIASES/UNITS/"JOIN COLUMN"/Egendefinert) → fritekstfelt, med beslutningsmatrisen (avsnitt 4) som inline hjelpetekst

### 5.3 Onboarding-flow for nye tabeller ("Aktiver for QueryChat")

Trigges når admin velger en tabell som ikke er i `object_list`:

1. **Skjemaoversikt**: kolonner, datatyper, eksisterende `COMMENT`/`ANNOTATIONS` (ofte tomt for nye tabeller)
2. **Automatisk profilering** (kjøres on-demand, vises progressivt):
   - Steg A (instant): `USER_TAB_COL_STATISTICS` → `NUM_DISTINCT`/`NUM_NULLS`/`AVG_COL_LEN` per kolonne. Flagger kolonner med `NUM_DISTINCT < N` (konfigurerbar, f.eks. 50) som "kategoriske - vis distinct-verdier?"
   - Steg B (lett, `SAMPLE(1)`): for flaggede kolonner, `GROUP BY`-spørring som viser faktiske distinct-verdier + frekvens. Admin ser dette **før** de skriver en `ALIASES`/`DESCRIPTION`-annotasjon - unngår STILLINGSGRUPPE-typen feil (dokumentere en kategori som ikke finnes som verdi)
   - Steg C (valgfritt, kan ta tid på store tabeller): datakvalitetssjekk for `VARCHAR2`-kolonner som "ser numeriske ut" (regex-sjekk for ikke-numerisk innhold) - flagger `POLIKLINISK_LT`-type problemer automatisk
   - Steg D (valgfritt): kryss-tabell-konsistenssjekk for kolonner med samme navn i andre aktiverte tabeller (f.eks. `HELSEFORETAK`) - foreslår delt `ALIASES`
3. **AI-assistert utkast** (stretch goal): bruk `DBMS_CLOUD_AI.GENERATE` til å foreslå `DESCRIPTION`/`ALIASES`-tekst basert på kolonnenavn + profileringsresultat fra steg B/C. Lagres som `status='UTKAST'` - admin redigerer/godkjenner før publisering.
4. **Publisering**: admin velger hvilke annotasjoner som settes til `status='AKTIV'` (→ synkes til DB) vs. lagres som `NONE`/notat. Til slutt: oppdater `object_list` i AI-profilen via `DBMS_CLOUD_AI.SET_ATTRIBUTE`.

### 5.4 Profileringsverktøy som frittstående funksjon
Selv for *allerede aktiverte* tabeller bør profileringsverktøyet (steg A-D) være tilgjengelig som en "Analyser kolonne"-knapp per kolonne - nyttig for periodisk revalidering (data endrer seg, som vi så med `COLNAME_COL3X_MISSING`-kommentaren som ble feil over tid).

---

## 6. Backend

- Nytt admin-handler-endepunkt (eller egen `metadata-handler`-funksjon):
  - `GET /admin/metadata/objects` - liste tabeller/views + status (aktivert i `object_list`?)
  - `GET /admin/metadata/objects/{owner}/{name}` - kolonner + eksisterende `COMMENT`/`ANNOTATIONS` + `qc_object_annotations`-rader
  - `GET /admin/metadata/objects/{owner}/{name}/profile` - profileringsresultat (steg A-D), evt. med `?deep=true` for steg C/D
  - `POST /admin/metadata/annotations` - opprett/oppdater rad i `qc_object_annotations` (validerer `sync_target`/`annotation_name`-kombinasjon, genererer og kjører DDL hvis `status='AKTIV'`)
  - `POST /admin/metadata/object-list` - legg til/fjern tabell fra AI-profilens `object_list`
- Ny permission `admin:metadata` i `QC_PERMISSIONS`/`QC_ROLE_PERMISSIONS`
- VARCHAR2(32) for `id`-kolonnen, generert i Python (jf. oracledb RAW-begrensning - samme mønster som øvrige QC-tabeller)

---

## 8. Feedback-loop / agentbasert kontinuerlig forbedring (utforsket, delvis blokkert)

Utforsket som mulig "lag 3" på toppen av annotasjonsrammeverket: bruke `QUERYCHAT_FEEDBACK` + Select AI sine innebygde feedback-/agent-mekanismer til å kontinuerlig forbedre annotasjoner basert på reelle brukerspørsmål.

**Tilgjengelighet bekreftet på instansen** (`23.26.2.2.0`, oc19):
- `DBMS_CLOUD_AI_AGENT` (Select AI Agent, ReAct-rammeverk: Planning/Tool Use/Reflection/Memory) - pakken finnes, `EXECUTE` er grantet direkte, 46 subprogrammer inkl. `CREATE_TEAM`/`CREATE_TOOL`/`SQL_TOOL`/`RUN_TEAM`. **Ikke videre testet**, men prinsipielt levedyktig.
- `DBMS_CLOUD_AI.FEEDBACK` - pakken finnes, `EXECUTE` er grantet, signaturen tillater å sende `sql_text` (CLOB) direkte sammen med `feedback_content` (korrigert SQL) - ingen behov for å finne `sql_id` separat.

**Blokkering funnet:**
`DBMS_CLOUD_AI.FEEDBACK` feiler med `ORA-20404: Object not found` mot en `embedText`-endepunkt-URL som inneholder en usubstituert literal `my$cloud_domain`. Dette er **bekreftet som en kjent Oracle-side plattformbug** (identisk feilmønster rapportert av andre brukere på Cloud Customer Connect, på en annen Select AI-action i en annen region) - ikke en konfigurasjonsfeil på vår side. Samme kategori problem som tidligere observert med Resource Principal for ADB i oc19: nyere "26ai"-funksjonalitet som ikke er fullstendig rullet ut i alle realmer/regioner.

**Sekundærfunn fra samme testrunde** (se avsnitt 1, oppdatert):
- STILLINGSGRUPPE-kategori-annotasjonen er mer pålitelig enn først antatt (pålitelig i isolasjon)
- Ny non-determinisme-observasjon (HELSEFORETAK-regresjon på en tidligere "100%"-prompt)

**Konklusjon og status:**
- `DBMS_CLOUD_AI.FEEDBACK`-basert forbedringsloop: **lagt på vent**, blokkert av ekstern plattformbug. Revurder periodisk (eller etter SR til Oracle Support) - krever ingen arkitekturendring fra vår side når/hvis bugen fikses, siden `FEEDBACK` er additiv til eksisterende `comments`/`annotations`-oppsett.
- `DBMS_CLOUD_AI_AGENT`-basert "metadata-kurator-agent" (avsnitt 5.3, steg 3 / "AI-assistert utkast"): prinsipielt levedyktig (pakke + privilegier OK), men ikke testet. Forblir et **stretch-mål for senere iterasjon**, ikke en forutsetning for `qc_object_annotations` v1.
- Ingen endringer i datamodell (avsnitt 2) eller synk-prosess (avsnitt 3) er nødvendig som følge av denne utforskningen - `status='UTKAST'`-mekanismen er allerede designet for å ta imot forslag fra en fremtidig agent, manuelt eller automatisk.

---

## 9. Åpne punkter

- [ ] `"JOIN COLUMN"`-annotasjonen er ikke testet med en faktisk kryss-tabell-spørring (kun satt på en enkelt-tabell-kolonne i testen). Bør verifiseres med en prompt som krever JOIN mellom to `KI_GRUNNLAG_*`-tabeller.
- [ ] Terskel for "kategorisk kolonne" i profilering (forslag: `NUM_DISTINCT < 50`) bør justeres basert på erfaring.
- [ ] AI-assistert utkast (5.3, steg 3) er et stretch-mål - vurder om dette tas med i første versjon eller senere iterasjon.
- [ ] `LIGGETIMER`-datakvalitetsfunnet (sendt til dataeier 2026-06-15) - avvent svar; påvirker hvilke `notat_type='DATAKVALITET'`-annotasjoner som faktisk skrives for denne tabellen.
- [ ] Avklar terskel/strategi for når full-scan-profilering (steg C) er greit å trigge fra UI på svært store tabeller (49M+ rader i `HR_MNDVERK`) - timeout-risiko i admin-handler (OCI Function-tidsbegrensning).
- [ ] **Regresjonstest-suite**: gitt at selv "100%"-mønstre kan regrediere ved identisk gjentakelse (HELSEFORETAK-funnet i avsnitt 8), bør en liten samling kjente prompts (med forventet SQL-mønster) kjøres periodisk - f.eks. som del av profileringsverktøyet (5.4) eller en enkel scheduled job - for å fange opp drift i Select AI/modell-oppdateringer over tid, ikke bare ved første publisering av en annotasjon.
- [ ] Avklar om/når SR bør meldes til Oracle Support for `ORA-20404 my$cloud_domain`-bugen i `DBMS_CLOUD_AI.FEEDBACK` (avsnitt 8).

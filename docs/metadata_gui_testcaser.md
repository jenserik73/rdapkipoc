# GUI-testcaser – Metadata-fanen i QueryChat

Manuell testplan for Metadata-fanen under Administrasjon i QueryChat.
Forutsetter innlogging som bruker med `admin:metadata`-rettighet (f.eks. Administrator).

---

## Forutsetninger

- Innlogget som `jemyhr@sykehuspartner.no` (Administrator) på `https://querychat.elcarocloud.no/chat/`
- Minst én tabell i databasen har eksisterende Oracle annotations og COMMENT ON
- `qc_object_annotations`-tabellen er tilgjengelig og migrert (migrasjon 15+16)

---

## TC-01: Navigasjon til Metadata-fanen

**Beskrivelse:** Verifiser at Metadata-fanen er synlig og tilgjengelig for admin-brukere.

**Steg:**
1. Logg inn som Administrator
2. Klikk **Administrasjon** i venstre sidepanel
3. Observer fane-knappene øverst i admin-panelet

**Forventet resultat:**
- Tre faner vises: **Brukere**, **Roller**, **Metadata**
- **Metadata**-fanen er synlig med blå aktiv-markering når den klikkes
- Brukere uten `admin:metadata`-rettighet ser ikke Metadata-fanen

**Godkjent:** ☐

---

## TC-02: Metadata-fane – tomt startpunkt

**Beskrivelse:** Verifiser at fanen viser riktig startpunkt uten valgt tabell.

**Steg:**
1. Klikk på **Metadata**-fanen

**Forventet resultat:**
- Dropdown med teksten `– Velg tabell –` vises
- Informasjonstekst: "Velg en tabell for å se annotasjoner og kommentarer"
- **+ Ny annotasjon**-knapp vises øverst til høyre
- Ingen paneler eller tabelldata vises

**Godkjent:** ☐

---

## TC-03: Velg tabell – vis kolonner og kommentarer

**Beskrivelse:** Verifiser at valg av tabell laster korrekt innhold i alle tre paneler.

**Steg:**
1. Klikk på Metadata-fanen
2. Velg `KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK` i dropdown-en

**Forventet resultat:**
- **Venstre panel – Kolonner og kommentarer:**
  - Tabell-kommentar vises øverst i grå boks
  - Alle 11 kolonner listes med navn (blå monospace), datatype og kommentar
  - Kolonner uten kommentar viser kun navn og type
- **Høyre panel øverst – Oracle annotations (live):**
  - `BELOEP · DESCRIPTION` med formel-teksten
  - `BELOEP · JOIN COLUMN` med `maanedsverk_brutto`
  - `STILLINGSGRUPPE · DESCRIPTION` med IN-listen
- **Høyre panel nederst – Redigerbare annotasjoner:**
  - Eksisterende `qc_object_annotations`-rader vises med badges
  - Tommelfingerregel: "Ingen qc-annotasjoner ennå" hvis tabellen ikke har rader

**Godkjent:** ☐

---

## TC-04: Velg tabell uten annotations

**Beskrivelse:** Verifiser visning for tabell uten Oracle annotations.

**Steg:**
1. Velg `KI_GRUNNLAG_ORACLE_RDAP_BEMANNING` i dropdown-en

**Forventet resultat:**
- **Oracle annotations (live):** viser "Ingen annotations"
- **Kolonner og kommentarer:** viser kolonner med tilhørende kommentarer
- **Redigerbare annotasjoner:** viser "Ingen qc-annotasjoner ennå"

**Godkjent:** ☐

---

## TC-05: Bytt tabell – innhold oppdateres

**Beskrivelse:** Verifiser at innholdet oppdateres korrekt når annen tabell velges.

**Steg:**
1. Velg `KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK`
2. Velg deretter `KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER`

**Forventet resultat:**
- Innholdet i alle tre paneler endres til å vise data for LIGGETIMER
- LIGGETIMER har 32 kolonner (mange flere enn HR_MNDVERK)
- `AKUTTMOTTAK`-kolonnen har en `DATAKVALITET`-notat i redigerbare annotasjoner
- `ER_TEKNISK`-kolonnen vises i Oracle annotations med DESCRIPTION

**Godkjent:** ☐

---

## TC-06: Opprett ny ANNOTATION via modal

**Beskrivelse:** Verifiser at ny ANNOTATION kan opprettes med korrekt DDL.

**Steg:**
1. Velg `KI_GRUNNLAG_ORACLE_RDAP_BEMANNING`
2. Klikk **+ Ny annotasjon**
3. Velg tabell (allerede valgt fra fanen)
4. Velg kolonne: `SUM_OVERTID`
5. Type: `ANNOTATION`
6. Annotasjonsnavn: `DESCRIPTION`
7. Verdi: `Antall overtidsvakter i uken. Summer med SUM().`
8. Status: `AKTIV`
9. Klikk **Lagre**

**Forventet resultat:**
- Modal viser grønn suksessmelding: "Lagret og synket til databasen (1 DDL-setning kjørt)"
- Modal lukkes automatisk etter ~1,4 sekunder
- Panelet oppdateres og ny rad vises i "Oracle annotations (live)" for `SUM_OVERTID`
- Rad vises i "Redigerbare annotasjoner" med badge `ANNOTATION` (blå) og `AKTIV` (grønn)

**Godkjent:** ☐

---

## TC-07: Opprett ny COMMENT via modal

**Beskrivelse:** Verifiser at COMMENT ON kan settes via modal.

**Steg:**
1. Velg `KI_GRUNNLAG_ORACLE_RDAP_BEMANNING`
2. Klikk **+ Ny annotasjon**
3. Type: `COMMENT`
4. Kolonne: `SUM_EKSTRA`
5. Verdi: `Antall ekstravakter (tilkalt utover ordinær turnus).`
6. Status: `AKTIV`
7. Klikk **Lagre**

**Forventet resultat:**
- Suksessmelding vises
- `SUM_EKSTRA`-kolonnen vises nå med kommentar i **Kolonner og kommentarer**-panelet
- Rad vises i "Redigerbare annotasjoner" med badge `COMMENT` (grønn)

**Godkjent:** ☐

---

## TC-08: Opprett internt notat (NONE)

**Beskrivelse:** Verifiser at interne notater lagres uten DDL.

**Steg:**
1. Velg `KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER`
2. Klikk **+ Ny annotasjon**
3. Type: `NONE`
4. Kolonne: `COLNAME_COL30_MISSING`
5. Notattype: `DATAKVALITET`
6. Verdi: `Kolonnen inneholder faktisk data (11.6% ikke-null) til tross for kommentaren som sier den er tom. Kjent ETL-feil.`
7. Status: `AKTIV`
8. Klikk **Lagre**

**Forventet resultat:**
- Suksessmelding: "Lagret" (ingen DDL-setninger kjørt)
- Rad vises i "Redigerbare annotasjoner" med badge `NONE` (amber) og `DATAKVALITET` (amber)
- **Oracle annotations (live)** er uendret (ingen DDL kjørt)

**Godkjent:** ☐

---

## TC-09: Opprett UTKAST

**Beskrivelse:** Verifiser at UTKAST lagres uten å synke til databasen.

**Steg:**
1. Velg `KI_GRUNNLAG_ORACLE_RDAP_BEMANNING`
2. Klikk **+ Ny annotasjon**
3. Type: `ANNOTATION`
4. Kolonne: `ISO_UKE`
5. Annotasjonsnavn: `DESCRIPTION`
6. Verdi: `ISO-ukenummer 1-53. Uferdig utkast.`
7. Status: `UTKAST`
8. Klikk **Lagre**

**Forventet resultat:**
- Suksessmelding: "Lagret" (ingen DDL-setninger)
- Rad vises med badge `UTKAST` (amber) – ikke grønn AKTIV
- **Oracle annotations (live)** viser IKKE annotasjonen (den er ikke synket)

**Godkjent:** ☐

---

## TC-10: Duplikat-blokkering

**Beskrivelse:** Verifiser at systemet blokkerer opprettelse av duplikat-annotasjon.

**Steg:**
1. Velg `KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK`
2. Klikk **+ Ny annotasjon**
3. Type: `ANNOTATION`
4. Kolonne: `BELOEP`
5. Annotasjonsnavn: `DESCRIPTION`
6. Verdi: `En ny tekst som vil kollisjonere.`
7. Status: `AKTIV`
8. Klikk **Lagre**

**Forventet resultat:**
- Rød feilmelding vises i modalen: "En annotasjon med samme type og navn finnes allerede..."
- Modal forblir åpen
- Ingen endringer i databasen

**Godkjent:** ☐

---

## TC-11: Valideringsfeil – manglende felt

**Beskrivelse:** Verifiser at modalen validerer påkrevde felt.

**Steg:**
1. Klikk **+ Ny annotasjon**
2. La verdi/innhold-feltet stå tomt
3. Klikk **Lagre**

**Forventet resultat:**
- Rød feilmelding: "Fyll inn verdi/innhold"
- Modal forblir åpen

**Steg (variant 2):**
1. Type: `ANNOTATION`
2. Fyll inn verdi, men la annotasjonsnavn stå (skal allerede være forhåndsvalgt til DESCRIPTION)
3. Endre annotasjonsnavn til blank (ikke mulig via dropdown – annotation_name er alltid satt for ANNOTATION)

**Godkjent:** ☐

---

## TC-12: Arkiver annotasjon

**Beskrivelse:** Verifiser at arkivering dropper Oracle annotation og merker raden ARKIVERT.

**Forutsetning:** En AKTIV ANNOTATION-rad eksisterer (f.eks. fra TC-06).

**Steg:**
1. Velg tabellen der annotasjonen ble opprettet
2. Finn raden i "Redigerbare annotasjoner"
3. Klikk **Arkiver**
4. Bekreft i dialog

**Forventet resultat:**
- Raden vises nå med badge `ARKIVERT` (rød)
- **Publiser**-knapp vises på den arkiverte raden
- **Oracle annotations (live)** oppdateres – annotasjonen er ikke lenger synlig
- Ny rad kan nå opprettes med samme type/navn siden den aktive raden er arkivert

**Godkjent:** ☐

---

## TC-18: Publiser UTKAST

**Beskrivelse:** Verifiser at en UTKAST-rad kan publiseres til databasen via Publiser-knappen.

**Forutsetning:** En UTKAST-rad eksisterer (f.eks. fra TC-09).

**Steg:**
1. Velg tabellen der UTKAST-raden ligger
2. Finn raden med `UTKAST`-badge i "Redigerbare annotasjoner"
3. Klikk **Publiser**
4. Bekreft i dialog

**Forventet resultat:**
- Raden skifter fra `UTKAST` (amber) til `AKTIV` (grønn)
- Annotasjonen dukker opp i **Oracle annotations (live)**
- `updated_at`-tidsstempelet oppdateres
- **Arkiver**-knapp vises, **Publiser**-knapp skjules

**Godkjent:** ☐

---

## TC-19: Publiser ARKIVERT (reaktivering)

**Beskrivelse:** Verifiser at en ARKIVERT rad kan reaktiveres og legges tilbake i Oracle.

**Forutsetning:** En ARKIVERT ANNOTATION-rad eksisterer (f.eks. fra TC-12).

**Steg:**
1. Velg tabellen der den arkiverte raden ligger
2. Finn raden med `ARKIVERT`-badge i "Redigerbare annotasjoner"
3. Klikk **Publiser**
4. Bekreft i dialog

**Forventet resultat:**
- Raden skifter fra `ARKIVERT` (rød) til `AKTIV` (grønn)
- Annotasjonen dukker opp i **Oracle annotations (live)** med opprinnelig verdi
- DDL kjøres: `ALTER TABLE ... ANNOTATIONS (ADD <navn> '...')`
- **Arkiver**-knapp vises, **Publiser**-knapp skjules

**Merk:** Vil feile med duplikat-feil hvis en annen AKTIV rad med samme
type/kolonne/annotasjonsnavn allerede finnes – da må den aktive raden arkiveres først.

**Godkjent:** ☐

---

## TC-13: Kolonne-dropdown fylles fra API

**Beskrivelse:** Verifiser at kolonne-dropdown i modal fylles korrekt fra valgt tabell.

**Steg:**
1. Klikk **+ Ny annotasjon**
2. Velg tabell `KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK`
3. Observer kolonne-dropdown

**Forventet resultat:**
- Dropdown inneholder `(tabellnivå)` øverst, deretter alle 11 kolonner i tabellen
- Kolonner listes i riktig rekkefølge (HELSEFORETAK, PERIODE_ARBEIDET, osv.)
- Bytt til en annen tabell i modal – dropdown oppdateres til den nye tabellens kolonner

**Godkjent:** ☐

---

## TC-14: Synkronisering mellom modal og fanens tabell-dropdown

**Beskrivelse:** Verifiser at modal forhåndsvelger riktig tabell basert på aktiv tabellvelger.

**Steg:**
1. Velg `KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER` i fanenens dropdown
2. Klikk **+ Ny annotasjon**

**Forventet resultat:**
- Modal åpner med `KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER` forhåndsvalgt i tabell-dropdown
- Kolonne-dropdown er allerede fylt med LIGGETIMERs kolonner (fra cache)

**Godkjent:** ☐

---

## TC-15: Type-avhengige felt i modal

**Beskrivelse:** Verifiser at modal viser/skjuler riktige felt basert på valgt type.

**Steg:**
1. Åpne modal
2. Velg Type: `ANNOTATION` – observer felt
3. Bytt til Type: `COMMENT` – observer felt
4. Bytt til Type: `NONE` – observer felt

**Forventet resultat:**
- `ANNOTATION`: viser **Annotasjonsnavn**-dropdown (DESCRIPTION/ALIASES/UNITS/JOIN COLUMN), skjuler Notattype
- `COMMENT`: skjuler Annotasjonsnavn, skjuler Notattype. Hint-tekst sier "COMMENT ON overskriver..."
- `NONE`: skjuler Annotasjonsnavn, viser **Notattype**-dropdown (DATAKVALITET/VIEW_KANDIDAT/TODO)

**Godkjent:** ☐

---

## TC-16: Panel-scroll ved mange kolonner

**Beskrivelse:** Verifiser at paneler med mye innhold er scrollbare.

**Steg:**
1. Velg `KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER` (32 kolonner)
2. Observer venstre panel

**Forventet resultat:**
- Venstre panel er scrollbart (maks høyde 320px)
- Alle kolonner er tilgjengelige ved scroll
- Øvrig layout forblir stabil (ingen overflow utenfor panelet)

**Godkjent:** ☐

---

## TC-17: Tilgangskontroll – bruker uten admin:metadata

**Beskrivelse:** Verifiser at Metadata-fanen er skjult for brukere uten rettighet.

**Steg:**
1. Logg ut
2. Logg inn som en bruker med kun `analyst`-rolle
3. Klikk Administrasjon (hvis synlig)

**Forventet resultat:**
- Administrasjon-knappen i sidepanelet er ikke synlig for analyst-brukere
- Direkte API-kall til `/admin/metadata/...` gir HTTP 403

**Godkjent:** ☐

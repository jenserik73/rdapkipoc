# Brukerdokumentasjon – QueryChat Administrasjonspanel

Dokumentasjon for administratorer av QueryChat. Dekker alle funksjoner i
administrasjonspanelet, inkludert bruker- og rollehåndtering og NL2SQL-annotasjoner.

---

## Innlogging

Gå til `https://querychat.elcarocloud.no/chat/` og logg inn med e-post og passord.

- **Glemt passord:** Klikk "Glemt passord?" på innloggingsskjermen. En tilbakestillingslenke
  sendes til e-postadressen din.
- **Passordkrav:** Minimum 8 tegn.
- **Første innlogging:** Nye brukere må bytte passord ved første innlogging.

---

## Navigasjon

Etter innlogging vises chatgrensesnittet. I venstre sidepanel finner du:

| Element | Beskrivelse |
|---|---|
| **+ Ny samtale** | Start en ny NL2SQL-samtale |
| **Administrasjon** | Åpner administrasjonspanelet (kun synlig for administratorer) |
| Samtalehistorikk | Tidligere samtaler, gruppert etter dato |
| **Bytt passord** | Endre ditt eget passord |
| **Logg ut** | Logg ut av systemet |

Klikk pilen øverst til høyre i administrasjonspanelet for å gå tilbake til chat.

---

## Administrasjonspanelet

Administrasjonspanelet har tre faner:

| Fane | Rettighet | Beskrivelse |
|---|---|---|
| **Brukere** | `admin:users` | Administrer brukere |
| **Roller** | `admin:roles` | Administrer roller og rettigheter |
| **Metadata** | `admin:metadata` | Administrer NL2SQL-annotasjoner |

---

## Brukere

### Oversikt

Brukertabellen viser alle registrerte brukere med navn, e-post, roller og status.

### Opprette ny bruker

1. Klikk **+ Ny bruker**
2. Fyll inn e-postadresse og navn
3. Passord: la feltet stå tomt for automatisk generert passord, eller skriv inn et midlertidig passord
4. Klikk **Opprett**

Brukeren mottar en velkomst-e-post med innloggingsinformasjon og blir bedt om å bytte
passord ved første innlogging.

### Administrere roller for en bruker

1. Klikk **Roller** på ønsket bruker
2. Huk av/av roller i listen
3. Endringer lagres umiddelbart

### Tilbakestille passord

1. Klikk **Passord** på ønsket bruker
2. Skriv inn nytt passord, eller la feltet stå tomt for automatisk generert passord
3. Klikk **Sett passord**

Brukeren vil bli bedt om å bytte passord ved neste innlogging. Eksisterende sesjoner
ugyldiggjøres.

### Deaktivere/aktivere bruker

Klikk **Deaktiver** eller **Aktiver** på ønsket bruker. Deaktiverte brukere kan ikke logge inn,
men historikk og data bevares.

---

## Roller

### Oversikt

Rolletabellen viser alle roller med navn, beskrivelse og tilhørende rettigheter.

### Standard roller

| Rolle | Rettigheter | Beskrivelse |
|---|---|---|
| `admin` | Alle | Full tilgang til alle funksjoner |
| `analyst` | `query:execute`, `query:read`, `feedback:write` | Kan kjøre spørringer og gi tilbakemeldinger |
| `viewer` | `query:read` | Kan kun se resultater |

### Opprette ny rolle

1. Klikk **+ Ny rolle**
2. Fyll inn rollenavn (kun små bokstaver) og beskrivelse
3. Klikk **Opprett**

Tildel rettigheter til rollen via Brukere-fanen (rettigheter administreres per bruker, ikke per rolle i UI-et).

### Slette rolle

Klikk **Slett** på ønsket rolle. Dette fjerner rollen fra alle brukere som har den.

---

## Metadata – NL2SQL-annotasjoner

Metadata-fanen lar administratorer legge til, redigere og arkivere annotasjoner som
forbedrer NL2SQL-tolkningen i QueryChat. Annotasjoner gir LLM-modellen ekstra kontekst
om tabeller og kolonner i databasen.

### Hva er annotasjoner?

QueryChat bruker to mekanismer for å gi LLM-modellen kontekst:

| Mekanisme | Beskrivelse | Eksempel |
|---|---|---|
| **COMMENT ON** | Oracle-kommentar på tabell/kolonne. God for generell kontekstuell beskrivelse. | Forklaring av hva en kolonne inneholder |
| **ANNOTATIONS** | Oracle 23ai annotations. God for presise direktiver og regler til LLM. | Tving LLM til å bruke IN-liste for en samlekategori |
| **Internt notat** | Lagres kun i QueryChat, ingen effekt på LLM. | Datakvalitetsproblem som er dokumentert |

### Tabelloversikt

Metadata-fanen dekker disse tabellene:

| Tabell | Beskrivelse |
|---|---|
| `KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK` | HR-data: månedsverk og lønnsutbetalinger |
| `KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER` | Daglige pasientliggetimer per post |
| `KI_GRUNNLAG_ORACLE_RDAP_BEMANNING` | Bemanningsdata fra turnus/vaktplansystem |
| `KI_GRUNNLAG_ORACLE_RDAP_OKONOMIDATA` | Økonomidata |

### Velg tabell

Velg en tabell i dropdown-menyen øverst i Metadata-fanen. Tre paneler vises:

**Venstre panel – Kolonner og kommentarer**
- Viser tabell-kommentaren øverst (grå boks)
- Lister alle kolonner med navn, datatype og eventuell kommentar
- Kolonnenavn i blå monospace-skrift, datatype i grå

**Høyre panel øverst – Oracle annotations (live)**
- Viser annotasjoner som faktisk er aktive i Oracle-databasen akkurat nå
- Oppdateres automatisk etter at en annotasjon publiseres eller arkiveres
- Kolonnenavn i blå, annotasjonsnavn i amber

**Høyre panel nederst – Redigerbare annotasjoner**
- Viser alle rader i QueryChats metadatatabell for valgt objekt
- Inkluderer AKTIV, UTKAST og ARKIVERT-rader
- Badges viser type (blå=ANNOTATION, grønn=COMMENT, amber=NONE) og status

### Opprette ny annotasjon

1. Klikk **+ Ny annotasjon** (øverst til høyre eller inne i panelet)
2. Fyll inn feltene:

| Felt | Beskrivelse |
|---|---|
| **Tabell** | Hvilken tabell annotasjonen gjelder |
| **Kolonne** | Velg kolonne, eller la stå `(tabellnivå)` for hele tabellen |
| **Type** | Se forklaring under |
| **Annotasjonsnavn** | Kun for ANNOTATION-type – se forklaring under |
| **Notattype** | Kun for NONE-type |
| **Verdi / innhold** | Teksten som synkes til databasen eller lagres som notat |
| **Status** | AKTIV = publiser nå, UTKAST = lagre uten å publisere |

3. Klikk **Lagre**

### Type-valg

**ANNOTATION** – synker til Oracle 23ai `ANNOTATIONS`-mekanismen. Brukes for presise
direktiver til LLM:
- `DESCRIPTION`: formelregler, samlekategorier, filtreringsregler
- `ALIASES`: alternative navn for kolonnen
- `UNITS`: måleenhet (f.eks. NOK, timer, antall)
- `JOIN COLUMN`: kolonne som brukes til JOIN mot annen tabell

**COMMENT** – synker til Oracle `COMMENT ON TABLE/COLUMN`. Brukes for generell
kontekstuell beskrivelse. Merk: overskriver eksisterende kommentar på samme objekt.

**NONE** – lagres kun i QueryChats metadatatabell, ingen effekt på databasen eller LLM.
Brukes for interne notater om datakvalitet, fremtidige view-kandidater, eller TODO-oppgaver.

### Notattyper (for NONE)

| Notattype | Bruksområde |
|---|---|
| `DATAKVALITET` | Kjente feil, avvik eller begrensninger i dataene |
| `VIEW_KANDIDAT` | Forslag om at en samlekategori bør lages som et view |
| `TODO` | Fremtidig annotasjon som ikke er klar ennå |

### Status

| Status | Beskrivelse |
|---|---|
| **AKTIV** | Annotasjonen er publisert og aktiv i databasen (for ANNOTATION og COMMENT) |
| **UTKAST** | Lagret i QueryChat, men ikke publisert til databasen |
| **ARKIVERT** | Var tidligere aktiv, er nå trukket tilbake og droppet fra databasen |

Hvilke knapper som vises per status:

| Status | Knapper |
|---|---|
| AKTIV | **Arkiver** |
| UTKAST | **Publiser**, **Arkiver** |
| ARKIVERT | **Publiser** |

### Publisere en annotasjon

**Publiser**-knappen vises på UTKAST og ARKIVERT-rader.

- **UTKAST → AKTIV:** DDL kjøres og annotasjonen blir aktiv i Oracle
- **ARKIVERT → AKTIV:** Annotasjonen legges tilbake i Oracle med `ADD`-DDL (reaktivering)

Vil feile med duplikat-feil hvis en annen AKTIV rad med samme type/kolonne/annotasjonsnavn
allerede finnes – arkiver den aktive raden først.

### Arkivere en annotasjon

Klikk **Arkiver** på en AKTIV eller UTKAST-rad og bekreft.

- For ANNOTATION/AKTIV: Oracle-annotasjonen droppes fra databasen (DDL kjøres)
- For COMMENT/AKTIV: kommentaren tømmes i databasen
- For NONE og UTKAST: ingen DDL, kun statusendring

Arkiverte rader kan reaktiveres med **Publiser**-knappen.

### Gode råd for annotasjoner

**For DESCRIPTION-annotasjoner:**
- Skriv direktiver i SQL-syntaks der det er mulig: `bruk IN ('A','B','C')` i stedet for `velg mellom A, B og C`
- Vær eksplisitt om hva LLM IKKE skal gjøre: `ALDRI bruk AVG()`, `verdien 'X totalt' finnes IKKE i kolonnen`
- Hold teksten kortfattet og presis – lange forklaringer kan forvirre LLM

**For COMMENT ON:**
- Beskriv hva kolonnen inneholder og hvordan den brukes
- Dokumenter alle gyldige verdier for kategoriske kolonner
- Beskriv filtreringslogikk for dato/periode-kolonner (f.eks. `TRUNC(periode/100) = 2024`)

**Duplikater:**
- Systemet blokkerer opprettelse av ny annotasjon hvis en aktiv rad med samme
  type/kolonne/annotasjonsnavn allerede finnes
- For å endre en eksisterende annotasjon: bruk **Arkiver** og deretter **Publiser**,
  eller opprett en ny rad med oppdatert verdi

---

## Chat – NL2SQL-grensesnittet

### Stille spørsmål

Skriv spørsmålet ditt på norsk eller engelsk i tekstfeltet nederst og trykk **Enter**
(eller **Shift+Enter** for ny linje).

Eksempler på spørsmål:
- `Hvor mange aarsverk har sykepleiere totalt ved OUSHF i 2024?`
- `Hva er gjennomsnittslønnen per stillingsgruppe ved SIHF?`
- `Vis antall liggetimer per avdeling siste kvartal`

### Resultatvisning

Svar vises med:
- **Tekst:** LLM-ens forklaring av resultatet
- **SQL:** generert SQL-spørring (med syntax-highlighting og kopier-knapp)
- **Tabell:** resultattabell med scrollbar
- **Tekst-visning:** alternativ tekstrepresentasjon av resultatene
- **Graf:** søyle-, linje- eller kakediagram (vises kun hvis dataene inneholder numeriske verdier)

### Tilbakemelding

Under hvert svar kan du gi tilbakemelding:
- 👍 **Ja** – svaret var nyttig
- 👎 **Nei** – svaret var ikke nyttig

Ved negativ tilbakemelding kan du legge til kommentar og korrigert SQL.
Tilbakemeldinger lagres og brukes til å forbedre systemet.

### Samtalehistorikk

Samtaler lagres lokalt i nettleseren og vises i sidepanelet gruppert etter dato.
Klikk en samtale for å se historikken. Historikk kan eksporteres som tekstfil
via nedlastingsknappen øverst til høyre i chatvisningen.

---

## Bytte passord

Klikk **Bytt passord** i sidepanelet. Fyll inn gammelt passord, nytt passord og bekreftelse.
Nytt passord må være minst 8 tegn.

---

## Konfigurasjon

Klikk tannhjulikonet øverst til høyre i chatvisningen for å konfigurere:
- **API Gateway URL:** endepunkt for NL2SQL-spørringer
- **Feedback endpoint:** endepunkt for tilbakemeldinger

Standardverdier er satt ved oppstart og trenger normalt ikke endres.

---

## Feilsituasjoner

| Feil | Mulig årsak | Løsning |
|---|---|---|
| "Ugyldig eller utløpt token" | Sesjonen er utløpt (15 min) | Logg inn på nytt |
| "Kunne ikke nå serveren" | Nettverksproblem eller API nede | Prøv igjen etter noen sekunder |
| "Databasefeil" | Feil i spørringen eller databasen | Ta kontakt med administrator |
| Ingen respons på spørsmål | API Gateway eller sql-executor nede | Ta kontakt med systemansvarlig |
| Metadata-fanen vises ikke | Mangler admin:metadata-rettighet | Be administrator om rettighet |
| "En annotasjon finnes allerede" | Duplikat-blokkering | Arkiver eksisterende rad og opprett ny |

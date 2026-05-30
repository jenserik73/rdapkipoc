-- =============================================================
-- 02_schema_comments.sql
-- Skjemakommentarer etter rename (00_rename_columns.sql kjørt)
-- Ingen norske tegn, ingen doble understrek
-- =============================================================


-- ══════════════════════════════════════════════════════════════
-- BEMANNING  (ukebasert — bruk aar + iso_uke, ikke periode)
-- ══════════════════════════════════════════════════════════════

COMMENT ON TABLE querychat.ki_grunnlag_oracle_rdap_bemanning IS
  'Bemanningsdata fra turnus/vaktplansystem per uke, helseforetak, avdeling og stillingskategori. 
   NB: Tidsdimensjon er AAR og ISO_UKE — ikke periode/maaned som i de andre tabellene. 
   Maaltall: SUM_BEMANNING (planlagte vakter), SUM_OVERTID, SUM_EKSTRA, SUM_UTRYKNING m.fl. 
   Alle SUM-kolonner teller antall vakter/hendelser i uken.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.helseforetak IS
  'Helseforetaket. Verdier: OUSHF, AHUSHF, VVHF, SIHF, SOHF, SSHF, SIVHF,
   SUNHF, SPHF, SAHF, RHF, PASHF, MHH, STHF.
   Fullt navn: Oslo universitetssykehus HF, Akershus universitetssykehus HF, osv.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.aar IS
  'Rapporteringsaar. Heltall, f.eks. 2024.
   Kombiner med ISO_UKE for tidsfiltrering.
   Kan IKKE kobles direkte mot PERIODE_ARBEIDET i HR_MNDVERK uten konvertering.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.iso_uke IS
  'ISO-ukenummer 1-53. 
  Q1 = ISO_UKE 1-13, Q2 = 14-26, Q3 = 27-39, Q4 = 40-53.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.stillingskategori IS
  'Stillingskategori, f.eks. Sykepleier, Lege, Helsefagarbeider.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.avdeling IS
  'Avdelingsnavn (fri tekst, kan vaere lang).';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.ansvar IS
  'Ansvarssted/kostnadssenter innen avdelingen.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.enhet IS
  'Organisasjonsenhet/post.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.sum_bemanning IS
  'Antall planlagte bemanningsvakter i uken. Hoved-maaltall for bemanningsnivaa.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.sum_overtid IS
  'Antall overtidsvakter i uken.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.sum_forskjoevet IS
  'Antall forskjovede vakter (endret tidspunkt).';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.sum_ekstra IS
  'Antall ekstravakter (tilkalt utover ordinaer turnus).';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.sum_byttet IS
  'Antall vakter byttet mellom ansatte.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.sum_utrykning IS
  'Antall utrykningsvakter i uken.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.sum_delvis_fravaersvakter IS
  'Antall vakter med delvis fravaer.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.sum_gaatt_som_planlagt IS
  'Antall vakter som gikk som planlagt. 
   Hoy andel = godt samsvar mellom plan og virkelighet.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_bemanning.sum_utlaant IS
  'Antall vakter der personell er utlaant til annen enhet.';


-- ══════════════════════════════════════════════════════════════
-- HR_MNDVERK  (maanedlig, periode som NUMBER YYYYMM)
-- ══════════════════════════════════════════════════════════════

COMMENT ON TABLE querychat.ki_grunnlag_oracle_rdap_hr_mndverk IS
  'HR-data med maanedsverk og lonnsutbetalinger per helseforetak, stillingsgruppe og funksjonsomraade. 
   Tre maaltall: beloep, maanedsverk_brutto (inkl. fravaer), maanedsverk_netto (ekskl. fravaer). 
   Gjennomsnittslonn = SUM(beloep) / NULLIF(SUM(maanedsverk_brutto),0) der maanedsverk_brutto > 0. 
   Aarsverk = SUM(maanedsverk) / 12. 
   Periode: NUMBER YYYYMM — filtrer aar med TRUNC(periode_arbeidet/100).';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.helseforetak IS
  'Helseforetaket. Fullt navn eller forkortelse:
   Oslo universitetssykehus HF / OUSHF, Akershus universitetssykehus HF / AHUSHF, 
   Vestre Viken HF / VVHF, Sykehuset Innlandet HF / SIHF, Sykehuset Ostfold HF / SOHF, 
   Sorlandet sykehus HF / SSHF, Sykehuset i Vestfold HF / SIVHF, Sunnaas sykehus HF / SUNHF, 
   Sykehuspartner HF / SPHF, Sykehusapotekene HF / SAHF, Helse Sor-Ost RHF / RHF, 
   Pasientreiser HF / PASHF, Martine Hansen Hospital / MHH, Sykehuset Telemark HF / STHF.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.periode_arbeidet IS
  'Naar arbeidet ble utfort. NUMBER YYYYMM, f.eks. 202401 = januar 2024. 
   Filtrer aar: TRUNC(periode_arbeidet/100) = 2024. 
   Filtrer maaned: MOD(periode_arbeidet,100) = 3 (mars). 
   Hittil i aar: TRUNC(periode_arbeidet/100) = EXTRACT(YEAR FROM SYSDATE).';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.periode_utbetalt IS
  'Naar lonnen ble utbetalt. NUMBER YYYYMM. Kan ligge etter periode_arbeidet. 
   Samme filtreringslogikk som periode_arbeidet.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.funksjonsomraade IS
  'Fagomraade. Psykisk helsevern totalt = tre verdier: 
   BUP - Psykisk helsevern for barn og unge, 
   VoP - Psykisk helsevern for voksne, DPS og annen behandling, 
   VoP - Psykisk helsevern for voksne, sykehus. 
   Rusbehandling = Tverrfaglig spesialisert behandling av rusmiddelmisbrukere. 
   Lab/rontgen = Lab/rontgen + Laboratorietjenester.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.stillingsgruppe IS
  'Stillingsgruppe. Sykepleiere totalt inkluderer: Sykepleier, Operasjonssykepleier, 
   Barn/Pediatrisykepleier, Anestesisykepleier, Andre spesialsykepleiere, 
   Intensivsykepleier, Jordmor, Kreft/onkologisykepleier. 
   Pleiepersonell = sykepleiere + Helsefagarbeider/hjelpepleier.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.loennsgruppe IS
  'Aarsak til utbetaling. Fast lonn = Grunnlonn/basislonn. 
   Ekstraarbeid = Mertid/timeonn, Overtid, Utrykning pa vakt.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.avtalt_dagsverk_brutto IS
  'Avtalte dagsverk brutto inkl. fravaer. Hjelpekolonne.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.maanedsverk_brutto IS
  'Maanedsverk inkludert fravaer — alle som har faatt utbetaling. 
   Brukes som nevner i gjennomsnittslonn: KUN rader der maanedsverk_brutto > 0. 
   Aarsverk = SUM(maanedsverk_brutto over alle maaneder i aaret) / 12.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.avtalt_dagsverk_netto IS
  'Avtalte dagsverk netto ekskl. fravaer. Hjelpekolonne.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.maanedsverk_netto IS
  'Maanedsverk ekskludert fravaer — faktisk utfort arbeid. 
   Aarsverk = SUM(maanedsverk_netto over alle maaneder i aaret) / 12.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_hr_mndverk.beloep IS
  'Utbetalt lonn i NOK. Summer med SUM(beloep). 
   Gjennomsnittslonn = SUM(beloep) / NULLIF(SUM(maanedsverk_brutto),0) 
   der maanedsverk_brutto > 0.';


-- ══════════════════════════════════════════════════════════════
-- LIGGETIMER  (daglig, dato er DATE-type)
-- NB: innlagt_dogn_lt og innlagt_dag_lt er VARCHAR2 med tallverdier
--     — bruk TO_NUMBER() ved summering
-- colname_col30/31/32_missing er tekniske kolonner — ikke bruk
-- ══════════════════════════════════════════════════════════════

COMMENT ON TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer IS
  'Daglig pasientliggetimer per post, avdeling og oppholdstype. 
   Tidsdimensjon: dato (DATE). Filtrer aar: EXTRACT(YEAR FROM dato). 
   Filtrer maaned: TRUNC(dato,''MM''). 
   NB: innlagt_dogn_lt og innlagt_dag_lt er VARCHAR2 med tall — bruk TO_NUMBER() ved summering. 
   colname_col30_missing, colname_col31_missing og colname_col32_missing er 
   tekniske systemkolonner uten innhold — skal aldri brukes i spoerringer.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.helseforetak IS
  'Helseforetaket. Samme verdier som HR_MNDVERK.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.dato IS
  'Dato for liggetimene. DATE-type. 
   Filtrer aar: EXTRACT(YEAR FROM dato) = 2024. 
   Filtrer maaned: TRUNC(dato,MM) = DATE 2024-03-01. 
   Siste maaned: TRUNC(dato,''MM'') = TRUNC(ADD_MONTHS(SYSDATE,-1),''MM'').';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.post IS
  'Sengepost der pasienten laa.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.akuttmottak IS
  'Om oppholdet er knyttet til akuttmottak.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.avdeling IS
  'Behandlende avdeling.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.ansvar IS
  'Ansvarssted/kostnadssenter.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.lokalisering IS
  'Fysisk lokalisering/bygning.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.oppholdstype IS
  'Type opphold, f.eks. innlagt, dagopphold, poliklinisk.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.seksjon IS
  'Seksjon innen avdelingen.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.poliklinisk_lt IS
  'Polikliniske liggetimer. VARCHAR2 — konverter med TO_NUMBER ved summering.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_dogn_lt IS
  'Liggetimer for innlagte doegnpasienter. VARCHAR2 — bruk TO_NUMBER(innlagt_dogn_lt) ved SUM.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_dag_lt IS
  'Liggetimer for dagpasienter. VARCHAR2 — bruk TO_NUMBER(innlagt_dag_lt) ved SUM.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_ledsager_dogn_lt IS
  'Liggetimer for ledsagere til innlagte doegnpasienter. NUMBER.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_ledsager_dag_lt IS
  'Liggetimer for ledsagere til dagpasienter. NUMBER.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_dogn_fravaer_lt IS
  'Fraværsliggetimer for doegnpasienter — senger som ikke ble brukt pga. fravaer.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_dag_fravaer_lt IS
  'Fraværsliggetimer for dagpasienter.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_dogn_teknisk_lt IS
  'Tekniske liggetimer for doegnpasienter (administrative, ikke kliniske timer).';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_dag_teknisk_lt IS
  'Tekniske liggetimer for dagpasienter.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_ledsager_dogn_teknisk_lt IS
  'Tekniske liggetimer for ledsagere til doegnpasienter.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_ledsager_dag_teknisk_lt IS
  'Tekniske liggetimer for ledsagere til dagpasienter.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_dogn_teknisk_fravaer_lt IS
  'Tekniske fraværsliggetimer for doegnpasienter.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_dag_teknisk_fravaer_lt IS
  'Tekniske fraværsliggetimer for dagpasienter.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_ledsager_dogn_teknisk_fravaer_lt IS
  'Tekniske fraværsliggetimer for ledsagere til doegnpasienter.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.innlagt_ledsager_dag_teknisk_fravaer_lt IS
  'Tekniske fraværsliggetimer for ledsagere til dagpasienter.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.er_teknisk IS
  'Flagg: ''J'' hvis raden representerer tekniske (ikke kliniske) liggetimer. 
   Filtrer bort med: er_teknisk IS NULL OR er_teknisk != ''J'' for kliniske tall.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.flyt_type IS
  'Type pasientflyt, f.eks. elektiv, oyeblikkelig hjelp.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.sist_kjoretid_dato IS
  'Teknisk kolonne — tidspunkt for siste datakjoering. Ikke bruk i analyser.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.colname_col30_missing IS
  'Teknisk systemkolonne uten innhold. Skal ikke brukes.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.colname_col31_missing IS
  'Teknisk systemkolonne uten innhold. Skal ikke brukes.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_liggetimer.colname_col32_missing IS
  'Teknisk systemkolonne uten innhold. Skal ikke brukes.';


-- ══════════════════════════════════════════════════════════════
-- OKONOMIDATA  (dato og periode er DATE-type)
-- ══════════════════════════════════════════════════════════════

COMMENT ON TABLE querychat.ki_grunnlag_oracle_rdap_okonomidata IS
  'Okonomikostnader med budsjett og faktisk per helseforetak, klinikk, avdeling og konto. 
   Maaltall: faktisk (regnskapsbeloep NOK) og budsjett (budsjettbeloep NOK). 
   Avvik = faktisk - budsjett. Negativt avvik for kostnader = mindreforbruk. 
   Avviksprosent = ROUND((SUM(faktisk)-SUM(budsjett))/NULLIF(SUM(budsjett),0)*100,1). 
   Kontoplan er hierarkisk: kontoplan_1_nivaa (grovest) til kontoplan_3_nivaa (finest). 
   Tidsdimensjon: dato (bilagsdato DATE) og periode (regnskapsperiode DATE).';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.helseforetak IS
  'Helseforetaket. Samme verdier som de andre tabellene.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.klinikk IS
  'Klinikk — organisasjonsnivaa over avdeling.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.avdeling IS
  'Avdeling innen klinikken.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.seksjon IS
  'Seksjon innen avdelingen. Fineste organisasjonsnivaa.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.konto_navn IS
  'Kontonavn i klartekst. Foretrekk dette fremfor konto_obak i spoerringer.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.kontoplan_1_nivaa IS
  'Groveste kontoplan-nivaa, f.eks. Lonn, Drift, Inntekter. Bruk for overordnet analyse.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.kontoplan_2_nivaa IS
  'Mellom-nivaa i kontoplanen. Underkategori av kontoplan_1_nivaa.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.kontoplan_3_nivaa IS
  'Fineste kontoplan-nivaa. Brukes for detaljert kostnadsanalyse.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.dato IS
  'Bilagsdato. DATE-type. 
   Filtrer aar: EXTRACT(YEAR FROM dato) = 2024. 
   Filtrer maaned: TRUNC(dato,''MM'').';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.konto_obak IS
  'Intern kontonokkel. Bruk konto_navn eller kontoplan-kolonner i stedet.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.periode IS
  'Regnskapsperiode. DATE-type, typisk forste dag i maaneden. 
   Filtrer hittil i aar: PERIODE >= TRUNC(SYSDATE,''YYYY''). 
   Filtrer aar: EXTRACT(YEAR FROM periode) = 2024.';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.faktisk IS
  'Faktisk regnskapsbeloep i NOK. Summer med SUM(faktisk).';

COMMENT ON COLUMN querychat.ki_grunnlag_oracle_rdap_okonomidata.budsjett IS
  'Budsjettert beloep i NOK. Summer med SUM(budsjett).';

COMMIT;
EXEC DBMS_CLOUD_AI.set_profile('QUERYCHAT_PROFILE');

SELECT DBMS_CLOUD_AI.GENERATE(
      prompt       => 'Vis topp 3 kunder etter omsetning',
      profile_name => 'QUERYCHAT_PROFILE',
      action       => 'narrate') AS generated_sql
FROM DUAL;

SELECT querychat.querychat_pkg.ask_nl('Hvilken helseforetak har flest dagsverk?')
FROM DUAL;

declare
    v_clob clob;
    l_offset number := 1;
BEGIN
  v_clob := querychat.querychat_pkg.ask_nl('Hvilken helseforetak har flest dagsverk?');

loop
    exit when l_offset > dbms_lob.getlength(v_clob);
    dbms_output.put_line( dbms_lob.substr( v_clob, 255, l_offset ) );
    l_offset := l_offset + 255;
END LOOP;
end;

SELECT "AVDELING" AS AVDELING, SUM("SUM_BEMANNING") AS TOTAL_BEMANNING FROM "QUERYCHAT"."KI_GRUNNLAG_ORACLE_RDAP_BEMANNING" GROUP BY "AVDELING" ORDER BY TOTAL_BEMANNING DESC FETCH FIRST 1 ROW ONLY;


SELECT HELSEFORETAK,
    PERIODE_ARBEIDET,
    PERIODE_UTBETALT,
    FUNKSJONSOMRAADE,
    STILLINGSGRUPPE,
    LOENNSGRUPPE,
    AVTALT_DAGSVERK_BRUTTO,
    MAANEDSVERK_BRUTTO,
    AVTALT_DAGSVERK_NETTO,
    MAANEDSVERK_NETTO,
    BELOEP FROM KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK;


    SELECT ID,
    QUESTION,
    GENERATED_SQL,
    CORRECT_SQL,
    VOTE,
    CREATED_AT,
    UPDATED_AT FROM QUERYCHAT_FEEDBACK;

grant select on rdapkipoc.ki_grunnlag_oracle_rdap_bemanning to nicolai;
grant select on rdapkipoc.ki_grunnlag_oracle_rdap_hr_mndverk to nicolai;
grant select on rdapkipoc.ki_grunnlag_oracle_rdap_liggetimer to nicolai;
grant select on rdapkipoc.ki_grunnlag_oracle_rdap_okonomidata to nicolai;

grant select on rdapkipoc.ki_grunnlag_oracle_rdap_bemanning to christian;
grant select on rdapkipoc.ki_grunnlag_oracle_rdap_hr_mndverk to christian;
grant select on rdapkipoc.ki_grunnlag_oracle_rdap_liggetimer to christian;
grant select on rdapkipoc.ki_grunnlag_oracle_rdap_okonomidata to christian;


GRANT SELECT ANY TABLE ON SCHEMA HR TO nicolai;
GRANT SELECT ANY TABLE ON SCHEMA HR TO christian;

revoke select on querychat.ki_grunnlag_oracle_rdap_bemanning from nicolai;
revoke select on querychat.ki_grunnlag_oracle_rdap_hr_mndverk from nicolai;
revoke select on querychat.ki_grunnlag_oracle_rdap_liggetimer from nicolai;
revoke select on querychat.ki_grunnlag_oracle_rdap_okonomidata from nicolai;

revoke select on querychat.ki_grunnlag_oracle_rdap_bemanning from christian;
revoke select on querychat.ki_grunnlag_oracle_rdap_hr_mndverk from christian;
revoke select on querychat.ki_grunnlag_oracle_rdap_liggetimer from christian;
revoke select on querychat.ki_grunnlag_oracle_rdap_okonomidata from christian;


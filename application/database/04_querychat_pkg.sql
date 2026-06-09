CREATE OR REPLACE PACKAGE BODY querychat.querychat_pkg AS

  FUNCTION error_json(p_code IN VARCHAR2, p_msg IN VARCHAR2) RETURN CLOB IS
    v_clob CLOB;
  BEGIN
    v_clob := TO_CLOB('{"ok":false,"code":'||p_code||',"error":"'||p_msg||'"}');
    RETURN v_clob;
  END;

  PROCEDURE validate_sql(p_sql IN VARCHAR2) IS
    v_upper VARCHAR2(32767) := UPPER(TRIM(p_sql));
    v_first VARCHAR2(10);
  BEGIN
    v_first := SUBSTR(v_upper, 1, INSTR(v_upper || ' ', ' ') - 1);
    IF v_first NOT IN ('SELECT', 'WITH') THEN
      RAISE_APPLICATION_ERROR(-20001, 'Kun SELECT/WITH er tillatt. Fikk: ' || v_first);
    END IF;
    FOR kw IN (SELECT COLUMN_VALUE AS word FROM TABLE(SYS.ODCIVARCHAR2LIST('INSERT','UPDATE','DELETE','DROP','CREATE','ALTER','TRUNCATE','MERGE','EXECUTE','GRANT','REVOKE')))
    LOOP
      IF REGEXP_INSTR(v_upper, '\b' || kw.word || '\b') > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Forbudt nøkkelord: ' || kw.word);
      END IF;
    END LOOP;
  END;

  -- Hent few-shot eksempler og bygg prompt
  FUNCTION build_prompt(p_question IN VARCHAR2) RETURN VARCHAR2 IS
    v_examples VARCHAR2(32767);
  BEGIN
    BEGIN
      SELECT LISTAGG(
               'Spørsmål: "' || question || '"' || CHR(10) ||
               'SQL: ' || correct_sql,
               CHR(10) || CHR(10)
             ) INTO v_examples
      FROM (
        SELECT question,
               NVL(corrected_sql, generated_sql) AS correct_sql
        FROM   querychat.querychat_feedback
        WHERE  vote > 0
        ORDER  BY vote DESC, created_at DESC
        FETCH  FIRST 5 ROWS ONLY
      );
    EXCEPTION WHEN OTHERS THEN v_examples := NULL;
    END;

    IF v_examples IS NOT NULL THEN
      RETURN 'Du er en SQL-ekspert for et helseforetak. ' ||
             'Tabellene ligger i skjema querychat. ' ||
             'Bruk ALLTID fullt tabellnavn med skjema-prefiks (querychat.KI_GRUNNLAG_ORACLE_RDAP_*).' ||
             CHR(10) || CHR(10) ||
             'Eksempler på godkjente spørringer:' || CHR(10) ||
             v_examples || CHR(10) || CHR(10) ||
             'Norsk spørsmål: ' || p_question;
    ELSE
      RETURN 'Du er en SQL-ekspert for et helseforetak. ' ||
             'Tabellene ligger i skjema querychat. ' ||
             'Bruk ALLTID fullt tabellnavn med skjema-prefiks (querychat.KI_GRUNNLAG_ORACLE_RDAP_*).' ||
             CHR(10) || 'Norsk spørsmål: ' || p_question;
    END IF;
  END;

  -- logg: inserter rad og returnerer id
  FUNCTION logg(p_question IN VARCHAR2, p_sql IN VARCHAR2, p_vote IN NUMBER)
  RETURN NUMBER IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    v_id NUMBER;
  BEGIN
    INSERT INTO querychat.querychat_feedback(question, generated_sql, vote, created_at)
    VALUES (p_question, p_sql, p_vote, SYSTIMESTAMP)
    RETURNING id INTO v_id;
    COMMIT;
    RETURN v_id;
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line(sqlerrm);
      RETURN NULL;
  END logg;

  -- generate_sql
  FUNCTION generate_sql(
    p_question IN VARCHAR2,
    p_profile  IN VARCHAR2 DEFAULT 'QUERYCHAT_PROFILE'
  ) RETURN VARCHAR2 IS
    v_sql VARCHAR2(32767);
  BEGIN
    v_sql := DBMS_CLOUD_AI.GENERATE(
      prompt       => build_prompt(p_question),
      profile_name => p_profile,
      action       => 'showsql'
    );
    v_sql := REGEXP_REPLACE(v_sql, '^```sql\s*', '',  1, 1, 'im');
    v_sql := REGEXP_REPLACE(v_sql, '\s*```\s*$', '',  1, 1, 'im');
    v_sql := REGEXP_REPLACE(
               v_sql,
               '\b(FROM|JOIN)\s+(KI_GRUNNLAG_ORACLE_RDAP_)',
               '\1 querychat.\2',
               1, 0, 'i'
             );
    RETURN TRIM(v_sql);
  END;

  -- ask_nl
  FUNCTION ask_nl(
    p_question IN VARCHAR2,
    p_profile  IN VARCHAR2 DEFAULT 'QUERYCHAT_PROFILE',
    p_max_rows IN NUMBER   DEFAULT 500
  ) RETURN CLOB IS
    v_sql       VARCHAR2(32767);
    v_result    CLOB;
    v_cols      JSON_ARRAY_T := JSON_ARRAY_T();
    v_rows_arr  JSON_ARRAY_T := JSON_ARRAY_T();
    v_row_arr   JSON_ARRAY_T;
    v_row_count NUMBER := 0;
    v_truncated VARCHAR2(5) := 'false';
    v_cursor    INTEGER;
    v_col_cnt   NUMBER;
    v_desc      DBMS_SQL.DESC_TAB;
    v_col_val   VARCHAR2(4000);
    v_log_id    NUMBER;
  BEGIN
    BEGIN
      v_sql := generate_sql(p_question, p_profile);
    EXCEPTION WHEN OTHERS THEN
      RETURN error_json('AI_ERROR', SQLERRM);
    END;

    BEGIN
      validate_sql(v_sql);
    EXCEPTION WHEN OTHERS THEN
      RETURN error_json('VALIDATION_ERROR', SQLERRM);
    END;

    IF INSTR(UPPER(v_sql), 'FETCH FIRST') = 0
       AND INSTR(UPPER(v_sql), 'ROWNUM') = 0 THEN
      v_sql := v_sql || CHR(10) || 'FETCH FIRST ' || p_max_rows || ' ROWS ONLY';
    END IF;

    BEGIN
      v_cursor := DBMS_SQL.OPEN_CURSOR;
      DBMS_SQL.PARSE(v_cursor, v_sql, DBMS_SQL.NATIVE);
      DBMS_SQL.DESCRIBE_COLUMNS(v_cursor, v_col_cnt, v_desc);
      FOR i IN 1..v_col_cnt LOOP
        v_cols.APPEND(v_desc(i).col_name);
        DBMS_SQL.DEFINE_COLUMN(v_cursor, i, v_col_val, 4000);
      END LOOP;
      IF DBMS_SQL.EXECUTE(v_cursor) >= 0 THEN
        LOOP
          EXIT WHEN DBMS_SQL.FETCH_ROWS(v_cursor) = 0;
          v_row_count := v_row_count + 1;
          v_row_arr := JSON_ARRAY_T();
          FOR i IN 1..v_col_cnt LOOP
            DBMS_SQL.COLUMN_VALUE(v_cursor, i, v_col_val);
            IF v_col_val IS NULL THEN
              v_row_arr.APPEND(JSON_ELEMENT_T.PARSE('null'));
            ELSE
              v_row_arr.APPEND(v_col_val);
            END IF;
          END LOOP;
          v_rows_arr.APPEND(v_row_arr);
        END LOOP;
      END IF;
      DBMS_SQL.CLOSE_CURSOR(v_cursor);
      IF v_row_count >= p_max_rows THEN v_truncated := 'true'; END IF;
    EXCEPTION WHEN OTHERS THEN
      IF DBMS_SQL.IS_OPEN(v_cursor) THEN DBMS_SQL.CLOSE_CURSOR(v_cursor); END IF;
      RETURN error_json('DB_ERROR', SQLERRM);
    END;

    v_log_id := logg(p_question, v_sql, 0);

    DBMS_LOB.CREATETEMPORARY(v_result, TRUE);
    DBMS_LOB.APPEND(v_result, TO_CLOB(
      '{"ok":true' ||
      ',"logId":' || NVL(TO_CHAR(v_log_id), 'null') ||
      ',"sql":"' || REPLACE(REPLACE(REPLACE(v_sql, CHR(10), '\n'), CHR(13), '\r'), '"', '\"') || '"' ||
      ',"columns":' || v_cols.TO_STRING() ||
      ',"rows":' || v_rows_arr.TO_STRING() ||
      ',"rowCount":' || v_row_count ||
      ',"truncated":' || v_truncated ||
      '}'
    ));
    RETURN v_result;
  END ask_nl;

  -- save_feedback: oppdaterer rad via id
  PROCEDURE save_feedback(
    p_id            IN NUMBER,
    p_vote          IN NUMBER,
    p_feedback_text IN VARCHAR2 DEFAULT NULL,
    p_corrected_sql IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    UPDATE querychat.querychat_feedback
    SET    vote           = p_vote,
           feedback_text  = NVL(p_feedback_text, feedback_text),
           corrected_sql  = NVL(p_corrected_sql, corrected_sql),
           updated_at     = SYSTIMESTAMP
    WHERE  id = p_id;
    COMMIT;
  END;

END querychat_pkg;
/
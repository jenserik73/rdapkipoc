EXEC DBMS_CLOUD_AI.SET_PROFILE('QUERYCHAT_PROFILE');

-- Kjøres som app_user:
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Hvilke helseforetak har vi?',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'narrate'
) AS sql_output FROM DUAL;


-- Forventet: en SELECT-setning mot <DB_SCHEMA>.CUSTOMERS / ORDERS

-- Test hele pakken:
SELECT querychat.querychat_pkg.ask_nl(
  'Hvilke helseforetak har vi?'
) FROM DUAL;


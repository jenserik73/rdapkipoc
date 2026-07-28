-- 22_grant_qc_ai_profiles.sql
--
-- Grants som manglet fra 20_create_qc_ai_profiles.sql.
--
-- Bakgrunn (juli 2026): sql-executor (v3) kobler til som
-- RDAP_CHATBOT_APP_USER og leser AI-profilkatalogen i QUERYCHAT-skjemaet
-- via _resolve_ai_profile. Uten disse grantene feiler oppslaget med
-- ORA-00942 (table or view does not exist).
--
-- NB: Disse grantene ble kjørt manuelt i prod 28.07.2026 i forbindelse
-- med feilsøking. Fila er lagt til for at repoet skal være komplett
-- fasit ved gjenoppbygging av miljøet. Å kjøre den på nytt er idempotent.

GRANT SELECT ON querychat.qc_ai_profiles            TO rdap_chatbot_app_user;
GRANT SELECT ON querychat.qc_user_active_ai_profile TO rdap_chatbot_app_user;
GRANT SELECT ON querychat.qc_user_ai_profiles       TO rdap_chatbot_app_user;
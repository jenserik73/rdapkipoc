create user rdap_chatbot_app_user identified by RFeqv7PWe73sxT7_mXx9kn_vj34yAh;
grant create session to rdap_chatbot_app_user;
grant execute on dbms_cloud_ai to rdap_chatbot_app_user;
grant execute on dbms_cloud to rdap_chatbot_app_user;
exec dbms_cloud_admin.enable_resource_principal(username => 'RDAP_CHATBOT_APP_USER');

grant select on querychat.ki_grunnlag_oracle_rdap_bemanning to rdap_chatbot_app_user;
grant select on querychat.ki_grunnlag_oracle_rdap_hr_mndverk to rdap_chatbot_app_user;
grant select on querychat.ki_grunnlag_oracle_rdap_liggetimer to rdap_chatbot_app_user;
grant select on querychat.ki_grunnlag_oracle_rdap_okonomidata to rdap_chatbot_app_user;
grant execute on querychat.querychat_pkg to rdap_chatbot_app_user;
grant select, insert, update on querychat.querychat_feedback to rdap_chatbot_app_user;

select grantee, table_name, grantor, table_schema from all_tab_privs
   where grantee = 'RDAP_CHATBOT_APP_USER' 
        and table_name = 'OCI$RESOURCE_PRINCIPAL' 
        and table_schema = 'ADMIN';

alter user rdap_chatbot_app_user identified by RFeqv7PWe73sxT7_mXx9kn_vj34yAh;

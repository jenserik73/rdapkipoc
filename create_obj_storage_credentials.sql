 
begin
  dbms_cloud.drop_credential(credential_name => 'OBJ_STORAGE_CRED');
end;
/

begin
  dbms_cloud.create_credential (
    credential_name => 'OBJ_STORAGE_CRED',
    username        => 'jens.erik.myhra@sykehuspartner.no', 
    password        => '<password>'
  );
end;
/

select owner, credential_name, username, comments
from all_credentials;

select * 
from dbms_cloud.list_objects('obj_storage_cred', 'https://objectstorage.eu-frankfurt-2.oraclecloud.eu/n/axpqbvkhoxdj/b/rdap-ki-poc-bucket/o');
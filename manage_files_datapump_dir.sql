begin
dbms_cloud.get_object(
    credential_name => 'OBJ_STORAGE_CRED', object_uri => 'https://objectstorage.eu-frankfurt-2.oraclecloud.eu/n/axpqbvkhoxdj/b/rdap-ki-storage-bucket/o/KI_GRUNNLAG_ORACLE_RDAP_okonomidata_v2.csv',
    directory_name => 'DATA_PUMP_DIR');
end;
/

select * from dbms_cloud.list_files('DATA_PUMP_DIR');
 
begin
  dbms_cloud.delete_file(
    directory_name => 'DATA_PUMP_DIR',
    file_name      => 'KI_GRUNNLAG_ORACLE_RDAP_okonomidata_v2.csv'
  );
end;
/
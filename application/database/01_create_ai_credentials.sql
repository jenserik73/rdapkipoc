begin
 dbms_cloud.drop_credential(credential_name => 'OCI_GEN_AI_CRED');
end;
/

begin
DBMS_CLOUD.CREATE_CREDENTIAL (
credential_name => 'OCI_GEN_AI_CRED',
user_ocid => 'ocid1.user.oc19..aaaaaaaawkogoic3q7guo4huvji3vb5kexemlqthtql3fcc3ickff73og4pq',
tenancy_ocid => 'ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a',
private_key => '<private key>',
fingerprint => 'd4:c0:b5:99:5e:cf:5c:f8:f7:44:cd:90:11:f1:92:cd');
end;
/
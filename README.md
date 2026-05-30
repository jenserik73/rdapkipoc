# rdapkipoc
Diverse filer knyttet til RDAP sin KI poc i OCI

## Resource discovery for en compartment
terraform-provider-oci -command=export -compartment_id=ocid1.compartment.oc19..aaaaaaaaw7nfek7szdgjrdidzqhkjzx7bw4txy2y3kdydjryavxmei52t5xq -output_path=/workspaces/rdapkipoc/terraform/infra/resource_discovery

## Test command for OCI CLI
oci iam user list

## Installere fn CLI
curl -LSs https://raw.githubusercontent.com/fnproject/cli/master/install | sh

## Verifiser fn CLI
fn version
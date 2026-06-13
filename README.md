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

## Verifiser HELM
helm version

## Importer OCI ressurs som finnes inn i terraform state slik at den blir oppdatert og håndtert i terraform fra nå av
terraform import oci_vault_secret.rdapkipocdb_wallet_password <OCID>

## Find the current ip address of the codespace instance
curl -s https://api.ipify.org

## Rydd opp codespace slik at vi ikke går tom for diskplass
```
Clear package cache: sudo apt-get clean
Purge Python pip cache: pip cache purge
Prune hidden Docker data: docker system prune -f
Remove unused Docker volumes: docker volume prune -f
```
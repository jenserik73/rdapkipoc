# Python Backend function

## Set fn context
fn use context rdap-chatbot-application
fn update context oracle.compartment-id ocid1.compartment.oc19..aaaaaaaaw7nfek7szdgjrdidzqhkjzx7bw4txy2y3kdydjryavxmei52t5xq
fn update context oracle.image-compartment-id ocid1.compartment.oc19..aaaaaaaaw7nfek7szdgjrdidzqhkjzx7bw4txy2y3kdydjryavxmei52t5xq
fn update context api-url https://functions.eu-frankfurt-2.oci.oraclecloud.eu
fn update context registry ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/rdap-chatbot-container-rep

## Docker login
docker login 	ocir.eu-frankfurt-2.oci.oraclecloud.eu \
  --username 'axpqbvkhoxdj/jens.erik.myhra@sykehuspartner.no' \
  --password 'zsUsHy7]mZWw)CGzd.Tn'

## Test sql-executor
echo '{"action":"ask","question":"Hvilke helseforetak har vi?"}' | fn invoke rdap-chatbot-application sql-executor

## Deploy ny versjon av sql-executor til rdap-chatbot-application
export FN_REGISTRY=ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/rdap-chatbot-container-rep

cd sql-executor
fn deploy --app rdap-chatbot-application
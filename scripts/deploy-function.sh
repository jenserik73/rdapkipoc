#!/bin/bash
# deploy-function.sh
# Bygger og deployer en OCI Function til OCIR + Terraform.
# Oppdaterer image_digest i functions.tf automatisk etter push.
#
# Bruk: bash /workspaces/rdapkipoc/scripts/deploy-function.sh <funksjonsnavn>
#
# Eksempler:
#   bash scripts/deploy-function.sh admin-handler
#   bash scripts/deploy-function.sh auth-handler
#   bash scripts/deploy-function.sh sql-executor
#   bash scripts/deploy-function.sh feedback-executor

set -e

FUNCTION="${1}"

if [ -z "${FUNCTION}" ]; then
  echo "Feil: Mangler funksjonsnavn."
  echo "Bruk: bash scripts/deploy-function.sh <funksjonsnavn>"
  echo "Tilgjengelige funksjoner: admin-handler, auth-handler, sql-executor, feedback-executor"
  exit 1
fi

REGISTRY="ocir.eu-frankfurt-2.oci.oraclecloud.eu"
NAMESPACE="axpqbvkhoxdj"
FULL_IMAGE="${REGISTRY}/${NAMESPACE}/${FUNCTION}:latest"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUNCTION_DIR="${SCRIPT_DIR}/../application/${FUNCTION}"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform/infra"
FUNCTIONS_TF="${TERRAFORM_DIR}/functions.tf"

if [ ! -d "${FUNCTION_DIR}" ]; then
  echo "Feil: Finner ikke mappe: ${FUNCTION_DIR}"
  exit 1
fi

if [ ! -f "${FUNCTIONS_TF}" ]; then
  echo "Feil: Finner ikke ${FUNCTIONS_TF}"
  exit 1
fi

echo "=== OCI Function Deploy: ${FUNCTION} ==="
echo "Image:      ${FULL_IMAGE}"
echo "Kildemappe: ${FUNCTION_DIR}"
echo ""

# 1. Bygg
echo "[1/4] Bygger Docker-image (--no-cache)..."
cd "${FUNCTION_DIR}"
sudo docker build --no-cache -t "${FULL_IMAGE}" .

# 2. Push
echo "[2/4] Pusher til OCIR (500-feil fra OCIR er vanligvis ufarlige)..."
sudo docker push "${FULL_IMAGE}" || echo "ADVARSEL: Push rapporterte feil, fortsetter likevel..."

# 3. Hent ny digest og oppdater functions.tf
echo "[3/4] Henter ny digest og oppdaterer functions.tf..."
DIGEST=$(sudo docker inspect \
  --format='{{index .RepoDigests 0}}' \
  "${FULL_IMAGE}" | cut -d'@' -f2)

if [ -z "${DIGEST}" ]; then
  echo "Feil: Klarte ikke hente digest fra lokalt image."
  echo "Prøv å kjøre 'sudo docker pull ${FULL_IMAGE}' og prøv igjen."
  exit 1
fi

echo "Ny digest: ${DIGEST}"

# Finn og erstatt image_digest for riktig funksjon i functions.tf.
# Strategien er å finne display_name-blokken for funksjonen og erstatte
# første image_digest-linje etter den.
RESOURCE_NAME=$(echo "${FUNCTION}" | tr '-' '_')
python3 - "${FUNCTIONS_TF}" "${RESOURCE_NAME}" "${DIGEST}" << 'PYEOF'
import sys, re

tf_file = sys.argv[1]
resource_name = sys.argv[2]
new_digest = sys.argv[3]

with open(tf_file, 'r') as f:
    content = f.read()

# Finn ressursblokken for denne funksjonen og erstatt image_digest inni den
pattern = (
    r'(resource\s+"oci_functions_function"\s+"' + re.escape(resource_name) + r'"'
    r'.*?image_digest\s*=\s*)"sha256:[a-f0-9]+"'
)
replacement = r'\g<1>"' + new_digest + '"'
new_content, n = re.subn(pattern, replacement, content, count=1, flags=re.DOTALL)

if n == 0:
    print(f"ADVARSEL: Fant ikke image_digest for ressurs '{resource_name}' i {tf_file}")
    sys.exit(1)

with open(tf_file, 'w') as f:
    f.write(new_content)

print(f"Oppdaterte image_digest for '{resource_name}' i {tf_file}")
PYEOF

# 4. Terraform apply
echo "[4/4] Kjører terraform apply..."
cd "${TERRAFORM_DIR}"
terraform apply -auto-approve

echo ""
echo "=== Deploy fullført: ${FUNCTION} ==="
echo "Digest i prod: ${DIGEST}"

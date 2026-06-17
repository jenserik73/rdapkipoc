#!/bin/bash
# deploy-frontend.sh
# Bygger og deployer querychat-frontend til OKE.
# Kjøres fra: /workspaces/rdapkipoc/application/frontend
# Bruk: bash /workspaces/rdapkipoc/scripts/deploy-frontend.sh

set -e

REGISTRY="ocir.eu-frankfurt-2.oci.oraclecloud.eu"
NAMESPACE="axpqbvkhoxdj"
IMAGE="querychat"
FULL_IMAGE="${REGISTRY}/${NAMESPACE}/${IMAGE}:latest"
DEPLOYMENT="querychat"
CONTAINER="querychat"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="${SCRIPT_DIR}/../application/frontend"

echo "=== QueryChat Frontend Deploy ==="
echo "Image:      ${FULL_IMAGE}"
echo "Deployment: ${DEPLOYMENT}"
echo ""

# 1. Bygg
echo "[1/4] Bygger Docker-image (--no-cache)..."
cd "${FRONTEND_DIR}"
sudo docker build --no-cache -t "${FULL_IMAGE}" .

# 2. Push
echo "[2/4] Pusher til OCIR (500-feil fra OCIR er vanligvis ufarlige)..."
sudo docker push "${FULL_IMAGE}" || echo "ADVARSEL: Push rapporterte feil, fortsetter likevel..."

# 3. Tving ny image-pull i OKE (kubectl set image + rollout restart)
echo "[3/4] Oppdaterer deployment i OKE..."
kubectl set image deployment/${DEPLOYMENT} ${CONTAINER}=${FULL_IMAGE}
kubectl rollout restart deployment/${DEPLOYMENT}

# 4. Vent på at rollout er ferdig
echo "[4/4] Venter på rollout..."
kubectl rollout status deployment/${DEPLOYMENT}

echo ""
echo "=== Deploy fullført ==="
echo "Kjørende image:"
kubectl get deployment ${DEPLOYMENT} -o jsonpath='{.spec.template.spec.containers[0].image}'
echo ""
echo "Pods:"
kubectl get pods -l app=${DEPLOYMENT}

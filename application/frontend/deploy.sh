#!/bin/bash
set -e

REGISTRY="ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj"
IMAGE="querychat"
TAG=$(git rev-parse --short HEAD)

echo "Bygger image med tag: $TAG"
sudo docker build --no-cache -t $REGISTRY/$IMAGE:$TAG -t $REGISTRY/$IMAGE:latest .

echo "Pusher image..."
sudo docker push $REGISTRY/$IMAGE:$TAG
PUSH_OUTPUT=$(sudo docker push $REGISTRY/$IMAGE:latest)
echo "$PUSH_OUTPUT"

# Hent digest fra push-output
DIGEST=$(echo "$PUSH_OUTPUT" | grep -oP 'sha256:[a-f0-9]{64}' | head -1)
echo "Digest: $DIGEST"

echo "Oppdaterer Kubernetes med digest..."
kubectl set image deployment/querychat querychat=$REGISTRY/$IMAGE@$DIGEST
kubectl rollout status deployment querychat

echo "Deploy fullført: $REGISTRY/$IMAGE@$DIGEST"
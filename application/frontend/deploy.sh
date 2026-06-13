#!/bin/bash
set -e

REGISTRY="ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj"
IMAGE="querychat"
TAG=$(git rev-parse --short HEAD)

echo "Bygger image med tag: $TAG"
sudo docker build --no-cache -t $REGISTRY/$IMAGE:$TAG -t $REGISTRY/$IMAGE:latest .

echo "Pusher image..."
sudo docker push $REGISTRY/$IMAGE:$TAG
sudo docker push $REGISTRY/$IMAGE:latest

echo "Oppdaterer Kubernetes..."
kubectl set image deployment/querychat querychat=$REGISTRY/$IMAGE:$TAG
kubectl rollout status deployment querychat

echo "Deploy fullført: $REGISTRY/$IMAGE:$TAG"

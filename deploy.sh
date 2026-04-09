#!/bin/bash
set -e

CLUSTER_NAME="playground-multiserver"
CLUSTER_SERVERS=3
CLUSTER_PORT=8080

echo "Building Docker images..."
docker build -t backend:latest ./backend
docker build -t middleware:latest ./middleware
docker build -t frontend:latest ./frontend

echo "Checking if k3d cluster exists..."
if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
    echo "Cluster exists."
else
    echo "Creating ${CLUSTER_NAME} cluster with port ${CLUSTER_PORT} exposed..."
    k3d cluster create ${CLUSTER_NAME} --servers ${CLUSTER_SERVERS} --port "${CLUSTER_PORT}:80@loadbalancer"
fi

echo "Importing images to k3d..."
k3d image import backend:latest middleware:latest frontend:latest -c ${CLUSTER_NAME}

echo "Applying Kubernetes manifests..."
kubectl apply -f ./k8s

echo "Deployment complete! Please wait a moment for the pods to spin up."
echo "You can check the pod status with: kubectl get pods"
echo "Once running, you can access the frontend via: http://localhost:${CLUSTER_PORT}"

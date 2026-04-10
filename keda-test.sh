#!/bin/bash
set -e

echo "--- KEDA Auto-scaling Validation (Enhanced) ---"

#0. Install KEDA
echo "Installing KEDA..."
helm repo add kedacore https://kedacore.github.io/charts
helm repo update || true
helm upgrade --install keda kedacore/keda --namespace keda --create-namespace --version ^2.19.0
echo "Installing KEDA HTTP add-on..."
helm upgrade --install http-add-on kedacore/keda-add-ons-http --namespace keda

echo "Applying k8s-keda manifests (including RBAC fix)..."
kubectl delete clusterrolebinding keda-http-scaler-discovery-fix --ignore-not-found
# Remove the auto-generated ScaledObject if it still exists (created by the old HTTPScaledObject
# without skip-scaledobject-creation). The admission webhook will reject our custom
# frontend-scaledobject if the Deployment is already managed by the old one.
kubectl delete scaledobject frontend-scaling --ignore-not-found
kubectl apply -f ./k8s-keda --validate=false

echo "Restarting scaler to pick up permissions..."
kubectl rollout restart deployment -n keda keda-add-ons-http-external-scaler
kubectl rollout status deployment -n keda keda-add-ons-http-external-scaler --timeout=90s

echo "Creating dynamic interceptor bridge..."
INTERCEPTOR_IP=$(kubectl get svc -n keda keda-add-ons-http-interceptor-proxy -o jsonpath='{.spec.clusterIP}')
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: keda-interceptor-proxy
spec:
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: v1
kind: Endpoints
metadata:
  name: keda-interceptor-proxy
subsets:
- addresses:
  - ip: $INTERCEPTOR_IP
  ports:
  - port: 8080
EOF

echo "Forcing Ingress refresh..."
kubectl delete -f ./k8s/ingress.yaml --ignore-not-found
kubectl apply -f ./k8s/ingress.yaml
echo "Waiting for Traefik to sync (10s)..."
sleep 10

# 1. Reset replicas to 0
echo "Resetting frontend and middleware replicas to 0..."
kubectl scale deployment frontend --replicas=0 --current-replicas=-1 || true
kubectl scale deployment middleware --replicas=0 --current-replicas=-1 || true
echo "Waiting for pods to terminate..."
kubectl wait --for=delete pod -l app=frontend --timeout=60s || true
kubectl wait --for=delete pod -l app=middleware --timeout=60s || true

# 2. Trigger Activation (0 -> 1)
echo "Triggering activation via Ingress (expecting cold start)..."
# Capture first response body and headers
START_TIME=$(date +%s%N)
RESPONSE=$(curl -s -i -H "Host: keda.test" "http://localhost:8080/")
END_TIME=$(date +%s%N)
DURATION=$(( (END_TIME - START_TIME) / 1000000 ))

echo "First Response (Cold Start Duration: ${DURATION}ms):"
echo "$RESPONSE" | head -n 25

# Give KEDA a moment to update the Deployment status
sleep 2

# 3. Validate Activation
echo "Verifying activation..."
FE_REPLICAS=$(kubectl get deployment frontend -o jsonpath='{.status.replicas}' || echo "0")
MW_REPLICAS=$(kubectl get deployment middleware -o jsonpath='{.status.replicas}' || echo "0")
FE_REPLICAS=${FE_REPLICAS:-0}
MW_REPLICAS=${MW_REPLICAS:-0}

if [ "$FE_REPLICAS" -ge 1 ] && [ "$MW_REPLICAS" -ge 1 ]; then
    echo "SUCCESS: Both services activated! (Frontend: $FE_REPLICAS, Middleware: $MW_REPLICAS)"
else
    echo "FAILURE: Symmetrical activation failed."
    echo "Frontend Replicas: $FE_REPLICAS"
    echo "Middleware Replicas: $MW_REPLICAS"
    exit 1
fi

# 4. Trigger Scale Out (> 1)
echo "Triggering sustained scale-out load (100 requests, 10s each, staggered)..."
for i in {1..100}; do
    curl -s -H "Host: keda.test" "http://localhost:8080/api/wait?ms=10000" > /dev/null &
    if (( $i % 10 == 0 )); then sleep 1; fi
done

echo "Waiting for KEDA to detect load and scale out (60s)..."
# We wait longer to allow for HPA polling and stabilization
sleep 60

# 5. Validate Scale Out
FE_REPLICAS=$(kubectl get deployment frontend -o jsonpath='{.status.replicas}' || echo "0")
MW_REPLICAS=$(kubectl get deployment middleware -o jsonpath='{.status.replicas}' || echo "0")
echo "Current Replicas - Frontend: $FE_REPLICAS, Middleware: $MW_REPLICAS"

if [ "$FE_REPLICAS" -gt 1 ] && [ "$MW_REPLICAS" -gt 1 ]; then
    echo "SUCCESS: Symmetrical scale out confirmed!"
else
    echo "FAILURE: Symmetrical scale out failed."
    kubectl get hpa keda-hpa-frontend-scaledobject -o wide || true
    kubectl get hpa keda-hpa-middleware-scaledobject -o wide || true
    exit 1
fi

echo "--- Validation Complete ---"

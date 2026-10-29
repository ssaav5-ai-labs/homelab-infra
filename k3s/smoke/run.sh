#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NS=smoke

cleanup() {
  kubectl delete ns "$NS" --ignore-not-found --wait=false >/dev/null 2>&1
}
trap cleanup EXIT

echo "== Applying smoke manifests =="
kubectl apply -f "$SCRIPT_DIR/echo.yaml"
kubectl apply -f "$SCRIPT_DIR/check-script.yaml"
kubectl apply -f "$SCRIPT_DIR/pvc.yaml"

echo "== Waiting for whoami DaemonSet to be ready =="
kubectl -n "$NS" rollout status ds/whoami --timeout=120s

echo "== Running DNS/overlay checks =="
kubectl apply -f "$SCRIPT_DIR/test-pods.yaml"

OVERALL=0

for pod in dns-k3s-01 dns-k3s-02; do
  echo "--- $pod ---"
  deadline=$((SECONDS + 120))
  while [ $SECONDS -lt $deadline ]; do
    status=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null)
    [ "$status" = "Succeeded" ] && break
    [ "$status" = "Failed" ] && break
    sleep 5
  done
  kubectl -n "$NS" logs "$pod" 2>/dev/null || true

  phase=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null)
  reason=$(kubectl -n "$NS" get pod "$pod" -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}' 2>/dev/null)

  if [ "$phase" = "Succeeded" ] || [ "$reason" = "Completed" ]; then
    echo "PASS: $pod"
  else
    echo "FAIL: $pod (phase=$phase)"
    OVERALL=1
  fi
done

echo "--- pvc-write-read ---"
deadline=$((SECONDS + 120))
while [ $SECONDS -lt $deadline ]; do
  status=$(kubectl -n "$NS" get pod pvc-write-read -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$status" = "Succeeded" ] && break
  [ "$status" = "Failed" ] && break
  sleep 5
done
kubectl -n "$NS" logs pvc-write-read 2>/dev/null || true

phase=$(kubectl -n "$NS" get pod pvc-write-read -o jsonpath='{.status.phase}' 2>/dev/null)
reason=$(kubectl -n "$NS" get pod pvc-write-read -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}' 2>/dev/null)

if [ "$phase" = "Succeeded" ] || [ "$reason" = "Completed" ]; then
  echo "PASS: pvc-write-read"
else
  echo "FAIL: pvc-write-read (phase=$phase)"
  OVERALL=1
fi

echo
if [ "$OVERALL" -eq 0 ]; then
  echo "SMOKE TEST: ALL PASSED"
else
  echo "SMOKE TEST: FAILURES DETECTED"
fi

exit $OVERALL
#!/usr/bin/env bash
set -uo pipefail   # без -e: чистим максимально полно, даже если что-то уже удалено

log() { echo -e "\n\033[1;31m==> $1\033[0m"; }

log "1/7 Kiali"
helm uninstall kiali-server -n istio-system 2>/dev/null || true

log "2/7 Манифесты и политики"
kubectl delete -f manifests/frontend-asm-ingress.yaml --ignore-not-found
kubectl delete -f manifests/istio-metrics.yaml --ignore-not-found
kubectl delete -f manifests/mon-prometheusrule.yaml --ignore-not-found
kubectl delete -f manifests/mon-networkpolicy.yaml --ignore-not-found
kubectl delete gateway asm-ingressgateway -n asm-ingress --ignore-not-found

log "3/7 Приложение boutique"
helm uninstall boutique -n boutique 2>/dev/null || true

log "4/7 Логирование (Promtail -> Loki)"
helm uninstall promtail -n logging 2>/dev/null || true
helm uninstall loki -n logging 2>/dev/null || true

log "5/7 Мониторинг и Jaeger"
helm uninstall kube-prometheus-stack -n monitoring 2>/dev/null || true
helm uninstall jaeger -n tracing 2>/dev/null || true

log "6/7 Istio (gateway -> istiod -> base)"
helm uninstall asm-ingressgateway -n asm-ingress 2>/dev/null || true
helm uninstall istiod -n istio-system 2>/dev/null || true
helm uninstall istio-base -n istio-system 2>/dev/null || true

log "7/7 Namespace"
for ns in boutique asm-ingress tracing logging monitoring istio-system; do
  kubectl delete ns "$ns" --ignore-not-found --wait=false &
done
wait
echo -e "\n==> Очистка завершена."

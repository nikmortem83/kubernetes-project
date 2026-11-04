#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
log() { echo -e "\n\033[1;34m==> $1\033[0m"; }

log "1/8 Репозитории Helm"
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts 2>/dev/null || true
helm repo add istio https://istio-release.storage.googleapis.com/charts 2>/dev/null || true
helm repo add kiali https://kiali.org/helm-charts 2>/dev/null || true
helm repo update

log "2/8 Namespace"
for ns in monitoring logging tracing boutique asm-ingress istio-system; do
  kubectl get ns "$ns" &>/dev/null || kubectl create ns "$ns"
done
kubectl label ns tracing    istio-injection=enabled --overwrite
kubectl label ns monitoring istio-injection=enabled --overwrite
kubectl label ns logging    istio-injection=enabled --overwrite
kubectl label ns boutique   istio-injection=enabled --overwrite

log "3/8 Istio: base + istiod + gateway-чарт"
helm upgrade --install istio-base istio/base -n istio-system
helm upgrade --install istiod istio/istiod -n istio-system --wait
helm upgrade --install asm-ingressgateway istio/gateway -n asm-ingress \
  --set service.type=NodePort
kubectl -n asm-ingress rollout status deploy/asm-ingressgateway --timeout=300s

log "4/8 Jaeger"
helm upgrade --install jaeger jaegertracing/jaeger \
  -n tracing -f "$ROOT/helm/tracing/values-jaeger.yaml"

log "5/8 Мониторинг: kube-prometheus-stack"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring -f "$ROOT/helm/monitoring/values-prometheus.yaml"

log "6/8 Логирование: Loki + Promtail"
helm upgrade --install loki "$ROOT/helm/logging/loki-chart" \
  -n logging -f "$ROOT/helm/logging/loki-chart/values.yaml"
helm upgrade --install promtail grafana/promtail \
  -n logging --set loki.serviceName=loki \
  -f "$ROOT/helm/logging/values-promtail.yaml"

log "7/8 Приложение Online Boutique"
helm upgrade --install boutique "$ROOT/helm/online-boutique" \
  -n boutique \
  --set frontend.externalService=false \
  --set networkPolicies.create=true \
  --set sidecars.create=true \
  --set serviceAccounts.create=true \
  --set authorizationPolicies.create=true \
  --set frontend.virtualService.create=true \
  --set frontend.virtualService.gateway.name=asm-ingressgateway \
  --set frontend.virtualService.gateway.namespace=asm-ingress \
  --set frontend.virtualService.gateway.labelKey=asm \
  --values "$ROOT/helm/online-boutique/values.yaml"

log "8/8 Манифесты и Kiali"
kubectl apply -f "$ROOT/manifests/frontend-asm-ingress.yaml"
kubectl apply -f "$ROOT/manifests/istio-metrics.yaml"
kubectl apply -f "$ROOT/manifests/mon-prometheusrule.yaml"
kubectl apply -f "$ROOT/manifests/mon-networkpolicy.yaml"

helm upgrade --install kiali-server kiali/kiali-server \
  -n istio-system -f "$ROOT/helm/kiali/values-kiali.yaml"

log "Готово. Проверка:"
kubectl get pods -A | grep -Ev 'kube-system'
GWP=$(kubectl get svc -n asm-ingress asm-ingressgateway \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
echo "==> Приложение: http://$(minikube ip):$GWP"

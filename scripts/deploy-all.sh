#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
log() { echo -e "\n\033[1;34m==> $1\033[0m"; }

# --- Профиль окружения --------------------------------------------
# Приоритет: аргумент скрипта > ветка git > значение по умолчанию
PROFILE="${1:-}"
if [ -z "$PROFILE" ]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
  case "$BRANCH" in
    *prod*)  PROFILE="prod" ;;
    *)       PROFILE="dev"  ;;
  esac
fi
log "Профиль окружения: $PROFILE"
if [ "$PROFILE" = "prod" ] && [ "$(kubectl config current-context)" = "minikube" ]; then
  echo "ОШИБКА: профиль prod, но текущий контекст kubectl — minikube. Проверьте контекст!" >&2
  exit 1
fi

if [ "$PROFILE" = "prod" ]; then
  BOUTIQUE_VALUES="values-prod.yaml"
  GW_SVC_TYPE="LoadBalancer"
  PROMETHEUS_VALUES="values-prometheus-prod.yaml"
else
  BOUTIQUE_VALUES="values.yaml"
  GW_SVC_TYPE="NodePort"
  PROMETHEUS_VALUES="values-prometheus.yaml"
fi

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
for ns in tracing monitoring logging boutique; do
  kubectl label ns "$ns" istio-injection=enabled --overwrite
done

log "3/8 Istio: base + istiod + gateway-чарт"
helm upgrade --install istio-base istio/base -n istio-system
helm upgrade --install istiod istio/istiod -n istio-system --wait
helm upgrade --install asm-ingressgateway istio/gateway -n asm-ingress \
  --set service.type="$GW_SVC_TYPE"
kubectl -n asm-ingress rollout status deploy/asm-ingressgateway --timeout=300s

log "4/8 Jaeger"
helm upgrade --install jaeger jaegertracing/jaeger \
  -n tracing -f "$ROOT/helm/tracing/values-jaeger.yaml"

log "5/8 Мониторинг: kube-prometheus-stack"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring -f "$ROOT/helm/monitoring/$PROMETHEUS_VALUES"

log "6/8 Логирование: Loki + Promtail"
helm upgrade --install loki "$ROOT/helm/logging/loki-chart" \
  -n logging -f "$ROOT/helm/logging/loki-chart/values.yaml"
helm upgrade --install promtail grafana/promtail \
  -n logging --set loki.serviceName=loki \
  -f "$ROOT/helm/logging/values-promtail.yaml"

log "7/8 Приложение Online Boutique ($PROFILE)"
helm upgrade --install boutique "$ROOT/helm/online-boutique" \
  -n boutique \
  --values "$ROOT/helm/online-boutique/$BOUTIQUE_VALUES"

log "8/8 Манифесты и Kiali"
kubectl apply -f "$ROOT/manifests/frontend-asm-ingress.yaml"
kubectl apply -f "$ROOT/manifests/istio-metrics.yaml"
kubectl apply -f "$ROOT/manifests/mon-prometheusrule.yaml"
kubectl apply -f "$ROOT/manifests/mon-networkpolicy.yaml"

helm upgrade --install kiali-server kiali/kiali-server \
  -n istio-system -f "$ROOT/helm/kiali/values-kiali.yaml"

log "Готово. Проверка:"
kubectl get pods -A | grep -Ev 'kube-system'

if [ "$PROFILE" = "prod" ]; then
  LB_IP=$(kubectl get svc -n asm-ingress asm-ingressgateway \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echo "==> Приложение: http://$LB_IP"
else
  GWP=$(kubectl get svc -n asm-ingress asm-ingressgateway \
    -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
  echo "==> Приложение: http://$(minikube ip):$GWP"
fi

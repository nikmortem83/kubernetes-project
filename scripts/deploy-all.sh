#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# deploy-all.sh — полный деплой MVP платформы на minikube
# Стек: NGINX Ingress + kube-prometheus-stack + Loki + Jaeger + Online Boutique
# Требования: minikube запущен, minikube tunnel запущен в отдельном терминале
# ------------------------------------------------------------------------------

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELM_DIR="$BASE_DIR/helm"

echo "🚀 Запуск полного деплоя MVP платформы..."

# Проверка контекста
CURRENT_CONTEXT=$(kubectl config current-context)
if [[ "$CURRENT_CONTEXT" != "minikube" ]]; then
  echo "❌ Ошибка: текущий контекст kubectl — '$CURRENT_CONTEXT'. Нужен 'minikube'."
  echo "💡 Запустите: minikube start (или проверьте, что minikube.sh уже отработал)."
  exit 1
fi

# Создание namespace-ов
echo "📦 Создание namespace-ов..."
declare -a NAMESPACES=("ingress-nginx" "monitoring" "logging" "tracing" "boutique")
for ns in "${NAMESPACES[@]}"; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# Обновление репозиториев Helm
echo "🔄 Обновление Helm-репозиториев..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx > /dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts > /dev/null 2>&1 || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts > /dev/null 2>&1 || true
helm repo add loki https://grafana.github.io/loki/charts > /dev/null 2>&1 || true
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts > /dev/null 2>&1 || true
helm repo update

# Установка NGINX Ingress Controller
echo "🌐 Установка NGINX Ingress Controller..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f "$HELM_DIR/ingress/values-ingress.yaml"

# Установка Loki + Promtail
echo "📝 Установка Loki (логирование)..."
helm upgrade --install loki loki/loki-stack \
  --namespace logging \
  --create-namespace \
  -f "$HELM_DIR/logging/values-loki.yaml"

# Установка kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
echo "📊 Установка мониторинга (kube-prometheus-stack)..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f "$HELM_DIR/monitoring/values-prometheus.yaml"

# Применение ServiceMonitor для микросервисов Online Boutique
echo "👁️ Применение ServiceMonitor для сбора метрик Boutique..."
kubectl apply -f "$HELM_DIR/monitoring/servicemonitor.yaml" || {
  echo "⚠️ ServiceMonitor не применился (возможно, CRD ещё не готов). Подождите 10–30 сек и запустите скрипт повторно."
  exit 1
}

# Установка Jaeger (трейсинг)
echo "🗺️ Установка Jaeger (распределённый трейсинг)..."
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace tracing \
  --create-namespace \
  -f "$HELM_DIR/tracing/values-jaeger.yaml"

# Развёртывание Online Boutique
echo "🛍️ Развёртывание приложения Online Boutique..."
cd "$HELM_DIR/online-boutique"
helm upgrade --install boutique ./ \
  --namespace boutique \
  --create-namespace \
  -f values.yaml

# Ожидание запуска подов Boutique
echo "⏳ Ожидание запуска подов Online Boutique..."
kubectl wait --namespace boutique \
  --for=condition=Ready pod \
  --timeout=180s \
  -l app.kubernetes.io/name=boutique || {
    echo "⚠️ Некоторые поды не перешли в Ready за 3 минуты. Проверьте: kubectl get pods -n boutique"
  }

# Создание Ingress для доступа к фронтенду и Grafana
echo "🏠 Создание Ingress-ресурсов..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: boutique-ingress
  namespace: boutique
spec:
  rules:
    - host: boutique.127.0.0.1.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
spec:
  rules:
    - host: grafana.127.0.0.1.nip.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kube-prometheus-stack-grafana
                port:
                  number: 80
EOF

echo "✅ Деплой завершён!"
echo ""
echo "🔗 Точки доступа:"
echo "  Frontend:      http://boutique.127.0.0.1.nip.io"
echo "  Grafana:       http://grafana.127.0.0.1.nip.io (admin / change-me-in-prod)"
echo "  Loki:          через Grafana (Data Source)"
echo "  Jaeger:        нужно создать отдельный Ingress для jaeger-query (см. ниже)"
echo ""
echo "💡 Важно: держите терминал с 'minikube tunnel' открытым — иначе LoadBalancer не получит IP."
echo "   Запустите: minikube tunnel"

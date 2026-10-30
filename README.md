# Проектная работа "Развёртывание и управление Managed кластерами Kubernetes с использованием Terraform и GitLab-CI"
# Морозов Н.Н. Kubernetes-2026-05

## 📌 kubernetes-project/
### ├── .gitlab-ci.yml                 # единый пайплайн (с флагами minikube/cloud)
### ├── README.md                      # документация: шаги, переменные, как повторить
### ├── terraform/                     # IaC для Managed K8s (Yandex)
#### │   ├── main.tf
#### │   ├── variables.tf
#### │   └── outputs.tf
### ├── helm/
#### │   ├── ingress/                  # NGINX Ingress Controller
#### │   │   └── values-ingress.yaml
#### │   ├── logging/                  # Loki + Promtail
#### │   │   └── values-loki.yaml
#### │   ├── monitoring/               # kube-prometheus-stack
#### │   │   ├── values-prometheus.yaml
#### │   │   └── servicemonitor.yaml   # для сервисов Online Boutique
#### │   ├── tracing/                  # Jaeger
#### │   │   └── values-jaeger.yaml
#### │   └── online-boutique/          # Helm-чарт приложения (на базе microservices-demo)
#### │       ├── Chart.yaml
#### │       ├── values.yaml           # основные настройки всех микросервисов
#### │       └── templates/            # манифесты всех сервисов
### ├── argocd/                        # GitOps-манифесты (Application CRD)
#### │   └── boutique-app.yaml
### └── scripts/
####     ├── minikube.sh               # запуск minikube + включение нужных аддонов
####     └── deploy-all.sh             # универсальный скрипт деплоя всех компонентов

## 📌 MVP платформа: Managed K8s (minikube → YC), мониторинг, логирование, CI/CD, приложение Online Boutique

## ✨ Разработка в minikube
### 1. Поднимаем minikube и необходимые аддоны
minikube start --driver=docker --nodes=3 --memory=4096 --cpus=2
minikube addons enable ingress
minikube addons enable metrics-server
kubectl config use-context minikube

#### 🌟 ./scripts/minikube.sh (chmod +x kubernetes-project/scripts/minikube.sh)

### 2. Создаем namespace:
kubectl create ns ingress-nginx
kubectl create ns monitoring
kubectl create ns logging
kubectl create ns tracing
kubectl create ns boutique

### 3. Установливаем платформенные компоненты через Helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
? helm repo add loki https://grafana.github.io/loki/charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts



# Ingress
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  -f helm/ingress/values-ingress.yaml

# Loki
helm upgrade --install loki helm/logging/loki-chart \
  --namespace logging \
  --create-namespace

helm uninstall loki helm/logging/loki-chart -n logging

helm upgrade --install loki grafana/loki \
  --namespace logging \
  -f helm/logging/values-loki.yaml

helm uninstall loki --namespace logging

# Promtail
helm upgrade --install promtail grafana/promtail \
  --namespace logging \
  --create-namespace \
  --set loki.serviceName=loki

helm uninstall promtail grafana/promtail -n logging

helm upgrade --install promtail grafana/promtail \
  --namespace logging \
  --set loki.serviceName=loki \
  -f helm/logging/values-promtail.yaml

helm uninstall promtail --namespace logging

# Prometheus + Grafana + Alertmanager
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f helm/monitoring/values-prometheus.yaml

# Jaeger
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace tracing \
  -f helm/tracing/values-jaeger.yaml






helm repo add grafana https://grafana.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

### 3. Устанавливаем Ingress (обязательно для публичного доступа через nip.io)
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace

helm uninstall ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx

### 4. Устанавливаем мониторинг (Prometheus + Grafana + Alertmanager)
#### 💡 Важно: включаем ServiceMonitor, чтобы потом подхватывать метрики приложения
helm install prometheus grafana/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelector.matchLabels.release=prometheus

helm uninstall prometheus grafana/kube-prometheus-stack -n monitoring

### 5. Устанавливаем логирование (Loki + Promtail)
helm install loki grafana/loki-stack \
  --namespace logging --create-namespace

helm uninstall loki grafana/loki-stack -n logging

### 🔥 6. Устанавливаем приложение Online Boutique by Google
helm install boutique ./helm/online-boutique \
  --namespace boutique --create-namespace \
  --values ./helm/online-boutique/values.yaml

helm uninstall boutique ./helm/online-boutique -n boutique

#### 🌟 ./scripts/deploy-all.sh (chmod +x kubernetes-project/scripts/deploy-all.sh)



## 🎉 Развертывание в Yandex Cloud




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
### 1. Поднимаем minikube
minikube start --driver=docker --nodes=3 --memory=2048 --cpus=2

### 2. Добавляем репозитории Helm
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



# Ingress
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f helm/ingress/values-ingress.yaml

# Monitoring
helm install prometheus grafana/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f helm/monitoring/values-prometheus.yaml

# Logging
helm install loki grafana/loki-stack \
  --namespace logging --create-namespace \
  -f helm/logging/values-loki.yaml

# Online Boutique
helm install boutique ./helm/online-boutique \
  --namespace boutique --create-namespace \
  -f helm/online-boutique/values.yaml




## 🎉 Развертывание в Yandex Cloud




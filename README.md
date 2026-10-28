# Проектная работа "Развёртывание и управление Managed кластерами Kubernetes с использованием Terraform и GitLab-CI"
# Морозов Н.Н.

## 📌 kubernetes-project/
### ├── terraform/           IaC: кластер, сеть, ноды
### ├── helm/                Helm-чарты платформенных сервисов
### │   ├── monitoring/      kube-prometheus-stack + кастомные алерты
### │   ├── logging/         Loki + Promtail
### │   ├── ingress/         NGINX Ingress
### │   └── online-boutique/ Манифесты Online Boutique
### │   └── tracing/         Jaeger
### ├── gitlab-ci/           .gitlab-ci.yml, пайплайн-описание
### ├── argocd/              Application-манифесты
### └── README.md            Документация

## 📌 MVP платформы: Managed K8s (minikube → YC), мониторинг, логирование, CI/CD, приложение Online Boutique

## ✨ Разработка в minikube
### 1. Поднимаем minikube
minikube start --driver=docker --nodes=3 --memory=2048 --cpus=2 --disk-size=10g

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
  --namespace onlineboutique --create-namespace \
  --values ./microservices-demo/helm-chart/values.yaml

helm uninstall boutique ./helm/online-boutique -n onlineboutique





## 🎉 Развертывание в Yandex Cloud




# Проектная работа "Развёртывание и управление Managed кластерами Kubernetes с использованием Terraform и GitLab-CI"
# Морозов Н.Н. Kubernetes-2026-05

## 📌 kubernetes-project/
### ├── .gitlab-ci.yml                 единый пайплайн (с флагами minikube/cloud)
### ├── README.md                      документация: шаги, переменные, как повторить
### ├── terraform/                     IaC для Managed K8s (Yandex)
#### │   ├── main.tf
#### │   ├── variables.tf
#### │   └── outputs.tf
### ├── helm/
#### │   ├── logging/                  Loki + Promtail
#### │   │   └── values-loki.yaml
#### │   ├── monitoring/               kube-prometheus-stack
#### │   │   ├── values-prometheus.yaml
#### │   │   └── servicemonitor.yaml   для сервисов Online Boutique
#### │   ├── tracing/                  Jaeger
#### │   │   └── values-jaeger.yaml
#### │   └── online-boutique/          Helm-чарт приложения (на базе microservices-demo)
#### │       ├── Chart.yaml
#### │       ├── values.yaml           основные настройки всех микросервисов
#### │       └── templates/            манифесты всех сервисов
### ├── argocd/                        GitOps-манифесты (Application CRD)
#### │   └── boutique-app.yaml
### └── scripts/
####     ├── minikube.sh               запуск minikube + включение нужных аддонов
####     └── deploy-all.sh             универсальный скрипт деплоя всех компонентов

## 📌 MVP платформа: Managed K8s (minikube → YC), мониторинг, логирование, CI/CD, приложение Online Boutique

## ✨ Разработка в minikube
### 1. Поднимаем minikube и необходимые аддоны
minikube start --driver=docker --nodes=3 --memory=3072 --cpus=2
minikube addons enable metrics-server
kubectl config use-context minikube

#### 🌟 ./scripts/minikube.sh (chmod +x kubernetes-project/scripts/minikube.sh)

### 2. Создаем namespace:
kubectl create ns monitoring
kubectl create ns logging
kubectl create ns tracing
kubectl create ns boutique
kubectl create ns asm-ingress
kubectl create ns istio-ingress

### 3. Установливаем платформенные компоненты через Helm
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

### ⛵️ 4. Установка Istiod
#### Вручную
export ISTIO_VERSION=1.24.1
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.24.1
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y

#### Удаляем весь Istio из кластера
istioctl uninstall --purge -y

#### Через helm
helm repo add istio https://istio-release.storage.googleapis.com/charts && helm repo update

helm install istio-base istio/base -n istio-system --create-namespace
helm install istiod istio/istiod -n istio-system --wait
helm install istio-ingress istio/gateway -n istio-ingress --create-namespace


### 5. Устанавливаем Jaeger
helm upgrade --install jaeger jaegertracing/jaeger \
  --namespace tracing \
  -f helm/tracing/values-jaeger.yaml

### http://127.0.0.1:16686/

### 6. Устанавливаем мониторинг (Prometheus + Grafana + Alertmanager)
#### 💡 Включаем ServiceMonitor, чтобы потом подхватывать метрики приложения
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f helm/monitoring/values-prometheus.yaml

helm uninstall kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring

### 💡 «Для сбора метрик с микросервисов Online Boutique применён гибридный подход:
#### Frontend (HTTP) — метрики собираются напрямую через ServiceMonitor в Prometheus.
#### gRPC‑сервисы (cart, payment, shipping и др.) — не экспортируют HTTP‑метрики напрямую. Вместо этого они отправляют трейсы и логи в OpenTelemetry Collector, который агрегирует данные и предоставляет метрики для Prometheus. Это позволяет избежать установки экспортеров в каждый gRPC‑под и обеспечивает единообразие сбора телеметрии.»

### curl http://127.0.0.1:3101/metrics

### 7. Устанавливаем логирование (Loki + Promtail)
#### Loki
helm upgrade --install loki helm/logging/loki-chart \
  --namespace logging \
  --create-namespace

helm uninstall loki helm/logging/loki-chart -n logging

? helm upgrade --install loki grafana/loki \
  --namespace logging \
  -f helm/logging/values-loki.yaml

helm uninstall loki -n logging

#### Promtail
helm upgrade --install promtail grafana/promtail \
  --namespace logging \
  --create-namespace \
  --set loki.serviceName=loki

helm uninstall promtail grafana/promtail -n logging

? helm upgrade --install promtail grafana/promtail \
  --namespace logging \
  --set loki.serviceName=loki \
  -f helm/logging/values-promtail.yaml

helm uninstall promtail -n logging

### 🔥 6. Устанавливаем приложение Online Boutique by Google
kubectl label namespace boutique istio-injection=enabled

helm install boutique ./helm/online-boutique \
  --namespace boutique --create-namespace \
  --set frontend.externalService=true \
  --set serviceAccounts.create=true \
  --set authorizationPolicies.create=true \
  --set networkPolicies.create=true \
  --set sidecars.create=true \
  --set frontend.virtualService.create=true \
  --values ./helm/online-boutique/values.yaml

helm uninstall boutique ./helm/online-boutique -n boutique


#### 🌟 ./scripts/deploy-all.sh (chmod +x kubernetes-project/scripts/deploy-all.sh)



## 🎉 Развертывание в Yandex Cloud




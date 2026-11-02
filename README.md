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
### ├── manifests/                     дополнительные манифесты
### └── scripts/
####     ├── minikube.sh               запуск minikube + включение нужных аддонов
####     └── deploy-all.sh             универсальный скрипт деплоя всех компонентов

## 📌 MVP платформа: Managed K8s (minikube → YC), мониторинг, логирование, CI/CD, приложение Online Boutique

## ✨ Разработка в minikube
### 1. Поднимаем minikube и необходимые аддоны
minikube start --driver=docker --nodes=2 --memory=6144 --cpus=3
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

#### Удаляем Istio
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

#### удаление helm uninstall jaeger jaegertracing/jaeger -n tracing

### Jaeger: kubectl port-forward -n tracing service/jaeger 16686:16686 переход на http://localhost:16686

[![Screenshot Jaeger](/manifests/img/Jaeger.png)](/manifests/img/Jaeger.png)

### 6. Устанавливаем мониторинг (Prometheus + Grafana + Alertmanager)
#### 💡 Включаем ServiceMonitor, чтобы потом подхватывать метрики приложения
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f helm/monitoring/values-prometheus.yaml

#### удаление helm uninstall kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring

[![Screenshot Prometheus](/manifests/img/Prometheus.png)](/manifests/img/Prometheus.png)

### 💡 «Для сбора метрик с микросервисов Online Boutique применён гибридный подход:
#### Frontend (HTTP) — метрики собираются напрямую через ServiceMonitor в Prometheus.
#### gRPC‑сервисы (cart, payment, shipping и др.) — не экспортируют HTTP‑метрики напрямую. Вместо этого они отправляют трейсы и логи в OpenTelemetry Collector, который агрегирует данные и предоставляет метрики для Prometheus. Это позволяет избежать установки экспортеров в каждый gRPC‑под и обеспечивает единообразие сбора телеметрии.»

minikube service kube-prometheus-stack-prometheus --namespace=monitoring

### Prometheus: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 переход на http://localhost:9090/query
### Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 переход на http://localhost:3000 (admin)
### Alertmanager: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9093:9093 переход на http://localhost:9093

[![Screenshot Grafana](/manifests/img/Grafana.png)](/manifests/img/Grafana.png)

### 7. Устанавливаем логирование (Loki + Promtail)
#### Loki
helm upgrade --install loki helm/logging/loki-chart \
  --namespace logging \
  --create-namespace \
  -f helm/logging/loki-chart/values.yaml

#### удаление helm uninstall loki helm/logging/loki-chart -n logging

? helm upgrade --install loki grafana/loki \
  --namespace logging \
  -f helm/logging/values-loki.yaml

#### удаление helm uninstall loki -n logging

#### Promtail
helm upgrade --install promtail grafana/promtail \
  --namespace logging \
  --create-namespace \
  --set loki.serviceName=loki

#### удаление helm uninstall promtail grafana/promtail -n logging

? helm upgrade --install promtail grafana/promtail \
  --namespace logging \
  --set loki.serviceName=loki \
  -f helm/logging/values-promtail.yaml

#### удаление helm uninstall promtail -n logging

[![Screenshot Loki_Promtail](/manifests/img/Loki_Promtail.png)](/manifests/img/Loki_Promtail.png)

### Loki+Promtail: kubectl --namespace logging port-forward daemonset/promtail 3101 переход на http://localhost:3101/metrics

### 🔥 6. Устанавливаем приложение Online Boutique by Google
kubectl label namespace boutique istio-injection=enabled

helm install boutique ./helm/online-boutique \
  --namespace boutique --create-namespace \
  --set networkPolicies.create=true \
  --set sidecars.create=true \
  --set serviceAccounts.create=true \
  --set authorizationPolicies.create=true \
  --set frontend.externalService=true \
  --set frontend.virtualService.create=true \
  --set frontend.virtualService.gateway.name=asm-ingressgateway \
  --set frontend.virtualService.gateway.namespace=asm-ingress \
  --set frontend.virtualService.gateway.labelKey=asm \
  --values ./helm/online-boutique/values.yaml

#### удаление helm uninstall boutique -n boutique

#### Get the external IP address of the frontend:
    export SERVICE_IP=$(kubectl get svc --namespace boutique frontend-external --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
    echo http://$SERVICE_IP
#### Get the external IP address of the ingress gateway:
    export SERVICE_IP=$(kubectl get svc --namespace asm-ingress asm-ingressgateway --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
    echo http://$SERVICE_IP

### 7. 🔎 Добавление правил и политик мониторинга
kubectl apply -f manifests/mon-prometheusrule.yaml 
kubectl apply -f manifests/mon-networkpolicy.yaml

### удаление
kubectl delete -f manifests/mon-prometheusrule.yaml 
kubectl delete -f manifests/mon-networkpolicy.yaml

#### 🌟 ./scripts/deploy-all.sh (chmod +x kubernetes-project/scripts/deploy-all.sh)

## 🎉 Развертывание в Yandex Cloud




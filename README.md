# Проектная работа "Развёртывание и управление Managed кластерами Kubernetes с использованием Terraform и GitLab-CI"
# Морозов Н.Н.

## 📌 kubernetes-project/
### ├── terraform/           IaC: кластер, сеть, ноды
### ├── helm/                Helm-чарты платформенных сервисов
### │   ├── monitoring/      kube-prometheus-stack + кастомные алерты
### │   ├── logging/         Loki + Promtail
### │   ├── ingress/         NGINX Ingress
### │   └── tracing/         Jaeger
### ├── microservices-demo/                 Манифесты Online Boutique
### ├── gitlab-ci/           .gitlab-ci.yml, пайплайн-описание
### ├── argocd/              Application-манифесты
### └── README.md            Документация

## ✨ Разработка в minikube


## Запускаем minikube
minikube start --driver=docker --nodes=3 --memory=2048 --cpus=2


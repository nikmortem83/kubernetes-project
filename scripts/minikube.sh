
#!/usr/bin/env bash
set -e
minikube start --driver=docker --nodes=3 --memory=4096 --cpus=2
minikube addons enable ingress
minikube addons enable metrics-server
kubectl config use-context minikube
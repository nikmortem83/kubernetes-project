
#!/usr/bin/env bash
set -e
minikube start --driver=docker --nodes=3 --memory=3072 --cpus=2
minikube addons enable metrics-server
kubectl config use-context minikube
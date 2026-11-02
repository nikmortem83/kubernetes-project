
#!/usr/bin/env bash
set -e
minikube start --driver=docker --nodes=2 --memory=6144 --cpus=3
minikube addons enable metrics-server
kubectl config use-context minikube
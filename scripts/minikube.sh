#!/usr/bin/env bash
set -euo pipefail

# Управление minikube-кластером проекта
# ./scripts/minikube.sh up      - поднять кластер
# ./scripts/minikube.sh down    - остановить
# ./scripts/minikube.sh delete  - удалить полностью
# ./scripts/minikube.sh tunnel  - minikube tunnel (для LoadBalancer)

cmd="${1:-}"
case "$cmd" in
  up)
    echo "==> Запуск minikube (3 ноды)"
    minikube start --driver=docker --nodes=3 --memory=3072 --cpus=2
    echo "==> Включение metrics-server"
    minikube addons enable metrics-server
    kubectl config use-context minikube

    echo "==> Настройка inotify/file-max на нодах (нужно Promtail)"
    for node in $(minikube node list | awk '{print $2}' | grep -v '^$'); do
      echo "    node: $node"
      minikube ssh -n "$node" -- <<'EOF'
        sudo sysctl -w fs.inotify.max_user_instances=1024
        sudo sysctl -w fs.inotify.max_user_watches=1048576
        sudo sysctl -w fs.file-max=262144
        echo -e "fs.inotify.max_user_instances=1024\nfs.inotify.max_user_watches=1048576" | \
          sudo tee /etc/sysctl.d/99-promtail.conf
        sudo sysctl --system
EOF
    done
    echo "==> Кластер готов: $(minikube ip)"
    ;;
  down)
    minikube stop
    ;;
  delete)
    minikube delete
    ;;
  tunnel)
    minikube tunnel
    ;;
  *)
    echo "Использование: $0 {up|down|delete|tunnel}"
    exit 1
    ;;
esac

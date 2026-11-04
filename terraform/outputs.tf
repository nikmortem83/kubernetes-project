output "cluster_id" {
  value       = yandex_kubernetes_cluster.k8s.id
  description = "ID кластера (нужен для yc get-credentials)"
}

output "cluster_external_endpoint" {
  value       = yandex_kubernetes_cluster.k8s.master[0].external_v4_endpoint
  description = "Внешний endpoint API-сервера"
}

output "node_group_id" {
  value       = yandex_kubernetes_node_group.workers.id
  description = "ID группы узлов"
}
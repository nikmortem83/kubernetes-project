variable "yc_token" {
  type        = string
  description = "OAuth-токен или IAM-токен сервисного аккаунта Yandex Cloud"
  sensitive   = true
}

variable "yc_cloud_id" {
  type        = string
  description = "ID облака (yc config get cloud-id)"
}

variable "yc_folder_id" {
  type        = string
  description = "ID каталога (yc config get folder-id)"
}

variable "zone" {
  type        = string
  description = "Зона доступности кластера"
  default     = "ru-central1-a"
}

variable "cluster_name" {
  type        = string
  description = "Имя кластера"
  default     = "online-boutique-project"
}

variable "cluster_version" {
  type        = string
  description = "Версия Kubernetes"
  default     = "1.30"
}

variable "node_count" {
  type        = number
  description = "Количество узлов в группе"
  default     = 3
}

variable "node_cores" {
  type        = number
  description = "vCPU на узле"
  default     = 4
}

variable "node_memory" {
  type        = number
  description = "RAM на узле, ГБ"
  default     = 8
}

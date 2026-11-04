terraform {
  required_version = ">= 1.9"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.233.0"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.zone
}

# --- Сеть -----------------------------------------------------------

resource "yandex_vpc_network" "k8s-net" {
  name = "${var.cluster_name}-net"
}

resource "yandex_vpc_subnet" "k8s-subnet" {
  name           = "${var.cluster_name}-subnet"
  v4_cidr_blocks = ["10.10.0.0/16"]
  zone           = var.zone
  network_id     = yandex_vpc_network.k8s-net.id
}

# --- Сервисный аккаунт ---------------------------------------------

resource "yandex_iam_service_account" "sa" {
  name        = "${var.cluster_name}-sa"
  description = "SA для Managed K8s ${var.cluster_name}"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = var.yc_folder_id
  role      = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.sa.id}"
  ]
}

resource "yandex_iam_service_account_key_file" "sa-key" {
  service_account_id = yandex_iam_service_account.sa.id
}

# --- Кластер --------------------------------------------------------

resource "yandex_kubernetes_cluster" "k8s" {
  name        = var.cluster_name
  description = "Managed K8s для проектной работы"

  network_id = yandex_vpc_network.k8s-net.id

  master {
    version = var.cluster_version

    regional {
      region = "ru-central1"
      location {
        zone      = var.zone
        subnet_id = yandex_vpc_subnet.k8s-subnet.id
      }
    }

    maintenance_policy {
      auto_upgrade = false
    }

    public_ip = true   # внешний адрес мастера, чтобы работать с него снаружи
  }

  service_account_id      = yandex_iam_service_account.sa.id
  node_service_account_id = yandex_iam_service_account.sa.id

  release_channel = "RAPID"
}

# --- Группа узлов ---------------------------------------------------

resource "yandex_kubernetes_node_group" "workers" {
  cluster_id = yandex_kubernetes_cluster.k8s.id
  name       = "${var.cluster_name}-workers"
  version    = var.cluster_version

  instance_template {
    platform_id = "standard-v2"

    network_interface {
      subnet_ids = [yandex_vpc_subnet.k8s-subnet.id]
      nat        = true
    }

    resources {
      cores  = var.node_cores
      memory = var.node_memory
    }

    boot_disk {
      type = "network-ssd"
      size = 50
    }

    scheduling_policy {
      preemptible = false
    }

    container_runtime {
      type = "containerd"
    }
  }

  scale_policy {
    fixed_scale {
      size = var.node_count
    }
  }

  allocation_policy {
    location {
      zone = var.zone
    }
  }

  maintenance_policy {
    auto_upgrade = false
    auto_repair  = true
  }
}

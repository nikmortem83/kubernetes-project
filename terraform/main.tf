terraform {
  required_version = ">= 1.0.0"
  backend "local" { # Для minikube. В Yandex Cloud замени на yandex
    path = "terraform.tfstate"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Модуль кластера (заглушка для minikube, в YC будет реальный ресурс)
module "k8s_cluster" {
  source = "./modules/cluster"
  env    = var.environment # "minikube" или "yc"
}

# Модуль ингресса (NGINX)
module "ingress" {
  source = "./modules/ingress"
  cluster_name = module.k8s_cluster.name
}

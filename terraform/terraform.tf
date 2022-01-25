terraform {
  cloud {
    organization = "jonas"

    workspaces {
      name = "Home"
    }
  }

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }
    rke = {
      source  = "rancher/rke"
      version = "1.3.0"
    }
  }
}

provider "helm" {
  kubernetes {
    # config_path = "~/.kube/config"
    host                   = yamldecode(rke_cluster.cluster.certificates[0].config).clusters[0].cluster.server
    cluster_ca_certificate = base64decode(yamldecode(rke_cluster.cluster.certificates[0].config).clusters[0].cluster.certificate-authority-data)

    client_certificate = base64decode(yamldecode(rke_cluster.cluster.certificates[0].config).users[0].user.client-certificate-data)
    client_key         = base64decode(yamldecode(rke_cluster.cluster.certificates[0].config).users[0].user.client-key-data)
  }
}

provider "rke" {
  debug    = true
  log_file = "rke.log"
}

# TODO: FIX
# resource "null_resource" "docker_install" {
#   triggers = {
#     setup_vm_template   = file("setup_vm_template.sh")
#     connection_type     = "ssh"
#     connection_user     = "root"
#     connection_password = var.pve_password
#     connection_host     = var.pve_host
#   }

#   connection {
#     type     = self.triggers.connection_type
#     user     = self.triggers.connection_user
#     password = self.triggers.connection_password
#     host     = self.triggers.connection_host
#   }

#   provisioner "remote-exec" {
#     script = "setup_vm_template.sh"
#   }

#   provisioner "remote-exec" {
#     when   = destroy
#     inline = ["qm destroy 1000"]
#   }
# }

resource "rke_cluster" "cluster" {
  kubernetes_version = "v1.22.4-rancher1-1"

  nodes {
    node_name         = "kirkby"
    hostname_override = "kirkby"
    # address           = "k8s-${nodes.value}.home.jonassjodin.com"
    address          = "kirkby"
    internal_address = "kirkby"
    port             = "22"
    user             = "jonas"
    role             = ["controlplane", "worker", "etcd"]
    ssh_key          = file("~/.ssh/id_rsa")
  }
}

resource "local_file" "kubeconfig" {
  content  = rke_cluster.cluster.certificates[0].config
  filename = "${path.module}/kubeconfig.yaml"
}

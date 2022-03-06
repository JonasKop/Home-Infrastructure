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
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.1.0"
    }
    rke = {
      source  = "rancher/rke"
      version = "1.3.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "0.6.3"
    }
  }
}

provider "helm" {
  kubernetes {
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

resource "rke_cluster" "cluster" {
  kubernetes_version = "v1.22.4-rancher1-1"

  nodes {
    node_name         = "kirkby"
    hostname_override = "kirkby"
    address           = "kirkby"
    internal_address  = "kirkby"
    port              = "22"
    user              = "jonas"
    role              = ["controlplane", "worker", "etcd"]
    ssh_key           = file("~/.ssh/id_rsa")
  }
}

resource "local_file" "kubeconfig" {
  content  = rke_cluster.cluster.certificates[0].config
  filename = "${path.module}/kubeconfig.yaml"
}

data "sops_file" "secrets" {
  source_file = "../secrets.enc.yaml"
}

locals {
  secrets = yamldecode(data.sops_file.secrets.raw)

  apps = [
    {
      name = "ddclient",
      values = {
        password = local.secrets.ddclient.password
      }
    },
    {
      name = "home-assistant",
      values = {
        gitRepository = "https://github.com/JonasKop/Home-Assistant.git"

        postgresqlUsername = local.secrets.homeAssistant.postgresql.username
        postgresqlPassword = local.secrets.homeAssistant.postgresql.password
        postgresqlDatabase = local.secrets.homeAssistant.postgresql.database

        spotifyClientId     = local.secrets.homeAssistant.spotify.clientId
        spotifyClientSecret = local.secrets.homeAssistant.spotify.clientSecret

        mqttUsername = local.secrets.homeAssistant.mqtt.username
        mqttPassword = local.secrets.homeAssistant.mqtt.password

        networkKey = indent(6, yamlencode(local.secrets.homeAssistant.zigbee2mqtt.networkKey))

        googleProjectId      = local.secrets.homeAssistant.google.projectId
        googleServiceAccount = indent(4, local.secrets.homeAssistant.google.serviceAccount)
      }
    }
  ]
}


resource "helm_release" "longhorn" {
  name             = "longhorn"
  namespace        = "longhorn-system"
  create_namespace = true

  chart      = "longhorn"
  repository = "https://charts.longhorn.io"
  version    = "1.2.3"
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true

  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.6.1"

  values = [templatefile("../values/cert-manager.values.tmpl.yaml", {})]
}

resource "helm_release" "issuers" {
  name = "issuers"

  chart = "../charts/issuers"

  depends_on = [
    helm_release.cert_manager
  ]
}

resource "helm_release" "prometheus_grafana" {
  name             = "prometheus-grafana"
  namespace        = "monitoring"
  create_namespace = true

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "31.0.0"

  values = [templatefile("../values/prometheus-grafana.values.tmpl.yaml", {
    clusterIssuer = "letsencrypt-prod",
    fqdn          = "grafana.${local.secrets.dns}"
    adminPassword = random_password.grafana.result
  })]

  depends_on = [
    helm_release.issuers,
    helm_release.longhorn
  ]
}

resource "helm_release" "harbor" {
  name             = "harbor"
  namespace        = "harbor"
  create_namespace = true

  repository = "https://helm.goharbor.io"
  chart      = "harbor"
  version    = "1.8.1"

  values = [templatefile("../values/harbor.values.tmpl.yaml", {
    clusterIssuer = "letsencrypt-prod",
    fqdn          = "harbor.${local.secrets.dns}"
    adminPassword = random_password.harbor.result
  })]

  depends_on = [
    helm_release.issuers,
    helm_release.longhorn
  ]
}

resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  namespace        = "argo-cd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "3.33.7"

  depends_on = [
    helm_release.longhorn,
    helm_release.prometheus_grafana
  ]

  values = [templatefile("./argocd.values.yaml", {
    argoPassword        = null_resource.argo_cd_password.triggers.value,
    fqdn                = "argo-cd.${local.secrets.dns}"
    githubJonasUsername = local.secrets.argocd.credentials.githubJonas.username
    githubJonasPassword = local.secrets.argocd.credentials.githubJonas.password
    apps = {
      for app in local.apps : app.name => indent(6, templatefile("../argo-apps/${app.name}.app.tmpl.yaml", {
        values = indent(6, templatefile("../values/${app.name}.values.tmpl.yaml", app.values))
      }))
    }
  })]
}

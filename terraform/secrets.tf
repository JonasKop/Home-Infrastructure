resource "random_password" "grafana" {
  length  = 64
  special = false
}

resource "random_password" "harbor" {
  length  = 64
  special = false
}

resource "random_password" "argo_cd" {
  length  = 64
  special = false
}

resource "null_resource" "argo_cd_password" {
  triggers = {
    orig  = random_password.argo_cd.result
    value = bcrypt(random_password.argo_cd.result)
  }

  lifecycle {
    ignore_changes = [triggers["value"]]
  }
}

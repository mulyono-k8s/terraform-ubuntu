
terraform {
  required_version = ">= 1.5.0"
}

# ======================================
# INSTALL DOCKER ENGINE
# ======================================

resource "terraform_data" "docker" {
  triggers_replace = [
    filesha256("${path.module}/install-docker.sh")
  ]

  provisioner "local-exec" {
    command = "bash '${path.module}/install-docker.sh'"
    interpreter = ["/bin/bash", "-c"]
  }
}

# ======================================
# INSTALL KIND AND KUBECTL
# ======================================

resource "terraform_data" "tools" {
  depends_on = [
    terraform_data.docker
  ]

  triggers_replace = [
    filesha256("${path.module}/install-tools.sh"),
    var.kubernetes_node_image
  ]

  provisioner "local-exec" {
    command = "bash '${path.module}/install-tools.sh' install '${replace(var.kubernetes_node_image, "kindest/node:", "")}'"
    interpreter = ["/bin/bash", "-c"]
  }
}

# ======================================
# CREATE KUBERNETES CLUSTER
# ======================================

resource "terraform_data" "kubernetes" {
  depends_on = [
    terraform_data.docker,
    terraform_data.tools
  ]

  input = var.cluster_name

  triggers_replace = [
    var.cluster_name,
    var.kubernetes_node_image,
    var.worker_count
  ]

  # CREATE CLUSTER
  provisioner "local-exec" {
    command = "bash '${path.module}/install-tools.sh' create '${var.cluster_name}' '${var.kubernetes_node_image}' '${var.worker_count}' '${path.module}/kubeconfig'"

    interpreter = ["/bin/bash", "-c"]
  }

  # DESTROY CLUSTER
  provisioner "local-exec" {
    when = destroy

    command = "sg docker -c \"kind delete cluster --name '${self.input}'\" || true"

    interpreter = ["/bin/bash", "-c"]
  }
}

# ======================================
# CONFIGURE KUBECONFIG ENVIRONMENT
# ======================================

resource "terraform_data" "kubeconfig_env" {
  depends_on = [
    terraform_data.kubernetes
  ]

  provisioner "local-exec" {
    command = "CONFIG_LINE=\"export KUBECONFIG='${path.module}/kubeconfig'\"; grep -Fqx \"$CONFIG_LINE\" \"$HOME/.bashrc\" || printf '%s\\n' \"$CONFIG_LINE\" >> \"$HOME/.bashrc\""

    interpreter = ["/bin/bash", "-c"]
  }
}


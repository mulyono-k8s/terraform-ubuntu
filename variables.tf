
variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "wsl-k8s-cluster"
}

variable "kubernetes_node_image" {
  description = "Kind Kubernetes node image"
  type        = string
  default     = "kindest/node:v1.34.0"
}

variable "worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 5
    error_message = "Worker count must be between 1 and 5."
  }
}

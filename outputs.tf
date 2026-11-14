
output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "kubernetes_node_image" {
  description = "Kubernetes node image"
  value       = var.kubernetes_node_image
}

output "worker_count" {
  description = "Number of worker nodes"
  value       = var.worker_count
}

output "kubeconfig_path" {
  description = "Kubeconfig file location"
  value       = "${path.module}/kubeconfig"
}

output "kubectl_command" {
  description = "Command to access Kubernetes"
  value       = "export KUBECONFIG=${path.module}/kubeconfig"
}

output "verify_nodes" {
  value = "kubectl get nodes -o wide"
}

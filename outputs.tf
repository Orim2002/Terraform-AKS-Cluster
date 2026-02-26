output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "resource_group_name" {
  description = "Name of the Azure Resource Group"
  value       = azurerm_resource_group.main.name
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the AKS cluster (save to ~/.kube/config or use KUBECONFIG)"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "argocd_url" {
  description = "ArgoCD web UI URL"
  value       = "https://argocd.${var.base_domain}"
}

output "grafana_url" {
  description = "Grafana web UI URL"
  value       = "https://grafana.${var.base_domain}"
}

output "preview_environment_domain" {
  description = "Domain pattern for preview environments created by the operator"
  value       = "pr-<PR_NUMBER>.preview.${var.base_domain}"
}

output "get_ingress_ip" {
  description = "Command to retrieve the external IP of the nginx ingress LoadBalancer"
  value       = "kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
}

output "get_argocd_password" {
  description = "Command to retrieve the initial ArgoCD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# ── Azure Credentials ────────────────────────────────────────────────────────

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Service Principal Client Secret (omit when use_oidc = true)"
  type        = string
  sensitive   = true
  default     = null
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

# ── AKS Cluster ──────────────────────────────────────────────────────────────

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "my-rg"
}

variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "my-aks-cluster"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = "my-aks"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "VM size for the default node pool"
  type        = string
  default     = "Standard_DC2s_v3"
}

# ── Ingress & DNS ─────────────────────────────────────────────────────────────

variable "base_domain" {
  description = "Base domain used for all ingress hostnames (e.g. argocd.<base_domain>, grafana.<base_domain>)"
  type        = string
  default     = "orima.com"
}

# ── Grafana ───────────────────────────────────────────────────────────────────

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt ACME registration"
  type        = string
}

# ── Workload Identity ─────────────────────────────────────────────────────────

variable "use_oidc" {
  description = "Use OIDC authentication for the azurerm provider (set true when running via GitHub Actions)"
  type        = bool
  default     = false
}

variable "operator_namespace" {
  description = "Kubernetes namespace where the operator is deployed"
  type        = string
  default     = "operator"
}

variable "operator_service_account" {
  description = "Kubernetes service account name used by the operator pod (must match Helm release name + '-operator-sa')"
  type        = string
  default     = "custom-operator-operator-sa"
}

# User-assigned managed identity for the operator pod.
# The operator's Kubernetes service account is federated to this identity,
# allowing it to authenticate to Azure services (Key Vault, ACR, etc.)
# without any static credentials mounted in the pod.

resource "azurerm_user_assigned_identity" "operator" {
  name                = "${var.cluster_name}-operator-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = {
    managed-by = "terraform"
    purpose    = "operator-workload-identity"
  }
}

# Federated identity credential — binds the K8s service account to the managed identity.
# When a pod runs as the annotated service account, Azure AD issues it a token
# for this managed identity without any secret.
resource "azurerm_federated_identity_credential" "operator" {
  name                = "operator-k8s-federated"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.operator.id

  audience = ["api://AzureADTokenExchange"]
  issuer   = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject  = "system:serviceaccount:${var.operator_namespace}:${var.operator_service_account}"
}

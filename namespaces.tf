# All four namespaces are created after the AKS cluster is ready.
# Each namespace is labelled so that it can be easily identified.

resource "kubernetes_namespace" "operator" {
  metadata {
    name = "operator"
    labels = {
      managed-by = "terraform"
      purpose    = "custom-preview-operator"
    }
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      managed-by = "terraform"
      purpose    = "prometheus-grafana"
    }
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}

# The operator creates Deployment / Service / Ingress objects for each
# PreviewEnvironment CR inside this namespace.
resource "kubernetes_namespace" "preview_environments" {
  metadata {
    name = "preview-environments"
    labels = {
      managed-by = "terraform"
      purpose    = "pr-preview-environments"
    }
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      managed-by = "terraform"
      purpose    = "argocd"
    }
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}

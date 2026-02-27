# ── NGINX Ingress Controller ──────────────────────────────────────────────────
# Installed into its own namespace (ingress-nginx).
# SSL-passthrough is enabled so ArgoCD's gRPC traffic works correctly.

resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.1"
  wait             = true

  values = [
    yamlencode({
      controller = {
        # Enable SSL passthrough so ArgoCD TLS reaches its own server
        extraArgs = {
          enable-ssl-passthrough = ""
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            # Retain the external IP when the service is recreated
            "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/healthz"
          }
        }
      }
    })
  ]

  depends_on = [azurerm_kubernetes_cluster.main]
}

# ── cert-manager ──────────────────────────────────────────────────────────────
# Handles TLS certificate issuance for Grafana and preview-environment ingresses.

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.15.0"
  wait             = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}

# Give the cert-manager webhook time to become ready before creating Issuers.
resource "time_sleep" "wait_for_cert_manager" {
  depends_on      = [helm_release.cert_manager]
  create_duration = "30s"
}

# Let's Encrypt ClusterIssuer — used by the operator (pr-*.preview.<domain> ingresses)
# and by the Grafana/ArgoCD ingresses.
# kubectl_manifest (gavinbunney/kubectl) is used instead of kubernetes_manifest
# because it defers API validation to apply time, avoiding the "no client config"
# error that occurs when the cluster does not yet exist at plan time.
resource "kubectl_manifest" "letsencrypt_cluster_issuer" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-issuer"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-account-key"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                ingressClassName = "nginx"
              }
            }
          }
        ]
      }
    }
  })

  depends_on = [time_sleep.wait_for_cert_manager]
}

# ── ArgoCD ────────────────────────────────────────────────────────────────────
# Installed in the argocd namespace created in namespaces.tf.
#
# The server runs in --insecure mode (plain HTTP internally) so nginx can
# terminate TLS.  SSL-passthrough is NOT used here — nginx decrypts HTTPS and
# forwards HTTP to the ArgoCD server, which keeps the ingress config simple.
#
# Access:  https://argocd.<base_domain>
# Initial password:  kubectl -n argocd get secret argocd-initial-admin-secret \
#                      -o jsonpath='{.data.password}' | base64 -d

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "7.4.4"
  wait       = true

  values = [
    yamlencode({
      server = {
        # Run ArgoCD in HTTP mode; TLS is terminated at the nginx ingress
        extraArgs = ["--insecure"]

        ingress = {
          enabled           = true
          ingressClassName  = "nginx"
          hostname          = "argocd.${var.base_domain}"
          tls               = true

          annotations = {
            "cert-manager.io/cluster-issuer"               = "letsencrypt-issuer"
            "nginx.ingress.kubernetes.io/ssl-redirect"      = "true"
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.nginx_ingress,
    kubectl_manifest.letsencrypt_cluster_issuer,
  ]
}

# ── kube-prometheus-stack (Prometheus + Grafana) ──────────────────────────────
# Installed in the monitoring namespace created in namespaces.tf.
#
# Prometheus is configured to discover ServiceMonitors in ALL namespaces,
# which lets it scrape the operator's metrics service (monitoring namespace
# hosts the ServiceMonitor, but the operator lives in the operator namespace).
#
# Access:  https://grafana.<base_domain>  (admin / <grafana_admin_password>)

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "61.3.2"
  wait       = true
  # The chart has many CRDs and can take a while to deploy
  timeout = 600

  values = [
    yamlencode({
      grafana = {
        adminPassword = var.grafana_admin_password

        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hosts            = ["grafana.${var.base_domain}"]

          annotations = {
            "cert-manager.io/cluster-issuer"          = "letsencrypt-issuer"
            "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
          }

          tls = [
            {
              secretName = "grafana-tls"
              hosts      = ["grafana.${var.base_domain}"]
            }
          ]
        }
      }

      prometheus = {
        prometheusSpec = {
          # Scrape ALL ServiceMonitors in the cluster, not just those created
          # by this Helm release — allows the operator's ServiceMonitor to work.
          serviceMonitorSelectorNilUsesHelmValues = false
          serviceMonitorSelector                  = {}
          podMonitorSelectorNilUsesHelmValues     = false
          podMonitorSelector                      = {}
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.nginx_ingress,
    kubectl_manifest.letsencrypt_cluster_issuer,
  ]
}

# Terraform AKS Cluster

Terraform configuration that provisions the full AKS infrastructure on Azure — including the Kubernetes cluster and all supporting tools installed via Helm (NGINX, cert-manager, ArgoCD, Prometheus/Grafana).

---

## What Gets Provisioned

| Resource | Details |
|----------|---------|
| Azure Resource Group | Container for all resources |
| AKS Cluster | Managed Kubernetes, SystemAssigned identity, Azure CNI, OIDC issuer enabled |
| NGINX Ingress Controller | LoadBalancer service |
| cert-manager | TLS certificate issuance via Let's Encrypt (ACME HTTP-01) |
| ArgoCD | GitOps controller, exposed at `argocd.<base_domain>` |
| kube-prometheus-stack | Prometheus + Grafana, exposed at `grafana.<base_domain>` |
| Namespaces | `argocd`, `monitoring`, `preview-environments`, `operator` |
| Managed Identity | User-assigned identity for the operator pod (Workload Identity) |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- An Azure subscription with Contributor access
- A Service Principal with Contributor role
- A public domain with DNS pointing to the NGINX LoadBalancer IP (required for Let's Encrypt)

---

## Remote State Backend

Terraform state is stored in **Azure Blob Storage** (`tfstateorima` storage account, `tfstate` container). This provides:
- **Locking** — blob leases prevent concurrent applies from corrupting state
- **Security** — state file (which contains secrets) never lives locally or in git
- **Durability** — Azure-managed redundancy

### First-time backend setup

Run this **once** before the first `terraform init`:

```bash
./setup-backend.sh
```

Then initialize Terraform:

```bash
terraform init
```

If the state lock gets stuck (e.g. after a failed apply), break it with:

```bash
ACCOUNT_KEY=$(az storage account keys list --account-name tfstateorima --resource-group tfstate-rg --query "[0].value" -o tsv)
az storage blob lease break \
  --account-name tfstateorima \
  --container-name tfstate \
  --blob-name aks-cluster.terraform.tfstate \
  --account-key "$ACCOUNT_KEY"
```

---

## Setup

### 1. Create a Service Principal

```bash
az login
export SUB_ID=$(az account show --query id -o tsv)

az ad sp create-for-rbac \
  --name "terraform-sp" \
  --role Contributor \
  --scopes /subscriptions/$SUB_ID
```

Save the output — you'll need `appId`, `password`, `tenant`.

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
subscription_id        = "your-subscription-id"
client_id              = "your-app-id"
client_secret          = "your-password"
tenant_id              = "your-tenant-id"

resource_group_name    = "my-rg"
cluster_name           = "my-aks-cluster"
location               = "eastus"
node_count             = 2
vm_size                = "Standard_DC2s_v3"

base_domain            = "yourdomain.com"
grafana_admin_password = "your-secure-password"
letsencrypt_email      = "you@example.com"
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

---

## Accessing the Cluster

After apply, retrieve the kubeconfig:

```bash
az aks get-credentials \
  --resource-group my-rg \
  --name my-aks-cluster
```

---

## Accessing ArgoCD

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

Then open: `https://argocd.<base_domain>`

---

## Accessing Grafana

Open: `https://grafana.<base_domain>`
Credentials: `admin` / value of `grafana_admin_password`

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `location` | `eastus` | Azure region |
| `resource_group_name` | `my-rg` | Resource group name |
| `cluster_name` | `my-aks-cluster` | AKS cluster name |
| `node_count` | `2` | Number of worker nodes |
| `vm_size` | `Standard_DC2s_v3` | Node VM size |
| `base_domain` | — | Base domain for all ingress hostnames |
| `grafana_admin_password` | — | Grafana admin password (required) |
| `letsencrypt_email` | — | Email for Let's Encrypt ACME registration (required) |
| `use_oidc` | `false` | Use OIDC auth for the azurerm provider (set `true` in GitHub Actions) |
| `operator_namespace` | `operator` | Namespace where the operator is deployed |
| `operator_service_account` | `custom-operator-operator-sa` | Operator pod service account name |

---

## Outputs

After apply, useful values are printed:

```bash
terraform output operator_client_id   # set as workloadIdentity.clientId in Helm
terraform output oidc_issuer_url       # AKS OIDC issuer URL
terraform output kube_config_raw       # raw kubeconfig (sensitive)
```

---

## Workload Identity

The Terraform config creates a user-assigned managed identity for the operator pod and a federated identity credential linking the operator's Kubernetes service account to that identity. This allows the operator pod to authenticate to Azure services without any mounted secret.

After `terraform apply`, set the following in ArgoCD's Helm values for the operator app:

```yaml
workloadIdentity:
  enabled: true
  clientId: "<value of terraform output operator_client_id>"
```

---

## Destroy

```bash
terraform destroy
```

---

## Notes

- `terraform.tfvars` is gitignored — never commit secrets
- TLS certificates are issued by Let's Encrypt via ACME HTTP-01 challenge — requires the NGINX LoadBalancer IP to be publicly reachable before `terraform apply`
- Prometheus is configured with `serviceMonitorSelectorNilUsesHelmValues: false` so it discovers ServiceMonitors from all namespaces, including the operator's

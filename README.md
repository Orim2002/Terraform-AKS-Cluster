# Terraform AKS Cluster

Terraform configuration that provisions the full AKS infrastructure on Azure — including the Kubernetes cluster and all supporting tools installed via Helm (NGINX, cert-manager, ArgoCD, Prometheus/Grafana).

---

## What Gets Provisioned

| Resource | Details |
|----------|---------|
| Azure Resource Group | Container for all resources |
| AKS Cluster | Managed Kubernetes, SystemAssigned identity, Azure CNI |
| NGINX Ingress Controller | LoadBalancer service, SSL passthrough enabled |
| cert-manager | TLS certificate issuance, `selfsigned-issuer` ClusterIssuer |
| ArgoCD | GitOps controller, exposed at `argocd.<base_domain>` |
| kube-prometheus-stack | Prometheus + Grafana, exposed at `grafana.<base_domain>` |
| Namespaces | `argocd`, `monitoring`, `preview-environments`, `operator` |

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- An Azure subscription with Contributor access
- A Service Principal with Contributor role

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

Then initialize Terraform and migrate any existing local state:

```bash
terraform init -migrate-state
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
subscription_id      = "your-subscription-id"
client_id            = "your-app-id"
client_secret        = "your-password"
tenant_id            = "your-tenant-id"

resource_group_name  = "my-rg"
cluster_name         = "my-aks-cluster"
location             = "eastus"
node_count           = 2
vm_size              = "Standard_DC2s_v3"

base_domain          = "yourdomain.com"
grafana_admin_password = "your-secure-password"
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
Default credentials: `admin` / value of `grafana_admin_password`

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `location` | `eastus` | Azure region |
| `resource_group_name` | `my-rg` | Resource group name |
| `cluster_name` | `my-aks-cluster` | AKS cluster name |
| `node_count` | `2` | Number of worker nodes |
| `vm_size` | `Standard_DC2s_v3` | Node VM size |
| `base_domain` | `orima.com` | Base domain for all ingress hostnames |
| `grafana_admin_password` | `admin` | Grafana admin password |

---

## Destroy

```bash
terraform destroy
```

---

## Notes

- `terraform.tfvars` is gitignored — never commit secrets
- The `selfsigned-issuer` ClusterIssuer uses a self-signed certificate — browsers will show a security warning (expected for development)
- Prometheus is configured with `serviceMonitorSelectorNilUsesHelmValues: false` so it discovers ServiceMonitors from all namespaces, including the operator's

#!/bin/bash
# Run this ONCE before your first `terraform init` to create the remote backend.
# The storage account name must be globally unique — change STORAGE_ACCOUNT_NAME if needed.

set -e

RESOURCE_GROUP="tfstate-rg"
LOCATION="eastus"
STORAGE_ACCOUNT_NAME="tfstateorima"
CONTAINER_NAME="tfstate"

echo "Creating resource group: $RESOURCE_GROUP"
az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION"

echo "Creating storage account: $STORAGE_ACCOUNT_NAME"
az storage account create \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

echo "Creating blob container: $CONTAINER_NAME"
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login

echo ""
echo "Backend ready. Now run:"
echo "  terraform init -migrate-state"

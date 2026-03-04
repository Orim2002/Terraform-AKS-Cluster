#!/bin/bash
# Tears down the Terraform remote backend created by setup-backend.sh.
# WARNING: This will permanently delete all Terraform state stored in the backend.

set -e

RESOURCE_GROUP="tfstate-rg"
STORAGE_ACCOUNT_NAME="tfstateorima"
CONTAINER_NAME="tfstate"

echo "WARNING: This will permanently delete the Terraform state backend."
echo "  Resource Group:   $RESOURCE_GROUP"
echo "  Storage Account:  $STORAGE_ACCOUNT_NAME"
echo "  Container:        $CONTAINER_NAME"
echo ""
read -r -p "Are you sure you want to continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo "Deleting blob container: $CONTAINER_NAME"
az storage container delete \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT_NAME" \
  --auth-mode login

echo "Deleting storage account: $STORAGE_ACCOUNT_NAME"
az storage account delete \
  --name "$STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --yes

echo "Deleting resource group: $RESOURCE_GROUP"
az group delete \
  --name "$RESOURCE_GROUP" \
  --yes \
  --no-wait

echo ""
echo "Teardown complete. The remote backend has been removed."
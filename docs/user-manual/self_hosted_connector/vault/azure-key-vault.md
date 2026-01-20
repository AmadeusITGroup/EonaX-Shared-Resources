# Azure Key Vault Requirements

## Table of Contents

- [Introduction](#introduction)
- [Deployment](#deployment)
  - [Prerequisites](#prerequisites)
  - [Deployment Documentation](#deployment-documentation)
  - [Quick Deployment via Azure CLI](#quick-deployment-via-azure-cli)
- [Production Requirements](#production-requirements)
  - [1. Soft Delete and Purge Protection](#1-soft-delete-and-purge-protection)
  - [2. Access Control (RBAC)](#2-access-control-rbac)
  - [3. Network Security](#3-network-security)
  - [4. Audit Logging](#4-audit-logging)
- [EDC Configuration for Azure Key Vault](#edc-configuration-for-azure-key-vault)
  - [Supported Microservices](#supported-microservices)
  - [Authentication Options](#authentication-options)

## Introduction

Azure Key Vault is Microsoft's managed secrets management service that integrates seamlessly with Azure-native workloads. It provides centralized secret storage, key management, and certificate management with enterprise-grade security.

## Deployment

Azure Key Vault is a fully azure managed service. Follow the official Microsoft documentation for deployment.

### Prerequisites

- Azure subscription
- Resource group
- Appropriate RBAC permissions
- Azure CLI or Azure Portal access

### Deployment Documentation

📚 **Official Microsoft Documentation:**
- [Azure Key Vault Quick Start](https://docs.microsoft.com/en-us/azure/key-vault/general/quick-create-portal) - Create vault via Portal
- [Azure Key Vault CLI](https://docs.microsoft.com/en-us/azure/key-vault/general/quick-create-cli) - Create vault using Azure CLI
- [Azure Key Vault Terraform](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) - Infrastructure as Code

### Quick Deployment via Azure CLI

```bash
# Set variables
RESOURCE_GROUP="my-resource-group"
LOCATION="westeurope"
KEYVAULT_NAME="participant1-vault"  # Must be globally unique

# Create resource group (if needed)
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create Azure Key Vault
az keyvault create \
  --name $KEYVAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku standard \
  --enable-rbac-authorization true

# Enable soft delete and purge protection (recommended for production)
az keyvault update \
  --name $KEYVAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --enable-soft-delete true \
  --enable-purge-protection true
```

📚 **Reference:** [Azure Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)

---

## Production Requirements

### 1. Soft Delete and Purge Protection

Enable soft delete to protect against accidental deletion:

```bash
az keyvault update \
  --name $KEYVAULT_NAME \
  --enable-soft-delete true \
  --enable-purge-protection true \
  --retention-days 90
```

📚 **Reference:** [Soft Delete Overview](https://docs.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview)

### 2. Access Control (RBAC)

Use Azure RBAC for fine-grained access control:

```bash
# Assign Key Vault Secrets Officer role to service principal
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee <service-principal-id> \
  --scope /subscriptions/<subscription-id>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KEYVAULT_NAME
```

**Common Roles:**

| Role | Permissions | Use Case |
|------|-------------|----------|
| Key Vault Secrets Officer | Full secret management | Admin operations |
| Key Vault Secrets User | Read secrets only | EDC services (read-only) |
| Key Vault Reader | List and view metadata | Monitoring |

📚 **Reference:** [Azure Key Vault RBAC](https://docs.microsoft.com/en-us/azure/key-vault/general/rbac-guide)

### 3. Network Security

Configure private endpoints for production:

```bash
# Create private endpoint
az network private-endpoint create \
  --name "${KEYVAULT_NAME}-endpoint" \
  --resource-group $RESOURCE_GROUP \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --private-connection-resource-id $(az keyvault show --name $KEYVAULT_NAME --query id -o tsv) \
  --group-id vault \
  --connection-name "${KEYVAULT_NAME}-connection"
```

📚 **Reference:** [Private Link for Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/private-link-service)

### 4. Audit Logging

Enable diagnostic settings for audit logs:

```bash
# Enable diagnostic logging
az monitor diagnostic-settings create \
  --name keyvault-diagnostics \
  --resource $(az keyvault show --name $KEYVAULT_NAME --query id -o tsv) \
  --logs '[{"category": "AuditEvent","enabled": true}]' \
  --workspace <log-analytics-workspace-id>
```

📚 **Reference:** [Azure Key Vault Logging](https://docs.microsoft.com/en-us/azure/key-vault/general/logging)

---

## EDC Configuration for Azure Key Vault

### Supported Microservices

The following EDC microservices support Azure Key Vault configuration:

**✅ Supported Components:**
- Control Plane
- Data Plane
- Identity Hub
- Telemetry Agent

**❌ Not Supported:**
- Kafka Proxy K8s Manager (requires HashiCorp Vault)

### Authentication Options

Azure Key Vault authentication can be configured via environment variables in your Kubernetes deployment definitions. The EDC extension uses `DefaultAzureCredential` which supports multiple authentication methods.

#### Option 1: Service Principal with Client Secret

Add these environment variables to your microservice deployment:

```yaml
env:
  - name: EDC_VAULT_NAME
    value: "participant1-vault"
  - name: AZURE_CLIENT_ID
    value: "<your-client-id>"
  - name: AZURE_CLIENT_SECRET
    value: "<your-client-secret>"
  - name: AZURE_TENANT_ID
    value: "<your-tenant-id>"
```

#### Option 2: Service Principal with Client Certificate

Add these environment variables to your microservice deployment:

```yaml
env:
  - name: EDC_VAULT_NAME
    value: "participant1-vault"
  - name: AZURE_CLIENT_ID
    value: "<your-client-id>"
  - name: AZURE_CLIENT_CERTIFICATE_PATH
    value: "<path-to-certificate.pem>"
  - name: AZURE_CLIENT_CERTIFICATE_PASSWORD
    value: "<certificate-password>"  # Optional if cert is not password-protected
  - name: AZURE_TENANT_ID
    value: "<your-tenant-id>"
```

📚 **Reference:** [EnvironmentCredential](https://docs.microsoft.com/en-us/java/api/com.azure.identity.environmentcredential)

**Official Microsoft Documentation:**
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)
- [Azure Key Vault Best Practices](https://docs.microsoft.com/en-us/azure/key-vault/general/best-practices)
- [Managed Identity Overview](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)
- [AKS Workload Identity](https://docs.microsoft.com/en-us/azure/aks/workload-identity-overview)

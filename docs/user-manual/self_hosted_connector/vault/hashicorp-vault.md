# HashiCorp Vault Requirements

## Table of Contents

- [Introduction](#introduction)
- [Vault Deployment - Complete Step-by-Step Guide](#vault-deployment---complete-step-by-step-guide)
  - [Step 1: Prepare Helm Repository](#step-1-prepare-helm-repository)
  - [Step 2: Configure Production Values](#step-2-configure-production-values)
  - [Step 3: Deploy Vault](#step-3-deploy-vault)
  - [Step 4: Initialize Vault](#step-4-initialize-vault)
  - [Step 5: Create Kubernetes Secret for Root Token](#step-5-create-kubernetes-secret-for-root-token)
  - [Step 6: Create Key-Value v2 Secret Engine](#step-6-create-key-value-v2-secret-engine)
  - [Step 7: Enable Audit logging (production only)](#step-7-enable-audit-logging-production-only)
  - [Step 8: Verify deployment](#step-8-verify-deployment)
  - [Deployment Complete! 🎉](#deployment-complete-)
- [EDC Connector Configuration](#edc-connector-configuration)
  - [Step 1: Create Vault Token and Policy](#step-1-create-vault-token-and-policy)
  - [Step 2: Configure EDC Microservice](#step-2-configure-edc-microservice)
- [Additional Resources](#additional-resources)

## Introduction

HashiCorp Vault is an open-source secrets management tool that provides secure storage and access control for tokens, passwords, certificates, API keys, and other sensitive data. It is the default Vault implementation for EDC connectors in dataspace-ecosystem repository.

## Vault Deployment - Complete Step-by-Step Guide

This section provides a complete deployment workflow for HashiCorp Vault on Kubernetes/OpenShift.

📚 **Official Documentation:**
- [Vault on Kubernetes Deployment Guide](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-raft-deployment-guide) - Complete step-by-step deployment with Integrated Storage (Raft)
- [Production Hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening) - Security best practices

---

### Step 1: Prepare Helm Repository

Add the HashiCorp Helm repository:

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
```

---

### Step 2: Configure Production Values

Create a `values-production.yaml` file with production-ready configuration following the official Kubernetes guide.

#### Production Requirements

##### 1. TLS Encryption (HTTPS)

Production Vault must use HTTPS to protect secrets in transit.

```hcl
listener "tcp" {
  tls_disable = 0  # 0 = enabled
  address = "[::]:8200"
  tls_cert_file = "/vault/userconfig/vault-tls/tls.crt"
  tls_key_file = "/vault/userconfig/vault-tls/tls.key"
  tls_min_version = "tls12"
}
```

📚 [TLS Configuration](https://developer.hashicorp.com/vault/docs/configuration/listener/tcp)

##### 2. High Availability (HA)

Deploy minimum 3 replicas for fault tolerance.

```yaml
server:
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
```

📚 [Vault HA](https://developer.hashicorp.com/vault/docs/concepts/ha)

##### 3. Persistent Storage

Use persistent volumes to survive pod restarts.

```yaml
server:
  dataStorage:
    enabled: true
    size: 50Gi
    storageClass: "fast-ssd"
```

##### 4. Audit Logging

Enable audit logging for compliance.

```bash
vault audit enable file file_path=/vault/audit/audit.log
```

📚 [Audit Devices](https://developer.hashicorp.com/vault/docs/audit)

##### 5. Auto-Unseal (Recommended)

Use cloud KMS to automatically unseal Vault after restarts.

```hcl
seal "azurekeyvault" {
  tenant_id      = "your-tenant-id"
  vault_name     = "vault-unseal-kv"
  key_name       = "vault-unseal-key"
}
```

📚 [Auto-Unseal](https://developer.hashicorp.com/vault/docs/concepts/seal#auto-unseal) | [AWS KMS](https://developer.hashicorp.com/vault/docs/configuration/seal/awskms) | [Azure KV](https://developer.hashicorp.com/vault/docs/configuration/seal/azurekeyvault) | [GCP KMS](https://developer.hashicorp.com/vault/docs/configuration/seal/gcpckms)

---

### Step 3: Deploy Vault

**Production Deployment (HA mode):**

```bash
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  -f values-production.yaml
```

**Development/Testing Deployment (dev mode):**

```bash
helm install vault hashicorp/vault \
  --namespace dev \
  --create-namespace \
  --set "injector.enabled=false" \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root"
```

⚠️ **Never use dev mode in production:** it stores data in memory and has no security.

---

### Step 4: Initialize Vault

Choose the appropriate initialization method based on your deployment:

#### Auto-Unseal Deployments

For deployments with auto-unseal configured (using Azure KV, AWS KMS, etc.):

```bash
# Connect to vault pod
kubectl exec -it -n vault vault-0 -- /bin/sh

# Initialize with recovery keys
vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json > /tmp/init.json

# View the initialization output
cat /tmp/init.json

# Exit the pod
exit
```

---

### Step 5: Create Kubernetes Secret for Root Token

Extract and store the root token in a Kubernetes secret:

**For Standard Kubernetes:**

```bash
# Extract root token from initialization output
ROOT_TOKEN=$(jq -r '.root_token' vault-keys.json)

# Create Kubernetes secret
kubectl create secret generic vault \
  --from-literal=rootToken=$ROOT_TOKEN \
  -n vault
```

**For OpenShift / Auto-Unseal:**

```bash
# Copy init.json from pod
kubectl cp vault/vault-0:/tmp/init.json ./init.json

# Extract root token
ROOT_TOKEN=$(jq -r '.root_token' init.json)

# Create secret in target namespace
kubectl create secret generic vault \
  --from-literal=rootToken=$ROOT_TOKEN \
  -n <target-namespace>

# Example for DEV environment
kubectl create secret generic vault \
  --from-literal=rootToken=$ROOT_TOKEN \
  -n dev
```

---

### Step 6: Create Key-Value v2 Secret Engine

Before EDC services can store secrets, create a KV (Key-Value) secrets engine.

**Set the Vault Token:**

```bash
# Retrieve root token from Kubernetes secret
export VAULT_TOKEN=$(kubectl get secret vault -n vault -o jsonpath='{.data.rootToken}' | base64 -d)

# Verify token is set
echo $VAULT_TOKEN
```

**Enable KV v2 Secret Engine:**

```bash
# Connect to vault pod
kubectl exec -it -n vault vault-0 -- /bin/sh

# Set token inside pod
export VAULT_TOKEN=<your-root-token>

# Enable KV v2 engine at path 'secret'
vault secrets enable -path=secret -version=2 kv

# Exit pod
exit
```

**Alternative: Enable from Outside Pod (if Vault API is accessible):**

```bash
# Set Vault address and token
export VAULT_ADDR=https://vault.example.com:8200
export VAULT_TOKEN=$(kubectl get secret vault -n vault -o jsonpath='{.data.rootToken}' | base64 -d)

# Enable KV v2 engine
vault secrets enable -path=secret -version=2 kv
```

📚 **Reference:** [KV Secrets Engine v2](https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2)

---

### Step 7: Enable Audit logging (production only)

Enable audit logging for compliance and security monitoring:

```bash
# Connect to vault pod
kubectl exec -it -n vault vault-0 -- /bin/sh

# Set token
export VAULT_TOKEN=<your-root-token>

# Enable file audit device
vault audit enable file file_path=/vault/audit/audit.log

# Verify audit device
vault audit list

# Exit pod
exit
```

📚 **Reference:** [Audit Devices](https://developer.hashicorp.com/vault/docs/audit)

---

### Step 8: Verify deployment

Run final checks to ensure Vault is ready:

```bash
# Check all pods are running and unsealed
kubectl get pods -n vault

# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# List enabled secret engines
kubectl exec -n vault vault-0 -- vault secrets list

# Check HA status
kubectl exec -n vault vault-0 -- vault operator raft list-peers
```

**Expected Results:**
- ✅ All pods running (1/1 ready)
- ✅ Vault unsealed (Sealed: false)
- ✅ KV v2 engine enabled at `secret/`
- ✅ Raft peers showing the nodes

---

### Deployment Complete! 🎉

Your HashiCorp Vault is now ready for EDC integration. Next steps:

1. **Configure EDC services** - See [EDC Connector Configuration](#edc-connector-configuration)
2. **Create tokens for services** - See [Token Management for EDC Services](#step-1-create-vault-token-and-policy)

📚 **Additional Resources:**
- [Seal/Unseal Concepts](https://developer.hashicorp.com/vault/docs/concepts/seal)
- [Vault Initialization](https://developer.hashicorp.com/vault/docs/commands/operator/init)
- [Production Hardening](https://developer.hashicorp.com/vault/tutorials/operations/production-hardening)

---

## EDC Connector Configuration

This section explains how to configure EDC connectors to use HashiCorp Vault. All EDC microservices share a common configuration pattern.

**Configuration Flow:**

1. Create Vault token with appropriate policy
2. Store token in Kubernetes Secret
3. Configure EDC microservice to use the token
4. EDC automatically renews the token before expiration

---

### Step 1: Create Vault Token and Policy

#### Do NOT Use Root Token

❌ **Never use the root token for EDC services**

The root token has unlimited privileges and should only be used for:
- Initial Vault setup
- Creating policies and service tokens
- Emergency administration

**Why root token is dangerous:**
- Unlimited access to all secrets
- Cannot be restricted by policies
- If compromised, entire Vault is compromised
- Violates principle of least privilege

#### Creating Service Tokens with Policies

Each EDC participant should have its own dedicated Vault token with restricted access.

📚 **Reference:** [Vault Policies](https://developer.hashicorp.com/vault/docs/concepts/policies)

##### Define Access Policy

Create a policy that grants minimum required permissions for the EDC participant.

**Example Policy - Participant-Specific Access:**

```hcl
# Allow participant to read/write only their own secrets
path "secret/data/participant1/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/participant1/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow participant to list their own secret path
path "secret/metadata/participant1" {
  capabilities = ["list", "read"]
}

# Deny access to other participants' secrets
path "secret/data/*" {
  capabilities = ["deny"]
}

# Allow basic vault operations
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
```

**Policy Capabilities Explained:**

| Path Pattern | Capabilities | Purpose |
|--------------|-------------|---------|
| `secret/data/participant1/*` | create, read, update, delete, list | Full access to participant's secrets |
| `secret/metadata/participant1/*` | create, read, update, delete, list | Manage participant's secret metadata |
| `secret/metadata/participant1` | list, read | List participant's secrets |
| `secret/data/*` | deny | Explicit deny - prevents access to other participants |
| `auth/token/lookup-self` | read | Check own token information |
| `auth/token/renew-self` | update | Renew token before expiration |
| `sys/capabilities-self` | update | Query own permissions |

**Security Benefits:**
- ✅ Least Privilege: Only necessary capabilities granted
- ✅ Participant Isolation: Each participant can only access their own secrets
- ✅ Explicit Deny: Prevents accidental access to other participants
- ✅ Token Renewal: Allows automatic token refresh

📚 **Reference:** [Policy Syntax](https://developer.hashicorp.com/vault/docs/concepts/policies#policy-syntax)

##### Upload Policy to Vault

```bash
# Login to Vault with root token
vault login <root-token>

# Create the policy file
cat > participant1-policy.hcl <<EOT
# Allow participant to read/write only their own secrets
path "secret/data/participant1/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/participant1/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow participant to list their own secret path
path "secret/metadata/participant1" {
  capabilities = ["list", "read"]
}

# Deny access to other participants' secrets
path "secret/data/*" {
  capabilities = ["deny"]
}

# Allow basic vault operations
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
EOT

# Upload policy to Vault
vault policy write participant1-policy participant1-policy.hcl

# Verify policy
vault policy read participant1-policy
```

##### Create Token with Policy

Create a token with the policy and appropriate TTL (Time To Live):

```bash
# Create token for participant1 (720 hour TTL, renewable)
vault token create \
  -policy=participant1-policy \
  -ttl=720h \
  -renewable=true \
  -display-name="participant1-edc-token" \
  -format=json > participant1-token.json
```

**Token Configuration Options:**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `-policy` | participant1-policy | Apply the access policy |
| `-ttl` | 720h | Token expires in 720 hours |
| `-renewable` | true | Token can be renewed before expiration |
| `-display-name` | participant1-edc-token | Human-readable identifier |

⚠️ **Do not forget to save the token securely** as you will need it to create the Kubernetes Secret.

---

### Step 2: Configure EDC Microservice

#### Helm Chart Configuration (Group 1 Microservices)

Configure the EDC microservice (Control Plane, Data Plane, Identity Hub, or Telemetry Agent) to use HashiCorp Vault.

**Applicable to:**
- ✅ Control Plane (`controlplane.vault.hashicorp.*`)
- ✅ Data Plane (`dataplane.vault.hashicorp.*`)
- ✅ Identity Hub (`identityhub.vault.hashicorp.*`)
- ✅ Telemetry Agent (`telemetryagent.vault.hashicorp.*`)

❌ **Not applicable to:** Kafka Proxy Manager (uses different configuration)

---

##### Complete Helm Values Structure

Example for Control Plane (same structure applies to Data Plane, Identity Hub, Telemetry Agent):

```yaml
controlplane:
  vault:
    hashicorp:
      url: "https://vault.vault.svc.cluster.local:8200"
      cert:
        secretName: "tls-ca"
        tlsPath: "/shared/"
      token:
        renewal:
          enabled: true
          renewBuffer: 30
          ttl: 300
        secret:
          name: "participant1-vault-secret"
          tokenKey: "token"
      timeout: 30
      healthCheck:
        enabled: true
        standbyOk: true
      paths:
        secret: /v1/secret
        folder: "participant1"
        health: /v1/sys/health
```

##### Configuration Parameters Reference

| Parameter | Default | Description | Production Value | Required |
|-----------|---------|-------------|------------------|----------|
| **Connection** | | | | |
| `url` | `""` | Vault server URL | `https://vault.vault.svc.cluster.local:8200` | ✅ Yes |
| `timeout` | `30` | Connection timeout (seconds) | `30-60` | Optional |
| **TLS Certificate** | | | | |
| `cert.secretName` | `"tls-ca"` | K8s secret with Vault CA certificate | `"tls-ca"` | ✅ Yes (if HTTPS) |
| `cert.tlsPath` | `"/shared/"` | Mount path for CA certificate | `"/shared/"` | ✅ Yes (if HTTPS) |
| **Token Configuration** | | | | |
| `token.secret.name` | `""` | K8s secret containing Vault token | `"participant1-vault-secret"` | ✅ Yes |
| `token.secret.tokenKey` | `""` | Key within secret containing token | `"token"` | ✅ Yes |
| **Token Renewal** | | | | |
| `token.renewal.enabled` | `false` | Enable automatic token renewal | `true` ⚠️ | Recommended |
| `token.renewal.renewBuffer` | `30` | Renew N seconds before expiration | `30-60` | If renewal enabled |
| `token.renewal.ttl` | `300` | Check interval (seconds) | `300 (5 min)` | If renewal enabled |
| **Health Checks** | | | | |
| `healthCheck.enabled` | `true` | Enable Vault health checks | `true` | Optional |
| `healthCheck.standbyOk` | `true` | Accept standby nodes (HA Vault) | `true` | Optional |
| **Secret Paths** | | | | |
| `paths.secret` | `"/v1/secret"` | KV v2 API path | `"/v1/secret"` | ✅ Yes |
| `paths.folder` | `""` | Folder prefix for isolation | `"participant1"` | Optional |
| `paths.health` | `"/v1/sys/health"` | Health check endpoint | `"/v1/sys/health"` | Optional |

---

##### URL Configuration

| Environment | URL Format | Example | Use Case |
|-------------|-----------|---------|----------|
| Production (Internal) | `https://<service>.<namespace>.svc.cluster.local:<port>` | `https://vault.vault.svc.cluster.local:8200` | Vault in same K8s cluster |
| Production (External) | `https://<domain>:<port>` | `https://vault.example.com:8200` | Vault outside cluster |
| Development | `http://<service>:<port>` | `http://vault:8200` | Local development only |

---

##### TLS Certificate Setup

Create Kubernetes secret with Vault CA certificate:

```bash
# Get Vault CA certificate
kubectl get secret vault-server-tls -n vault -o jsonpath='{.data.ca\.crt}' | base64 -d > vault-ca.crt

# Create secret in dataspace namespace
kubectl create secret generic tls-ca --from-file=ca.crt=vault-ca.crt -n dataspace
```

**How it works:** Kubernetes mounts the certificate at `<tlsPath>/ca.crt` (e.g., `/shared/ca.crt`) for TLS verification.

---

##### Token Renewal Configuration

| Parameter | Value | Behavior |
|-----------|-------|----------|
| `enabled: false` | Default | ⚠️ Token expires after TTL, manual replacement required |
| `enabled: true` | Production | ✅ Automatic renewal before expiration |
| `renewBuffer: 30` | Recommended | Triggers renewal when ≤30 seconds remain |
| `ttl: 300` | Default | Checks token every 5 minutes |

**Requirements:** Vault policy must include `auth/token/renew-self` capability.

---

##### Folder Configuration

Controls secret path organization:

| `folder` Value | Secret `example-key` Path | Use Case |
|----------------|---------------------------|----------|
| `"participant1"` | `secret/data/participant1/example-key` | Multi-tenant - isolate participants |
| `"dev"` | `secret/data/dev/example-key` | Multi-environment - isolate environments |
| `""` (empty) | `secret/data/example-key` | Single-tenant - simpler paths |

---

#### Helm Chart Configuration (Group 2: Kafka Proxy K8s Manager)

⚠️ **IMPORTANT:** Kafka Proxy K8s Manager has a different configuration from other microservices and requires HashiCorp Vault (not compatible with Azure Key Vault).

##### Kafka Proxy Manager Configuration

**Helm Values:**

```yaml
kafkaProxy:
  manager:
    # Init container for Vault CA certificate installation
    initContainers:
      - name: cert-installer
        image: 'eclipse-temurin:21.0.7_6-jre-alpine-3.21'
        command:
          - /bin/sh
        args:
          - '-c'
          - |
            cp $JAVA_HOME/lib/security/cacerts /certificates/cacerts
            keytool -import -trustcacerts -keystore /certificates/cacerts \
              -storepass changeit -noprompt -alias vaultCa -file /certs/tls.crt
        volumeMounts:
          - name: cert-volume
            mountPath: /certs
          - name: cacerts-volume      # Different from Group 1 (cacerts-volume vs shared-volume)
            mountPath: /certificates
    
    # Vault server URL
    vaultAddr: "http://vault:8200"
    
    # Token configuration
    vaultTokenSecret:
      name: "vault-token"       # Kubernetes secret containing token
      key: "token"              # Key in secret with token value
    
    # Vault TLS Configuration
    vaultTls:
      enabled: true             # Enable TLS verification
      caCert:
        secret: "tls-ca"        # Secret containing CA certificate
        key: "tls.crt"          # Key within secret
        path: "/vault-ca/tls.crt"  # Mount path for CA cert
    
    # Vault folder configuration (optional for multi-tenant)
    vaultFolder: ""             # Empty = root level, "consumer" = secret/consumer/
    
    # Directory paths
    namespace: "default"        # Namespace where proxy pods will be deployed
    sharedDir: "/shared"        # Shared directory for queue files
    certDir: "/certificates"    # Directory for cacerts truststore
```

**Configuration Parameters Explained:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| `initContainers` | Init container for Vault CA cert installation | See init container config above |
| `vaultAddr` | Vault server URL | `http://vault:8200` (use HTTPS in production) |
| `vaultTokenSecret.name` | Kubernetes secret with Vault token | `vault-token` |
| `vaultTokenSecret.key` | Key in secret containing token | `token` |
| `vaultTls.enabled` | Enable TLS verification | `true` |
| `vaultTls.caCert.secret` | Secret with Vault CA certificate | `tls-ca` |
| `vaultTls.caCert.key` | Key in secret with CA cert | `tls.crt` |
| `vaultTls.caCert.path` | Mount path for CA certificate | `/vault-ca/tls.crt` |
| `vaultFolder` | Optional folder for multi-tenancy | `""` (empty) or `"consumer"` |
| `namespace` | Kubernetes namespace for proxy pods | `default` |
| `sharedDir` | Directory for queue files | `/shared` |
| `certDir` | Directory for cacerts truststore | `/certificates` |

**Configuration Differences from Group 1:**

| Aspect | Control/Data/Identity Hub | Kafka Proxy Manager |
|--------|---------------------------|---------------------|
| URL Parameter | `vault.hashicorp.url` | `vaultAddr` |
| Token Secret Structure | Nested `vault.hashicorp.token.secret` | Simple `vaultTokenSecret` |
| TLS Config | `cert.secretName`, `cert.tlsPath` | `vaultTls.caCert.*` with explicit path |
| Init Container Volume | `shared-volume` → `/shared` | `cacerts-volume` → `/certificates` |
| Folder Support | Via `vault.hashicorp.paths.folder` | Via `vaultFolder` |
| Token Renewal | Supported via `token.renewal.*` | Not supported |

---

## Additional Resources

- [HashiCorp Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Vault on Kubernetes](https://developer.hashicorp.com/vault/tutorials/kubernetes)
- [EDC Vault Extension](https://github.com/eclipse-edc/Connector/tree/main/extensions/common/vault)
- [Vault Security Model](https://developer.hashicorp.com/vault/docs/internals/security)

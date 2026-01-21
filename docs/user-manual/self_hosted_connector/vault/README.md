# Vault Requirements for EDC Connector

---

## Overview

In the context of the Eclipse Dataspace Components (EDC) connector, a vault is a critical security component that provides secure storage and management of sensitive information. Vaults serve as the central repository for cryptographic keys, secrets, credentials, and other confidential data that the EDC connector requires for its operations.

## Purpose of Vault in EDC Connector

The EDC connector relies on vault systems to ensure the confidentiality, integrity, and security of sensitive data throughout the dataspace ecosystem. The primary purposes of vault integration include:

### 1. Secrets management

- Secure storage of API keys, tokens, and authentication credentials.
- Management of OAuth2 client secrets and authentication tokens.

### 2. Cryptographic key management

- Storage and retrieval of private keys for digital signatures.
- Management of public/private key pairs for encryption and decryption.
- Secure handling of certificate-based authentication credentials.
- Storage of OAuth2 private keys for token generation.

### 3. Configuration security

- Centralized management of sensitive configuration parameters.
- Runtime retrieval of confidential settings without hardcoding.
- Support for dynamic credential rotation and updates.

### 4. Data sovereignty and compliance

- Ensuring sensitive data is stored in compliance with regulatory requirements.
- Providing audit trails for secret access and modifications.
- Supporting data residency and sovereignty policies.

### 5. Multi-component security

- Secure credential sharing across EDC components (Control Plane, Data Plane, etc.).
- Consistent security posture across distributed connector instances.
- Support for Identity Hub, Issuer Service, and other EDC services.

## Vault implementations in EDC

The EDC connector architecture supports multiple vault implementations through a pluggable extension mechanism. This flexibility allows organizations to choose the vault solution that best fits their infrastructure, security policies, and cloud environment.

**Although both HashiCorp Vault and Azure Key Vault are implemented in the Dataspace, Amadeus provides support and operational management only for HashiCorp Vault**.

### 1. HashiCorp Vault

HashiCorp Vault is an industry-standard secrets management solution that provides robust security features and extensive integration capabilities. It is particularly well-suited for on-premises deployments and hybrid cloud environments.

For detailed information about HashiCorp Vault configuration, features, and integration with EDC, please refer to [HashiCorp Vault Configuration Guide](hashicorp-vault.md).

### 2. Azure Key Vault

Azure Key Vault is Microsoft's cloud-native secrets management service, offering seamless integration with Azure services and providing enterprise-grade security features.

For comprehensive details about Azure Key Vault setup, authentication, and EDC integration, please refer to [Azure Key Vault Configuration Guide](azure-key-vault.md).

## HashiCorp Vault vs Azure Key Vault

| Aspect | HashiCorp Vault | Azure Key Vault |
|--------|----------------|-----------------|
| Deployment | Self-hosted (K8s, VMs) | Managed service (Azure cloud) |
| Cost | Infrastructure + maintenance | Pay-per-operation |
| Scaling | Manual HA configuration | Automatic (Azure managed) |
| Authentication | Tokens, AppRole, K8s SA | Managed Identity, Service Principal |
| Network | Any environment | Azure-centric (VNet integration) |
| Maintenance | Self-managed upgrades, patches | Fully managed by Azure |
| Kafka Proxy Support | ✅ Fully supported | ❌ Not supported |
| Best For | On-premises, multi-cloud, full control | Azure-native workloads, minimal ops |

## Vault interface and architecture

The EDC connector defines a standard Vault interface in its Service Provider Interface (SPI) layer. This abstraction allows different vault implementations to be plugged in without changing the core connector logic. The vault implementations are injected at runtime through EDC's dependency injection mechanism.

### Key architectural principles:

- **Abstraction**: Core EDC components interact with the Vault interface, not the specific implementation.
- **Extensibility**: New vault implementations can be added through the extension framework.
- **Default implementations**: The connector provides default vault implementations that can be overridden.
- **Runtime configuration**: Vault selection and configuration are determined at deployment time.

## Security best practices

When working with vaults in the EDC connector environment, the following security best practices should be observed:

- **Never hardcode secrets**: always retrieve secrets from the vault at runtime.
- **Use environment-specific configurations**: maintain separate vault instances for development, staging, and production.
- **Implement proper access controls**: ensure that only authorized components can access specific secrets.
- **Enable audit logging**: track all secret access for security monitoring and compliance.
- **Rotate credentials regularly**: implement automated credential rotation policies.
- **Use secure communication**: always use encrypted connections (HTTPS/TLS) when communicating with vault services.
- **Implement health checks**: monitor vault availability and health to ensure system reliability.

## References

- [Eclipse Dataspace Components Documentation](https://eclipse-edc.github.io/docs/)
- [EDC Connector GitHub Repository](https://github.com/eclipse-edc/Connector)
- [HashiCorp Vault Documentation](https://www.vaultproject.io/docs)
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)

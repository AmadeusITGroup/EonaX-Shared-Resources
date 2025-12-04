# Deployment of a Self Connector into the Participant Infrastructure (Self-Hosted deployment model)

---

## Overview
This page explains the necessary steps for a Participant to join the **Eona-X dataspace** with a Self-Hosted Connector, meaning hosted into the Participant Infrastructure.
---

## Useful Terminology

- **Provider**
    Providers are participants that have data to offer to other participants in the platform. When a provider wants to share data with other participants in the platform, they create data assets containing the information of the data to be shared and policies that allow to restrain the access to these assets. Together (data asset + policies) they represent a contract definition that states what is the data that is being offered and what are the restrictions consumers need to obey in order to consume the data.

- **Consumer**  
    Consumers are participants that consume data offered by providers.

- **Verifiable Credentials (VCs)**  
    They represent your identity on the Eona-X dataspace. They contain the information about each participant and are used to identify and reach agreements for data transfers between providers and consumers. When defining a data asset, the providers can define policies that restrict access based on verifiable credentials (e.g. Only participant with name sncf can consume this data).

- **Dataspace Connector**  
   The dataspace connector is a set of services that allow a participant to connect to the Eona-X dataspace. It contains:
  - Control-plane
  - Data-plane
  - Identity-hub
  - HashiCorp (Vault)

- **Self-Hosted Connector**  
  A connector deployed by the participant in their infrastructure, not managed by the Eona-X platform Operator.

- **Federated Catalogue**  
  A service managed on the Eona-X platform acting as a marketplace for all data assets defined by providers. This is where consumers get the information of what data assets are available for consumption.

---

## Self-Hosted Connector Deployment Steps

### **Prerequisites**
- Kubernetes Cluster  
- CURL or Postman  
- HashiCorp Vault and HashiCorp CLI
- PostgreSQL DB  
- Use the token provided by Amadeus to download the connector image (valid for one month). This image needs to be stored/registered into the Participant Infrastructure (E.g.: into a Docker registry).

Contact Eona-X with your **participant name** and **decentralized identifier (DID)** to request your:
- Federated Catalogue API Key
- Eona-X Membership Verifiable Credential (VC)

---

### **Deployment Steps**

#### 1. Download the Connector Docker Image and store it in the Participant Infrastructure

#### 2. Create a kind Kubernetes cluster

#### 3. Install the Ingress Controller

#### 4. Export EONAX_VERSION variable
```bash
export EONAX_VERSION=X.Y.Z
```

#### 5. Deploy HashiCorp Vault and PostgreSQL Database

#### 6. Navigate to the Connector folder


#### 7. Pull Helm charts and Docker images

#### 8. Expose routes over the internet

#### 9. Set environment variables

Setup the following local connector variables:
- DID_WEB
- DID_WEB_BASE64_URL
- IH_PRESENTATION_URL
- CP_DSP_URL
- DP_PUBLIC_URL

Setup the following Platform/Eona-x variables:
- EONAX_DID_WEB=did:web:test.api.eona-x.dataspace-platform.amadeus.com:ih:did:authority


#### 10. Create `terraform.tfvars`

#### 11. Deploy connector

After this, you should have the connector and its services up and running.


---

The next steps are to initialize and connect to the Eona-X dataspace:


#### Generate Key-Pair
With OpenSSL generate a key-pair and store them into the vault


#### Create Participant Context via `curl` (for postman configure the correct endpoint and replace the environment variables with the actual values)
```bash
curl -X POST -H "Content-Type: application/json" -d "$(cat <<EOF
{
  "participantId": "$DID_WEB",
  "did": "$DID_WEB",
  "active": true,
  "key": {
    "keyId": "my-key",
    "privateKeyAlias": "private-key",
    "publicKeyPem": "$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' public-key.pem)"
  },
  "serviceEndpoints": [
    {
      "id": "credential-service-url",
      "type": "CredentialService",
      "serviceEndpoint": "$IH_PRESENTATION_URL/v1/participants/$DID_WEB_BASE64_URL"
    },
    {
      "id": "dsp-url",
      "type": "DSPMessaging",
      "serviceEndpoint": "$CP_DSP_URL"
    }
  ]
}
EOF
  )" http://<identityhub-host-url>/ih/identity/v1alpha/participants

```

#### Request Creation of Eona-X Membership Verifiable Credential (VC)

To initiate the request for your membership Verifiable Credential (VC), please contact **Eona-X** with your **Decentralized Identifier (DID) and participant name**. Eona-X will forward both your DID and participant name to the **VC issuer**, **who will then issue the credential**.

#### Once confirmation that the VC has been created you can retrieve the VC

```bash
curl -X POST -H "Content-Type: application/json" -d "$(cat <<EOF
{
    "issuerDid": "$EONAX_DID_WEB",
    "holderPid": "$DID_WEB",
    "credentials": [
        {
            "format": "VC1_0_JWT",
            "credentialType": "MembershipCredential"
        }
    ]
}
EOF
)" http:///<identityhub-host-url>/ih/identity/v1alpha/participants/$DID_WEB_BASE64_URL/credentials/request

---

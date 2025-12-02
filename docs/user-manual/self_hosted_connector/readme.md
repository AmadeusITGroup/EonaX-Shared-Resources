
# Deployment of Participant Connector


## Overview
This page explains the necessary steps for a new self-hosted participant to join the **Eona-X dataspace**.

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

- **Self-Hosted Connector**  
  A connector deployed by the participant in their infrastructure, not managed by Eona-X.

- **Federated Catalogue**  
  A service managed by Eona-X acting as a marketplace for all data assets defined by providers. This is where consumers get the information of what data assets are available for consumption.

---

## Self-Hosted Connector Deployment Steps

### **Prerequisites**
- Kubernetes Cluster  
- CURL or Postman  
- Hashicorp Vault CLI  
- PostgreSQL DB  
- Use the token provided by Amadeus to download the connector image (valid for one month).  

Contact Eona-X with your **participant name** and **decentralized identifier (DID)** for:
- Federated Catalogue API Key
- Membership Credentials

---

### **Deployment Steps**

#### 1. Connector Repository
Connector repository can be found [here](https://github.com/AmadeusITGroup/EonaX-Shared-Resources).

#### 2. Create a kind Kubernetes cluster
```bash
kind create cluster -n eonax-cluster --config kind.config.yaml
```

#### 3. Install the Ingress Controller
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

#### 4. Export EONAX_VERSION variable
```bash
export EONAX_VERSION=X.Y.Z
```

#### 5. Deploy Vault and DB
```bash
cd storage
terraform init
terraform apply -auto-approve
```

#### 6. Enter the Connector
```bash
cd connector
```

#### 7. Pull Helm charts and Docker images
```bash
CLUSTER=eonax-cluster
DOCKER_IMAGE_REPO=ghcr.io/amadeusitgroup/dataspace_ecosystem
HELM_CHART_REPO=oci://ghcr.io/amadeusitgroup/dataspace_ecosystem/helm

for i in control-plane data-plane identity-hub; do \
  image=eonax-$i-postgresql-hashicorpvault; \
  
  ## pull the Docker image
  docker pull $DOCKER_IMAGE_REPO/$image:$EONAX_VERSION; \
  ## tag image with version latest
  docker tag $DOCKER_IMAGE_REPO/$image:$EONAX_VERSION $image:latest; \
  ## load image to the cluster
  kind load docker-image $image:latest --name $CLUSTER; \
  
  ## pull Helm chart
  chart=${i//-/}; \
  helm pull $HELM_CHART_REPO/$chart --version $EONAX_VERSION; \
  mv $chart-$EONAX_VERSION.tgz $chart.tgz; \
done
```

#### 8. Expose routes over the internet
- Control Plane DSP URL (port 8282 control plane)
- Data Plane public URL (port 8181 of the data plane)
- Identity Hub presentation URL (port 8282 of the identity hub)
- DID document URL (port 8383 of the identity hub)

#### 9. Set environment variables
```bash
DID_WEB=<your_did>
DID_WEB_BASE64_URL=$(echo -n "$DID_WEB" | base64 | tr '+/' '-_' | tr -d '=')
IH_PRESENTATION_URL=<your_presentation_url>
CP_DSP_URL=<control_plane_DSP_URL>
DP_PUBLIC_URL=<data_plane_public_URL>
EONAX_DID_WEB=did:web:test.api.eona-x.dataspace-platform.amadeus.com:ih:did:authority
```

#### 10. Create `terraform.tfvars`
```bash
cat <<EOF > terraform.tfvars
identity_hub_did_web_url = "$DID_WEB"
control_plane_dsp_url = "$CP_DSP_URL"
data_plane_public_url = "$DP_PUBLIC_URL"
EOF
```

#### 11. Deploy connector
```bash
terraform init
terraform apply -auto-approve
```

After this, you should have the connector and its services up and running.


---

The next steps are to initialize and connect to the Eona-X dataspace:


#### Generate Key-Pair
```bash
openssl genpkey -algorithm RSA -out private-key.pem -pkeyopt rsa_keygen_bits:2048 && \
openssl rsa -pubout -in private-key.pem -out public-key.pem && \
for k in public-key private-key; do VAULT_TOKEN=root VAULT_ADDR=http://localhost/vault vault kv put secret/$k content=@$k.pem; done
```

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
)" http://localhost/ih/identity/v1alpha/participants

```

#### Request Creation of Eona-X Membership Credentials

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
)" http://localhost/ih/identity/v1alpha/participants/$DID_WEB_BASE64_URL/credentials/request


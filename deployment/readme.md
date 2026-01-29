# Eona-X - Minimum Viable Dataspace

## Prerequisite

- Terraform
- Kind
- Docker desktop
- cURL or Postman
- Hashicorp Vault CLI

## Create a local Kubernetes cluster

```bash
kind create cluster -n eonax-cluster --config kind.config.yaml
```

### Install Ingress Controller

We install an Ingress Controller in order to interact with the microservice running in the cluster from the host.

Below command will wait until the ingress controller is ready before returning.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

## Deploy the Vault and DB (optional)

```bash
cd storage
terraform init
terraform apply -auto-approve
```

## Deploy the connector

```bash
cd connector
```

### Specify the Eona-X/EDC version

```bash
EONAX_VERSION=0.4.0
```

### Login to the Docker registry

Use the token provided by Amadeus in order to log to the Docker registry.

```bash
echo $GITHUB_TOKEN | podman login ghcr.io -u amadeusitgroup --password-stdin
echo $GITHUB_TOKEN | helm registry login ghcr.io -u amadeusitgroup --password-stdin
```

### Pull Helm chart and Docker images

```bash
CLUSTER=eonax-cluster
DOCKER_IMAGE_REPO=ghcr.io/amadeusitgroup/dataspace_ecosystem
HELM_CHART_REPO=oci://ghcr.io/amadeusitgroup/dataspace_ecosystem/helm

for i in control-plane data-plane identity-hub telemetry-agent; do \
  image=eonax-$i-postgresql-hashicorpvault; \
  echo "Processing $image..."; \
  ## pull the Docker image
  echo "Pulling image: $DOCKER_IMAGE_REPO/$image:$EONAX_VERSION"; \
  podman pull --tls-verify=false $DOCKER_IMAGE_REPO/$image:$EONAX_VERSION; \
# ## tag image with version latest
  echo "Tagging image as $image:latest"; \
  podman tag $DOCKER_IMAGE_REPO/$image:$EONAX_VERSION $image:latest; \
  ## export image to tar file
  echo "Exporting image to /tmp/$image.tar"; \
  podman save -o /tmp/$image.tar $image:latest; \
  ## load image archive to the cluster
  echo "Loading image archive into kind cluster: $CLUSTER"; \
  kind load image-archive /tmp/$image.tar --name $CLUSTER ; \
  ## verify image is loaded in kind cluster
  echo "Verifying image is loaded in kind cluster..."; \
  podman exec -it $CLUSTER-control-plane crictl images | grep $image || echo "WARNING: Image $image not found in kind cluster!"; \
#     ## pull Helm chart
  chart=${i//-/}; \
  echo "Pulling Helm chart: $chart version $EONAX_VERSION"; \
  helm pull $HELM_CHART_REPO/$chart --version $EONAX_VERSION; \
  mv $chart-$EONAX_VERSION.tgz $chart.tgz; \
  echo "Completed processing $image"; \
  echo "---"; \
done
```

## Routes to be exposed over the internet

4 routes must imperatively be exposed over the internet, as they are used for communication with the other connectors:

- the **Control Plane DSP url** (port 8282 of the control plane)
- the **Data Plane public url** (port 8181 of the data plane)
- the **Identity Hub presentation url** (port 8282 of the identity hub)
- the **DID document url ** (port 8383 of the identity hub)

We strongly recommend to expose these routes through a web application firewall and implements rate limiting.

Set the public facing urls in environment variables as shown below (please take of updating the values based on your
deployment topology as the ones provided below are only relevant for a local deployment).

```bash
DID_WEB=did:web:localhost:ih:did
DID_WEB_BASE64_URL=$(echo -n "$DID_WEB" | base64 | tr '+/' '-_' | tr -d '=')
IH_PRESENTATION_URL=http://localhost/ih/presentation
CP_DSP_URL=http://localhost/cp/dsp
DP_PUBLIC_URL=http://localhost/dp/public
EONAX_DID_WEB=did:web:test.api.eona-x.dataspace-platform.amadeus.com:ih:did:authority
```

Then create the `terraform.tfvars` file:

```bash
cat <<EOF > terraform.tfvars
identity_hub_did_web_url = "$DID_WEB"
control_plane_dsp_url = "$CP_DSP_URL"
data_plane_public_url = "$DP_PUBLIC_URL"
EOF
```

### Deploy the connector

If you are using your own Vault and/or DB, please take care of updating the vault url and token secret name, and the DB
url, username and password in the `variables.tf` file.

```bash
terraform init
terraform apply -auto-approve
```

### Initialize connector

#### Generate key pair

```bash
openssl genpkey -algorithm RSA -out private-key.pem -pkeyopt rsa_keygen_bits:2048 && \
openssl rsa -pubout -in private-key.pem -out public-key.pem && \
for k in public-key private-key; do VAULT_TOKEN=root VAULT_ADDR=http://localhost/vault vault kv put secret/$k content=@$k.pem; done
```

#### Create participant context

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

#### To request an Eona-X Membership Verifiable Credential (VC):

To initiate the request for your membership Verifiable Credential (VC), please contact Eona-X with your Decentralized Identifier (DID) and participant name. Eona-X will forward both your DID and participant name to the VC issuer, who will then issue the credential.

Once you receive confirmation from Eona-X that the VC has been successfully issued, you can proceed to retrieve it by calling the API provided below.

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
```

## Usage of the connector

On top of the public urls mentioned above which are used for interactions with the other connectors, there are 3 urls
that are only for internal usage and should preferably be kept in the company's private network:

- the Control Plane management url (port 8181 of the control plane), those are typically the ones used to define the
  business configuration of the connector.
- the Identity Hub identity url (port 8181 of the identity hub) which is used to write/read credentials from the
  identity hub.
- the Data Plane data url (port 8282 of the Data Plane) which is used to query data the data from a provider.

## Common Vulnerabilities Exposure (CVE)

List of opened CVE records can be
found [here](https://cve.mitre.org/cgi-bin/cvekey.cgi?keyword=eclipse+dataspace+connector).

Each record has a score calculated with
this [calculator](https://www.first.org/cvss/calculator/4.0#CVSS:4.0/AV:N/AC:L/AT:P/PR:H/UI:N/VC:N/VI:N/VA:N/SC:H/SI:H/SA:N/RE:L/U:Green).



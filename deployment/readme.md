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
EDC_VERSION=0.9.1
EONAX_VERSION=0.2.4
```

### Login to the Docker registry

Use the token provided by Amadeus in order to log to the Docker registry.

```bash
GITHUB_TOKEN="<YOUR_TOKEN_HERE>"
echo $GITHUB_TOKEN | docker login ghcr.io -u amadeusitgroup --password-stdin
```

### Pull Helm chart and Docker images

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

### Download SQL files

```bash
jq -r   --arg version "$EDC_VERSION" '.files[] | "https://raw.githubusercontent.com/eclipse-edc/\(.repo)/v\($version)/\(.path)/src/main/resources/\(.file_name)"' sql.json | \
tr -d '\r' | \
while read -r url; do curl -o "./connector/sql/$(basename "$url")"  "$url"; done
```

## Routes to be exposed over the internet

4 routes must imperatively be exposed over the internet, as they are used for communication with the other connectors:

- the Control Plane DSP url (port 8282 of the control plane)
- the Data Plane public url (port 8181 of the data plane)
- the Identity Hub presentation url (port 8282 of the identity hub)
- the DID document (port 8383 of the identity hub)

We strongly recommend to expose these routes through a web application firewall and implements rate limiting.

Set the public facing urls in environment variables as shown below (please take of updating the values based on your
deployment topology as the ones provided below are only relevant for a local deployment).

```bash
DID_WEB=did:web:localhost:ih:did
DID_WEB_BASE64_URL=$(echo -n "$DID_WEB" | base64 | tr '+/' '-_' | tr -d '=')
IH_RESOLUTION_URL=http://localhost/ih/resolution
CP_DSP_URL=http://localhost/cp/dsp
DP_PUBLIC_URL=http://localhost/dp/public
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
      "serviceEndpoint": "$IH_RESOLUTION_URL/v1/participants/$DID_WEB_BASE64_URL"
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

#### Add membership VC to the Identity Hub

Add the membership VC into your Identity Hub (do not forget to replace the request body with the VC provided by
Amadeus):

```bash
curl -X POST -H "Content-Type: application/json" -d "$(cat <<EOF
{
  "participantId": "$DID_WEB",
  "verifiableCredentialContainer": {
    "rawVc": "eyJraWQiOiJkaWQ6d2ViOmF1dGhvcml0eS1pZGVudGl0eWh1YiUzQTgzODM6YXBpOmRpZCNteS1rZXkiLCJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJkaWQ6d2ViOmF1dGhvcml0eS1pZGVudGl0eWh1YiUzQTgzODM6YXBpOmRpZCIsInN1YiI6ImRpZDp3ZWI6cHJvdmlkZXItaWRlbnRpdHlodWIlM0E4MzgzOmFwaTpkaWQiLCJ2YyI6eyJjcmVkZW50aWFsU3ViamVjdCI6W3siaWQiOiJkaWQ6d2ViOnByb3ZpZGVyLWlkZW50aXR5aHViJTNBODM4MzphcGk6ZGlkIiwibmFtZSI6InByb3ZpZGVyIiwibWVtYmVyc2hpcCI6eyJtZW1iZXJzaGlwVHlwZSI6IkZ1bGxNZW1iZXIiLCJzaW5jZSI6IjIwMjMtMDEtMDFUMDA6MDA6MDBaIn19XSwiaWQiOiIzMTkxNWJjOC0wODhjLTQwZDYtYTAxNC03YTk4YmNkNzBiY2IiLCJ0eXBlIjpbIlZlcmlmaWFibGVDcmVkZW50aWFsIiwiTWVtYmVyc2hpcENyZWRlbnRpYWwiXSwiaXNzdWVyIjp7ImlkIjoiZGlkOndlYjphdXRob3JpdHktaWRlbnRpdHlodWIlM0E4MzgzOmFwaTpkaWQiLCJhZGRpdGlvbmFsUHJvcGVydGllcyI6e319LCJpc3N1YW5jZURhdGUiOiIyMDI0LTA4LTE0VDE0OjMzOjQwWiIsImV4cGlyYXRpb25EYXRlIjpudWxsLCJjcmVkZW50aWFsU3RhdHVzIjpbXSwiZGVzY3JpcHRpb24iOm51bGwsIm5hbWUiOm51bGx9LCJpYXQiOjE3MjM2NDYwMjB9.FD4vjPomuKusPdyWlMRcOgbzUhGC7kyliw6My6HFrQzdAcKGC6N_BW-Cg4pHAX4f2O4EhFn5WJr-uB2UaZOHlQ",
    "format": "JWT",
    "credential": {
      "credentialSubject": [
        {
          "id": "$DID_WEB",
          "name": "provider",
          "membership": {
            "membershipType": "FullMember",
            "since": "2023-01-01T00:00:00Z"
          }
        }
      ],
      "id": "31915bc8-088c-40d6-a014-7a98bcd70bcb",
      "type": [
        "VerifiableCredential",
        "MembershipCredential"
      ],
      "issuer": {
        "id": "did:web:eonax-authority-url:api:did",
        "additionalProperties": {}
      },
      "issuanceDate": "2024-08-14T14:33:40Z",
      "expirationDate": null,
      "credentialStatus": [],
      "description": null,
      "name": null
    }
  }
}
EOF
)" http://localhost/ih/identity/v1alpha/participants/$DID_WEB_BASE64_URL/credentials
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



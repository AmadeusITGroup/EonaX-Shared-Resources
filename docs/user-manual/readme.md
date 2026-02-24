# Eona-X Connector - User Manual

## Eona-X platform overview

![platform_overview.png](platform_overview.png)

## Prerequisites

In order to complete this guide, you will need few infos that will be provided by Amadeus:

- the base url for targeting your respective connector, referred as `<CONNECTOR_URL>` hereafter,
- the base url for targeting the federated catalog, referred as `<CATALOG_URL>` hereafter,
- a token for authenticating to your respective connector APIs
- a token for authenticating to the dataspace federated catalog

## Steps for a participant to create a new dataset

All queries detailed in this section are based on
the [Swagger specification](https://eclipse-edc.github.io/Connector/openapi/management-api/) of the Management API of
the EDC
connector.

They require a `x-api-key` header in input containing the token provided by Amadeus to interact with your connector.

### Create dataset

#### Url

```bash
<CONNECTOR_URL>/cp/mgmt/v3/assets (POST)
```

#### Example of request body

```json
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@id": "my-asset-id",
  "properties": {
    "name": "Test Asset",
    "description": "A fancy test asset",
    "documentationUrl": "https://my-swagger-api",
    "logoUrl": "https://my-logo.com",
    "contenttype": "application/json",
    "version": "1.0"
  },
  "dataAddress": {
    "type": "HttpData",
    "baseUrl": "https://your-api-url.com",
    "authKey": "Authorization",
    // alias of the Vault entry containing the access token
    "secretName": "my-secret"
  }
}
```

It is worth mentioning that the structure of the request to create a new dataset is composed of two sections:

- the `properties` which are the public metadata of the dataset and are displayed in the catalog
- the `dataAddress` which contains the information (e.g. baseUrl...) used by the connector to fetch the data
  from the data source → the data address is private and thus is not readable by the other participants!

As of today, the connector supports both APIs using basic auth and oauth2.

Please find in the table below the supported `dataAddress` codesets:

| Category  | Name                     | Description                                                                                                                                                                                                                                                                                                    | Mandatory | Default value |
|-----------|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|---------------|
| Common    | `baseUrl`                | Url of the API serving the data                                                                                                                                                                                                                                                                                | yes       |               |
|           | `path`                   | Path to be appended to the baseUrl                                                                                                                                                                                                                                                                             | no        |               |
|           | `queryParams`            | Query params to be appended to the baseUrl                                                                                                                                                                                                                                                                     | no        |               |
|           | `proxyPath`              | Enable the proxying of path parameters provided by the consumer when request the data                                                                                                                                                                                                                          |           | false         |
|           | `proxyQueryParams`       | Enable the proxying of query parameters provided by the consumer when request the data                                                                                                                                                                                                                         |           | false         |
|           | `header:*`               | Defines headers to be sent when targeting the api, e.g. this `"header:foo":"bar"` will tell the  connector to send the header "foo" with value "bar" when targeting the api. There is no limit on the number of headers that can be provided                                                                   |           |               |
| Base auth | `authKey`                | Name of header in which api key will be sent (e.g. `Authorization`, `x-api-key`...)                                                                                                                                                                                                                            | no        |               |
|           | `authCode`               | The api key to authenticate to the api. Using this approach is strongly discouraged as  it means the api key will be stored in the database. Instead we recommend to use the `secretName` codeset                                                                                                              | no        |               |
|           | `secretName`             | Alias of the secret stored in the vault that contains the api key                                                                                                                                                                                                                                              |           |               |
| Oauth2    | `oauth2:tokenUrl`        | Url of the oauth2 server                                                                                                                                                                                                                                                                                       | yes       |               |
|           | `oauth2:clientId`        | Oauth2 client id                                                                                                                                                                                                                                                                                               | yes       |               |
|           | `oauth2:clientSecretKey` | Alias of the secret stored in the vault that contains the client secret. This is used for the `client_secret` field in the access token request to the oauth2 server. Either `oauth2:clientSecretKey` or `oauth2:privateKeyName` must be provided                                                              | no        |               |
|           | `oauth2:privateKeyName`  | Alias of the secret stored in the vault that contains the private key used to sign the client assertion token. The client assertion token is put in the `client_assertion` field in the access token request to the oauth2 server. Either `oauth2:clientSecretKey` or `oauth2:privateKeyName` must be provided | no        |               |
|           | `oauth2:kid`             | Value of the `kid` header sent in the request to the authorization server                                                                                                                                                                                                                                      | no        |               |

#### Response

If the request is successful, then a code 200 will be returned along with a body containing the id of the dataset:

```json
{
  "@type": "IdResponse",
  "@id": "hello-eonax",
  "createdAt": 1703167675052,
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "edc": "https://w3id.org/edc/v0.0.1/ns/",
    "eonax": "https://w3id.org/eonax/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  }
}
```

### Create secret

If the dataset defined at the previous steps includes a secret within its data address (see secretName and oauth2:
privateKeyName in the examples above), then you need to add the corresponding secret within the connector Vault.

#### Url

```bash
<CONNECTOR_URL>/cp/mgmt/v3/secrets (POST)
```

#### Request body

```json
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "Secret",
  "@id": "my-secret",
  "value": "e47bc29c-4839-40e7-967f-46968f83c36d"
}
```

#### Response

If the request is successful, then a code 200 will be returned along with a body containing the id of the secret:

```json
{
  "@type": "IdResponse",
  "@id": "my-secret",
  "createdAt": 1703167675052,
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "edc": "https://w3id.org/edc/v0.0.1/ns/",
    "eonax": "https://w3id.org/eonax/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  }
}
```

### Create policy

A policy is basically expressing a list of constraints that must be fulfilled by another participant in order to be
able to negotiate access to a given dataset.

#### Url

```bash
<CONNECTOR_URL>/cp/mgmt/v3/policydefinitions (POST)
```

#### Example of request body

```json
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "eox-policy": "https://w3id.org/eonax/policy/"
  },
  "@id": "membership-policy",
  "@type": "PolicyDefinitionDto",
  "policy": {
    "@context": "http://www.w3.org/ns/odrl.jsonld",
    "@type": "http://www.w3.org/ns/odrl/2/Set",
    "permission": [
      {
        "action": "use",
        "constraint": {
          "@type": "Constraint",
          "leftOperand": "eox-policy:Membership",
          "operator": "odrl:eq",
          "rightOperand": "active"
        }
      }
    ]
  }
}
```

All constraints defined in the `permission` field must be fulfilled by the other participant in order to get access.

In the above example, there is one constraint defined in the policy, whose left operand is `eox-policy:Membership`. This
left operand uses the `eox-policy` namespace, wherein the Eona-X specific policies are defined. The table below sums up
the currently available constraints (both in the Eona-X namespace and in the EDC-native one).

| leftOperand syntax                                            | Supported operators                                                   | Supported rightOperand                                                                              | Description | Example                                                                                                                        |
|---------------------------------------------------------------|-----------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------|-------------|--------------------------------------------------------------------------------------------------------------------------------|
| `eox-policy:Membership`                                       | `odrl:eq`                                                             | `active`                                                                                            |             | [membership.json](./policy_examples/membership.json)                                                                           |
| `eox-policy:GenericClaim.$.[CREDENTIAL_TYPE].[PATH_TO_FIELD]` | `odrl:eq`, `odrl:neq`, `odrl:isPartOf`                                | array of strings if operator is `odrl:isPartOf`, a string otherwise                                 |             | [generic_claim.json](./policy_examples/generic_claim.json)                                                                     |
| `edc:inForceDate`                                             | `odrl:eq`, `odrl:neq`, `odrl:gt`, `odrl:gteq`, `odrl:lt`, `odrl:lteq` | fixed time in ISO-8061 UTC or duration expressed in seconds `s`, minutes `m`, hours `h` or days `d` |             | [fixed_time.json](./deprecated_review/inforcedate_fixed_time.json), [duration.json](./deprecated_review/inforcedate_duration.json) |

The `eox-policy:GenericClaim` constraint has a particular syntax, as it enables to evaluate any claim from the consumer
VC. It is composed of three parts:

- the `eox-policy:GenericClaim` prefix,
- the type of VC on which the constraint applies. e.g. `Membership`,
- the path of the field that is evaluated. If the target field is in a nested structure, then `.` is used as separator (
  see example below).

Let's use a concrete example: at the time of writing this document, the Eona-X membership credential is as follows:

```json
{
  "@context": [
    "https://www.w3.org/ns/credentials/v2"
  ],
  "id": "23b792b6-30a5-4699-9c80-dba9ec97a1cf",
  "type": [
    "VerifiableCredential",
    "https://w3id.org/eonax/credentials/MembershipCredential"
  ],
  "issuer": "did:web:eonax.com",
  "issuanceDate": "2024-12-13T12:45:20.633598100Z",
  "credentialSubject": {
    "id": "did:web:eonaxtest.com",
    "name": "eonaxtest",
    "membership": {
      "membershipType": "FullMember",
      "since": "2023-01-01T00:00:00Z"
    }
  }
}
```

The only relevant claim in this membership credential as of now is the `name` field, which is different for every
participant (a list of the current Eona-X participant names can be found at the end of this documentation).

The `eox-policy:GenericClaim` constraint applies on the claim from the `credentialSubject`, thus if we want to express a
constraint that restricts access to participant which are `FullMember`, then we will use the following policy:

```json
{
  "action": "use",
  "constraint": {
    "@type": "Constraint",
    "leftOperand": "eox-policy:GenericClaim.$.MembershipCredential.membership.membershipType",
    "operator": "odrl:eq",
    "rightOperand": "FullMember"
  }
}
```

In the same manner, if we want to restrict the usage to, for example, participants `amadeus` and `sncf` that have active memberships we can find it [here](./policy_examples/combined.json)



> NOTE
: When using at least one Eona-X type of policy, take care of adding the `eox-policy` namespace in the `@Context` (see
above example)
> in order for the connector to know how to properly perform the JSON-LD expansion of the `leftOperand`.


#### Response

If the request is successful, then a code 200 will be returned along with a body containing the id of the policy:

```json
{
  "@type": "IdResponse",
  "@id": "eonax-members-only",
  "createdAt": 1703167855896,
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "edc": "https://w3id.org/edc/v0.0.1/ns/",
    "eonax": "https://w3id.org/eonax/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  }
}
```

### Create contract definition

The contract definition is basically a dataset with its associated policies. Each contract definition points to a
dataset and two policies:

- an `accessPolicy` which defines the non-public requirements for accessing a dataset governed by a contract. These
  requirements are therefore not advertised to the agent. For example, access control policy may require an agent to be
  in a business partner tier.
- a `contractPolicy` which defines the requirements governing use a participant must follow when accessing the data.
  This policy is advertised to agents as part of a contract and are visible in the catalog.

Both policies must be fulfilled by a participant in order to get access to the given contract definition.

#### Url

```bash
<CONNECTOR_URL>/cp/mgmt/v3/contractdefinitions (POST)
```

#### Request body

```json
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "https://w3id.org/edc/v0.0.1/ns/ContractDefinition",
  "accessPolicyId": "my-access-policy-id",
  "contractPolicyId": "my-contract-policy-id",
  "assetsSelector": [
    {
      "@type": "Criterion",
      "operandLeft": "https://w3id.org/edc/v0.0.1/ns/id",
      "operator": "=",
      "operandRight": "my-asset-id"
    }
  ]
}
```

#### Response

If the request is successful, then a code 200 will be returned along with a body containing the id of the contract
definition:

```json
{
  "@type": "IdResponse",
  "@id": "1c6e191e-84bf-4640-b41b-f9ba717e9712",
  "createdAt": 1703167892881,
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "edc": "https://w3id.org/edc/v0.0.1/ns/",
    "eonax": "https://w3id.org/eonax/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  }
}
```

## Dataset discovery

This section is not correlated with the first one, i.e. we are not using the dataset created in the first section.
All APIs from this section requires a x-api-key header in input containing the token provided by Amadeus to interact
with the dataspace federated catalog.

### Federated catalog

#### Url

```bash
<CATALOG_URL>/catalog/mgmt/v1alpha/catalog/query (POST)
```

No request body is required.

#### Response

The response is a list of catalog (one catalog per Eona-X participant). A test participant called `eonaxtest` whose
respective catalog is depicted below.

```json
{
  "@id": "bea94ccf-b582-4c0c-8369-e2787990df86",
  "@type": "http://www.w3.org/ns/dcat#Catalog",
  "https://w3id.org/dspace/v0.8/participantId": "did:web:eonaxtest-identityhub%3A8383:api:did",
  "http://www.w3.org/ns/dcat#dataset": {
    "@id": "hello-eonax",
    "@type": "http://www.w3.org/ns/dcat#Dataset",
    "odrl:hasPolicy": {
      "@id": "YTM1MjcyOWUtYmY3Ny00MDkxLWFkZGUtZWE2YmJkZDFlMTNj:aGVsbG8tZW9uYXg=:MWVjMjJjY2MtMGEyMi00OTU4LTliZDctNDU4NWFjYmE5ZDgz",
      "@type": "odrl:Offer",
      "odrl:permission": {
        "odrl:action": {
          "odrl:type": "http://www.w3.org/ns/odrl/2/use"
        },
        "odrl:constraint": {
          "odrl:leftOperand": "https://w3id.org/edc/v0.0.1/ns/MembershipCredential",
          "odrl:operator": {
            "@id": "odrl:eq"
          },
          "odrl:rightOperand": "active"
        }
      },
      "odrl:prohibition": [],
      "odrl:obligation": []
    },
    "http://www.w3.org/ns/dcat#distribution": {
      "@type": "http://www.w3.org/ns/dcat#Distribution",
      "http://purl.org/dc/terms/format": {
        "@id": "HttpData-PULL"
      },
      "http://www.w3.org/ns/dcat#accessService": {
        "@id": "76c141c1-6f2f-4704-bfa1-fcf734652b25",
        "@type": "http://www.w3.org/ns/dcat#DataService"
      }
    },
    "version": "1.0",
    "name": "Hello Eona-X",
    "description": "An API that says hello to Eona-X",
    "id": "hello-eonax",
    "contenttype": "application/json"
  },
  "http://www.w3.org/ns/dcat#service": {
    "@id": "76c141c1-6f2f-4704-bfa1-fcf734652b25",
    "@type": "http://www.w3.org/ns/dcat#DataService",
    "http://www.w3.org/ns/dcat#endpointDescription": "dspace:connector",
    "http://www.w3.org/ns/dcat#endpointUrl": "http://eonaxtest-controlplane:8282/api/dsp",
    "http://purl.org/dc/terms/terms": "dspace:connector",
    "http://purl.org/dc/terms/endpointUrl": "http://eonaxtest-controlplane:8282/api/dsp"
  },
  "originator": "http://eonaxtest-controlplane:8282/api/dsp",
  "participantId": "did:web:eonaxtest-identityhub%3A8383:api:did",
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "edc": "https://w3id.org/edc/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  }
}
```

This catalog contains a `dataset` field that contains the list of datasets exposed by this
provider. For the `eonaxtest` participant, there is one dataset in this list whose id is `hello-eonax`.
In the following section, we will demonstrate how to request the access to this dataset using the connector APIs, and
finally how to consume the data represented by this dataset.

## Contract negotiation and data transfer

This section is not correlated with the first one, i.e. we are not using the dataset created in the first section.
All queries detailed in this section are based on the Swagger specification of the Management API of the EDC connector.
All APIs from this section requires a `x-api-key` header in input containing the token provided by Amadeus to interact
with your connector.

### Contract negotiation

In order to request access to this dataset, we first need to perform a JSON-LD compaction of the catalog response. The
compacted structure can be obtained simply by copying the content of the catalog into the JSON-LD playground. Then
extract the content of the `hasPolicy` field for the `hello-eonax` dataset in the compacted
structure, which should look similar to:

```json
{
  "@id": "YTM1MjcyOWUtYmY3Ny00MDkxLWFkZGUtZWE2YmJkZDFlMTNj:aGVsbG8tZW9uYXg=:MWVjMjJjY2MtMGEyMi00OTU4LTliZDctNDU4NWFjYmE5ZDgz",
  "@type": "http://www.w3.org/ns/odrl/2/Offer",
  "http://www.w3.org/ns/odrl/2/obligation": [],
  "http://www.w3.org/ns/odrl/2/permission": {
    "http://www.w3.org/ns/odrl/2/action": {
      "http://www.w3.org/ns/odrl/2/type": "http://www.w3.org/ns/odrl/2/use"
    },
    "http://www.w3.org/ns/odrl/2/constraint": {
      "http://www.w3.org/ns/odrl/2/leftOperand": "https://w3id.org/edc/v0.0.1/ns/MembershipCredential",
      "http://www.w3.org/ns/odrl/2/operator": {
        "@id": "http://www.w3.org/ns/odrl/2/eq"
      },
      "http://www.w3.org/ns/odrl/2/rightOperand": "active"
    }
  },
  "http://www.w3.org/ns/odrl/2/prohibition": []
}
```

Then add the `target` and `assigner` fields in the resulting structure as follows:

```json
{
  "@id": "YTM1MjcyOWUtYmY3Ny00MDkxLWFkZGUtZWE2YmJkZDFlMTNj:aGVsbG8tZW9uYXg=:MWVjMjJjY2MtMGEyMi00OTU4LTliZDctNDU4NWFjYmE5ZDgz",
  "@type": "http://www.w3.org/ns/odrl/2/Offer",
  "http://www.w3.org/ns/odrl/2/obligation": [],
  "http://www.w3.org/ns/odrl/2/permission": {
    "http://www.w3.org/ns/odrl/2/action": {
      "http://www.w3.org/ns/odrl/2/type": "http://www.w3.org/ns/odrl/2/use"
    },
    "http://www.w3.org/ns/odrl/2/constraint": {
      "http://www.w3.org/ns/odrl/2/leftOperand": "https://w3id.org/edc/v0.0.1/ns/MembershipCredential",
      "http://www.w3.org/ns/odrl/2/operator": {
        "@id": "http://www.w3.org/ns/odrl/2/eq"
      },
      "http://www.w3.org/ns/odrl/2/rightOperand": "active"
    }
  },
  "http://www.w3.org/ns/odrl/2/prohibition": [],
  "http://www.w3.org/ns/odrl/2/target": {
    "@id": "hello-eonax"
  },
  "http://www.w3.org/ns/odrl/2/assigner": {
    "@id": "did:web:eonaxtest-identityhub%3A8383:api:did"
  }
}
```

Keep note of this resulting json structure, as it will be required to initiate the contract negotiation.

### Initiate Contract Negotiation request

#### Url

```bash
<CONNECTOR_URL>/cp/mgmt/v3/contractnegotiations (POST)
```

#### Request body

Paste the json structure obtained in the previous section into the policy field of the “Initiate Contract“ request, as
such:

```json
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "ContractRequestDto",
  "counterPartyAddress": "http://eonaxtest-controlplane:8282/api/dsp",
  "protocol": "dataspace-protocol-http",
  "policy": {
    "@id": "YTM1MjcyOWUtYmY3Ny00MDkxLWFkZGUtZWE2YmJkZDFlMTNj:aGVsbG8tZW9uYXg=:MWVjMjJjY2MtMGEyMi00OTU4LTliZDctNDU4NWFjYmE5ZDgz",
    "@type": "http://www.w3.org/ns/odrl/2/Offer",
    "http://www.w3.org/ns/odrl/2/obligation": [],
    "http://www.w3.org/ns/odrl/2/permission": {
      "http://www.w3.org/ns/odrl/2/action": {
        "http://www.w3.org/ns/odrl/2/type": "http://www.w3.org/ns/odrl/2/use"
      },
      "http://www.w3.org/ns/odrl/2/constraint": {
        "http://www.w3.org/ns/odrl/2/leftOperand": "https://w3id.org/edc/v0.0.1/ns/MembershipCredential",
        "http://www.w3.org/ns/odrl/2/operator": {
          "@id": "http://www.w3.org/ns/odrl/2/eq"
        },
        "http://www.w3.org/ns/odrl/2/rightOperand": "active"
      }
    },
    "http://www.w3.org/ns/odrl/2/prohibition": [],
    "http://www.w3.org/ns/odrl/2/target": {
      "@id": "hello-eonax"
    },
    "http://www.w3.org/ns/odrl/2/assigner": {
      "@id": "did:web:eonaxtest-identityhub%3A8383:api:did"
    }
  }
}
```

If the request validation is successful, a 200 OK status will be returned along with a response body containing the id
of the contract negotiation. Note this id for the next step. We will now check the status of the contract negotiation.

### Get Contract Negotiation by ID

#### Url

```bash
<CONNECTOR_URL>/cp/mgmt/v3/contractnegotiations/<id> (GET)
```

If the id provided in the request is correct, the system returns the associated contract negotiation object, which looks
like the following:

#### Request body

```json
{
  "@type": "ContractNegotiation",
  "@id": "ae13ba51-9151-4f83-9894-0c28ad8ee6fb",
  "type": "CONSUMER",
  "protocol": "dataspace-protocol-http",
  "state": "FINALIZED",
  "counterPartyId": "did:web:eonaxtest-identityhub%3A8383:api:did",
  "counterPartyAddress": "http://eonaxtest-controlplane:8282/api/dsp",
  "callbackAddresses": [],
  "createdAt": 1703171822146,
  "contractAgreementId": "af005be5-7e8a-4d4a-8c0c-605eae3de50e",
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "edc": "https://w3id.org/edc/v0.0.1/ns/",
    "eonax": "https://w3id.org/eonax/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  }
}
```

Ensure that the contract negotiation is in state `FINALIZED` before continuing to the next section. Please also take
note of the contract agreement id.

### Initiate transfer

Now that a contract agreed with the provider, we can start the transfer process.

#### Url

```bash
<CONNECTOR_URL>/cp/mgmt/v3/transferprocesses (POST)
```

#### Request

```json
{
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/"
  },
  "@type": "TransferRequest",
  "counterPartyAddress": "http://eonaxtest-controlplane:8282/api/dsp",
  "protocol": "dataspace-protocol-http",
  "connectorId": "did:web:eonaxtest-identityhub%3A8383:api:did",
  "contractId": "<contract agreement id>",
  "privateProperties": {},
  "transferType": "HttpData-PULL"
}
```

If the request is successfully validated by the system, a 200 OK status code will be returned along with the id of the
transfer process. Let’s now check the status of the transfer process.

### Get Transfer Process by ID

#### Url

```bash
<CONNECTOR_URL>/cp/mgmt/v3/transferprocesses/<id> (GET)
```

#### Response

If the id provided in the request is correct, the system returns the associated transfer process object, which looks
like the following:

```json
{
  "@id": "921cac8f-d123-4a4c-b399-b4d5fdfd1e8b",
  "@type": "TransferProcess",
  "correlationId": "921cac8f-d123-4a4c-b399-b4d5fdfd1e8b",
  "state": "STARTED",
  "stateTimestamp": 1703172827067,
  "type": "CONSUMER",
  "assetId": "hello-eonax",
  "contractId": "d6ce2252-af49-4c2f-bc38-921995d996a4",
  "callbackAddresses": [],
  "transferType": "HttpData-PULL",
  "connectorId": "did:web:eonaxtest-identityhub%3A8383:api:did",
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "edc": "https://w3id.org/edc/v0.0.1/ns/",
    "eonax": "https://w3id.org/eonax/v0.0.1/ns/",
    "odrl": "http://www.w3.org/ns/odrl/2/"
  }
}
```

Ensure that the transfer process is in state `STARTED` before continuing to the next section.

## Data consumption (Consumer)

### Data querying

Once a contract has been successfully negotiated with a provider and a transfer process has been started for this
contract, the consumer can now use its connector to fetch the provider’s data.

This is achieved by targeting a proxy API of the consumer Data Plane, that enables to pass query/path parameters in the
request. These query/path parameters are then forwarded to the provider Data Plane, which finally send them to the
actual data source.

All APIs from this section requires a `x-api-key` header in input containing the token provided by Amadeus to interact
with your connector. You must also provide the contract id obtained in the previous section in the `Contract-Id` header.

#### Url

```bash
<CONNECTOR_URL>/dp/data
```

#### Response

```json
{
  "message": "Hello Eona-X"
}
```

As mentioned above, you can pass any query/path parameters in the request url (assuming the provider has enabled the
proxying of query/path parameters for this dataset), e.g. `<CONNECTOR_URL>/dp/data?name=world`

## Appendix

### Eona-X participants ids as of Mar 4, 2025

| Participant name                                                        | ID                        |
|-------------------------------------------------------------------------|---------------------------|
| Aeroport de Paris                                                       | aeroportdeparis           |
| Apidae                                                                  | apidae                    |
| Amadeus                                                                 | amadeus                   |
| Direction de la transformation numerique (ministere de l’interieur)     | dnum                      |
| Eonax test participant                                                  | eonaxtest                 |
| Renault                                                                 | renault                   |
| SNCF                                                                    | sncf                      |
| Aeroport Marseille Provence                                             | aeroportmarseilleprovence |
| Le Petit Fute                                                           | petitfute                 |
| Atout France                                                            | atoutfrance               |
| Metropole De Nice                                                       | metropoledenice           |
| AnySolution                                                             | anysolution               |
| Direction Générale des Infrastructures, des Transports et des Mobilités | dgitm                     |
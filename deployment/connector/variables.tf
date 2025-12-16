variable "kube_context" {
  description = "(Optional) Kubernetes cluster context"
  default     = "kind-eonax-cluster"
}

variable "control_plane_dsp_url" {
  description = "(Required) Internet facing URL of the Control Plane DSP api"
}

variable "data_plane_public_url" {
  description = "(Required) Internet facing URL of the Data Plane public api"
}

variable "eonax_did_web" {
  description = "(Required) did:web url that should resolve to the internet facing url serving the EONAX DID document. Example: did:web:test.api.eona-x.dataspace-platform.amadeus.com:ih:did:authority"
}

variable "identity_hub_did_web_url" {
  description = "(Required) did:web url that should resolve to the internet facing url serving the DID document"
}

variable "vault_url" {
  description = "(Optional) Hashicorp Vault url"
  default     = "http://vault:8200"
}

variable "db_server_fqdn" {
  description = "(Optional) Fqdn of the DB server"
  default     = "postgres"
}

variable "db_name" {
  description = "(Optional) Name of the connector DB"
  default     = "connectordb"
}

variable "db_credentials_secret_name" {
  description = "(Optional) Name of the secret containing the DB credentials"
  default     = "connectordb"
}

variable "vault_token_secret_name" {
  description = "(Optional) Name of the Secret containing the Vault token"
  default     = "vault"
}

variable "publickey_alias" {
  description = "(Optional) Alias of the public key in the Vault"
  default     = "public-key"
}

variable "privatekey_alias" {
  description = "(Optional) Alias of the private key in the Vault"
  default     = "private-key"
}

variable "negotiation_state_machine_wait_millis" {
  description = "(Optional) Wait time of the contract state machines in milliseconds"
  default     = 2000
}

variable "transfer_state_machine_wait_millis" {
  description = "(Optional) Wait time of the transfer state machines in milliseconds"
  default     = 2000
}

variable "policy_monitor_state_machine_wait_millis" {
  description = "(Optional) Wait time of the policy_monitor state machines in milliseconds"
  default     = 5000
}

variable "data_plane_state_machine_wait_millis" {
  description = "(Optional) Wait time of the data plane state machines in milliseconds"
  default     = 5000
}
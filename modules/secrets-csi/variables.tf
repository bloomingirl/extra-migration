variable "driver_version" {
  description = "secrets-store-csi-driver Helm chart version"
  type        = string
  default     = "1.4.6"
}

variable "aws_provider_version" {
  description = "secrets-store-csi-driver-provider-aws Helm chart version"
  type        = string
  default     = "0.3.10"
}

variable "enable_secret_rotation" {
  description = "Periodically reconcile mounted secrets with the source (default 2 min)"
  type        = bool
  default     = true
}

variable "sync_to_kubernetes_secret" {
  description = "Allow mounted secrets to be optionally synced as K8s Secret objects (via SecretProviderClass.secretObjects)"
  type        = bool
  default     = true
}

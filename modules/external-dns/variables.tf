variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the OIDC provider without https:// prefix"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID to manage"
  type        = string
}

variable "domain_filter" {
  description = "Domain to filter (external-dns will only manage records under this domain)"
  type        = string
}

variable "external_dns_version" {
  description = "external-dns Helm chart version"
  type        = string
  default     = "1.15.0"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

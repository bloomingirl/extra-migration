variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint"
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

variable "subnet_ids" {
  description = "Subnet IDs where Karpenter will launch nodes"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID for Karpenter-managed nodes (reuse existing EKS node SG)"
  type        = string
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.0.6"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

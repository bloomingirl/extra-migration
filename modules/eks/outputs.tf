output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_arn" {
  value = aws_eks_cluster.this.arn
}
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider without https:// prefix, for use in IAM trust policy conditions"
  value       = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}

output "cluster_ca_data" {
  description = "Base64-encoded cluster CA certificate (for kubernetes/helm provider configuration)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "node_security_group_id" {
  description = "Security group ID for EKS worker nodes (reused by Karpenter)"
  value       = aws_security_group.eks_nodes.id
}

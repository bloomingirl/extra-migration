output "certificate_arn" {
  description = "ARN of the issued (validated) ACM certificate"
  # Use validation resource (not certificate) so consumers wait until cert is actually ready
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "domain_name" {
  description = "Primary domain name on the certificate"
  value       = aws_acm_certificate.this.domain_name
}

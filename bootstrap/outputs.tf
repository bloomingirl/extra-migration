output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "terraform_role_arn" {
  value = aws_iam_role.terraform_github_actions.arn
}
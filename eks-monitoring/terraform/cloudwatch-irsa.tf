# eks-monitoring/terraform/cloudwatch-irsa.tf
# Ad-hoc IAM role for Grafana → CloudWatch read access
# Story 1.2 will consolidate this later

data "aws_eks_cluster" "this" {
  name = "extra-migration-dev"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Policy: read-only CloudWatch access
resource "aws_iam_policy" "grafana_cloudwatch" {
  name        = "extra-migration-dev-grafana-cloudwatch"
  description = "Allows Grafana to read CloudWatch metrics"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:GetLogGroupFields",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeTags", "ec2:DescribeInstances", "ec2:DescribeRegions"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["tag:GetResources"]
        Resource = "*"
      }
    ]
  })
}

# IRSA role — trusted by Grafana service account
resource "aws_iam_role" "grafana_cloudwatch" {
  name = "extra-migration-dev-grafana-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.this.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")}:sub" = "system:serviceaccount:monitoring:grafana"
            "${replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  role       = aws_iam_role.grafana_cloudwatch.name
  policy_arn = aws_iam_policy.grafana_cloudwatch.arn
}

output "grafana_cloudwatch_role_arn" {
  value       = aws_iam_role.grafana_cloudwatch.arn
  description = "ARN of the IRSA role for Grafana CloudWatch access"
}

# eks-logging/terraform/logging-irsa.tf
# S3 bucket for log backup + IRSA role for Fluent Bit
# Ad-hoc — Story 1.2 consolidates IAM roles later

data "aws_eks_cluster" "this" {
  name = "extra-migration-dev"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# ── S3 Bucket ─────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "logs" {
  bucket = "extra-migration-dev-logs"

  tags = {
    Environment = "dev"
    Purpose     = "eks-log-backup"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: delete logs older than 90 days
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    filter {
      prefix = "logs/"
    }
  }
}

# ── IAM Policy for Fluent Bit → S3 ───────────────────────────────────────────
resource "aws_iam_policy" "fluentbit_s3" {
  name        = "extra-migration-dev-fluentbit-s3"
  description = "Allows Fluent Bit to write logs to S3 backup bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",      # needed for multipart upload verification
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "${aws_s3_bucket.logs.arn}/logs/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.logs.arn
      }
    ]
  })
}

# ── IRSA Role for Fluent Bit ──────────────────────────────────────────────────
resource "aws_iam_role" "fluentbit_s3" {
  name = "extra-migration-dev-fluentbit-s3"

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
            "${replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")}:sub" = "system:serviceaccount:logging:fluent-bit"
            "${replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fluentbit_s3" {
  role       = aws_iam_role.fluentbit_s3.name
  policy_arn = aws_iam_policy.fluentbit_s3.arn
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "fluentbit_s3_role_arn" {
  value       = aws_iam_role.fluentbit_s3.arn
  description = "Paste this into values/dev.yaml → fluentbit.s3.roleArn"
}

output "logs_bucket_name" {
  value       = aws_s3_bucket.logs.bucket
  description = "S3 bucket for log backup"
}

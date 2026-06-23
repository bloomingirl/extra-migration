# Trust policy: only external-dns SA in kube-system can assume this role via OIDC
data "aws_iam_policy_document" "external_dns_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.cluster_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume.json
  tags               = var.tags
}

# Permission policy: scoped to our hosted zone only
data "aws_iam_policy_document" "external_dns_permissions" {
  # Manage DNS records (create/delete/update) in our hosted zone only
  statement {
    sid    = "AllowChangeResourceRecordSets"
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    resources = ["arn:aws:route53:::hostedzone/${var.hosted_zone_id}"]
  }

  # List all hosted zones (external-dns needs to enumerate to find ours)
  statement {
    sid    = "AllowListHostedZones"
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "external_dns" {
  name   = "${var.cluster_name}-external-dns"
  role   = aws_iam_role.external_dns.id
  policy = data.aws_iam_policy_document.external_dns_permissions.json
}

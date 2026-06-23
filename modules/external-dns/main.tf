# Install external-dns via Helm
# https://kubernetes-sigs.github.io/external-dns/
resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_version

  # ServiceAccount with IRSA annotation
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_dns.arn
  }

  # AWS Route53 provider
  set {
    name  = "provider.name"
    value = "aws"
  }

  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  set {
    name  = "domainFilters[0]"
    value = var.domain_filter
  }

  # Watch Gateway API resources (gateway-httproute), not just legacy Ingress
  set {
    name  = "sources[0]"
    value = "gateway-httproute"
  }

  set {
    name  = "sources[1]"
    value = "service"
  }

  # Allow ALL namespaces (we may have HTTPRoutes in kube-system, default, etc)
  set {
    name  = "policy"
    value = "sync"
  }

  # Single replica is fine for learning
  set {
    name  = "replicaCount"
    value = "1"
  }

  # Schedule on bootstrap nodes (CriticalAddonsOnly taint)
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  depends_on = [
    aws_iam_role_policy.external_dns,
  ]
}

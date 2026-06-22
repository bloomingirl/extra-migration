# Karpenter lives in kube-system per upstream recommendation
# (it ships with tolerations for CriticalAddonsOnly out of the box)
locals {
  karpenter_namespace = "kube-system"
}

# Install Karpenter via Helm
# https://gallery.ecr.aws/karpenter/karpenter
resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = local.karpenter_namespace
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version

  # ServiceAccount with IRSA annotation so Karpenter pod can assume controller IAM role
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller.arn
  }

  # Tell Karpenter which cluster to manage
  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  }

  # Interruption queue we built in interruption_queue.tf
  set {
    name  = "settings.interruptionQueue"
    value = aws_sqs_queue.karpenter_interruption.name
  }

  # Karpenter controller needs to schedule on bootstrap nodes (which have CriticalAddonsOnly taint)
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  # 1 replica is fine for learning; production typically uses 2 for HA
  set {
    name  = "replicas"
    value = "1"
  }

  depends_on = [
    aws_eks_node_group.bootstrap,
    aws_iam_role_policy.karpenter_controller,
  ]
}

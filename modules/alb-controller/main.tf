# Install AWS Load Balancer Controller via Helm
# https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.alb_controller_version

  # Tell controller which cluster to manage
  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  # IRSA annotation so controller pod can assume AWS IAM role
  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }

  # Tell controller VPC to manage (otherwise it tries to auto-discover)
  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "region"
    value = "us-east-1"
  }

  # Enable Gateway API support (added in v2.13)
  set {
    name  = "enableServiceMutatorWebhook"
    value = "false"
  }

  set {
    name  = "controllerConfig.featureGates.ALBGatewayAPI"
    value = "true"
  }

  # Controller schedules on bootstrap nodes (CriticalAddonsOnly taint)
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  # Single replica for learning; production typically uses 2 for HA
  set {
    name  = "replicaCount"
    value = "1"
  }

  depends_on = [
    aws_iam_role_policy_attachment.alb_controller,
  ]
}

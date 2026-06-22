# EC2NodeClass: AWS-specific config (subnets, AMI, SG, instance profile) for Karpenter nodes.
# Karpenter NodePools reference this to know HOW to launch EC2 in AWS.
resource "kubernetes_manifest" "ec2nodeclass_default" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2023"
      amiSelectorTerms = [
        { alias = "al2023@latest" }
      ]
      role = aws_iam_role.karpenter_node.name
      subnetSelectorTerms = [
        for id in var.subnet_ids : { id = id }
      ]
      securityGroupSelectorTerms = [
        { id = var.node_security_group_id }
      ]
      tags = merge(var.tags, {
        "karpenter.sh/discovery" = var.cluster_name
        "Name"                   = "${var.cluster_name}-karpenter-node"
      })
    }
  }

  depends_on = [helm_release.karpenter]
}

# NodePool for system workloads — tainted, so only system pods with toleration land here
resource "kubernetes_manifest" "nodepool_system" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "system"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload-type" = "system"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          taints = [
            {
              key    = "CriticalAddonsOnly"
              value  = "true"
              effect = "NoSchedule"
            }
          ]
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["t", "m"]
            },
            {
              key      = "karpenter.k8s.aws/instance-cpu"
              operator = "In"
              values   = ["2", "4"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64", "arm64"]
            },
          ]
        }
      }
      limits = {
        cpu    = "20"
        memory = "40Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "30s"
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2nodeclass_default]
}

# NodePool for application workloads — no taint, normal pods land here
resource "kubernetes_manifest" "nodepool_apps" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "apps"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload-type" = "apps"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "default"
          }
          requirements = [
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["t", "m", "c"]
            },
            {
              key      = "karpenter.k8s.aws/instance-cpu"
              operator = "In"
              values   = ["2", "4", "8"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64", "arm64"]
            },
          ]
        }
      }
      limits = {
        cpu    = "50"
        memory = "100Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "30s"
      }
    }
  }

  depends_on = [kubernetes_manifest.ec2nodeclass_default]
}

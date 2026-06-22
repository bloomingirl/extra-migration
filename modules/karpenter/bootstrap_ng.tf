# Get the latest EKS-optimized AMI for the cluster's Kubernetes version
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_ssm_parameter" "bootstrap_ami" {
  name = "/aws/service/eks/optimized-ami/${data.aws_eks_cluster.this.version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

# Custom Launch Template with --node-ip=:: for IPv6-only kubelet registration
resource "aws_launch_template" "bootstrap" {
  name_prefix   = "${var.cluster_name}-bootstrap-"
  image_id      = data.aws_ssm_parameter.bootstrap_ami.value
  instance_type = "t3.medium"

  vpc_security_group_ids = [var.node_security_group_id]


  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.cluster_name}-bootstrap"
    })
  }

  # nodeadm config tells kubelet to register with IPv6 node IP
  user_data = base64encode(<<-EOT
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="==BOUNDARY=="

    --==BOUNDARY==
    Content-Type: application/node.eks.aws

    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${var.cluster_name}
        apiServerEndpoint: ${data.aws_eks_cluster.this.endpoint}
        certificateAuthority: ${data.aws_eks_cluster.this.certificate_authority[0].data}
        cidr: ${data.aws_eks_cluster.this.kubernetes_network_config[0].service_ipv6_cidr}
      kubelet:
        flags:
          - "--node-ip=::"
    --==BOUNDARY==--
  EOT
  )
}

# Bootstrap node group using custom Launch Template
resource "aws_eks_node_group" "bootstrap" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-bootstrap"
  node_role_arn   = aws_iam_role.karpenter_node.arn
  subnet_ids      = var.subnet_ids

  launch_template {
    id      = aws_launch_template.bootstrap.id
    version = aws_launch_template.bootstrap.latest_version
  }

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  labels = {
    "node-role.kubernetes.io/bootstrap" = "true"
    "workload-type"                     = "system"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-bootstrap"
  })

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_node_worker,
    aws_iam_role_policy_attachment.karpenter_node_cni,
    aws_iam_role_policy_attachment.karpenter_node_ecr,
    aws_iam_role_policy_attachment.karpenter_node_ssm,
    aws_eks_access_entry.karpenter_nodes,
  ]
}

# Install Gateway API CRDs from upstream releases.
# These are not AWS-specific; ALB Controller consumes them but doesn't install them.
#
# Using null_resource with kubectl because:
# - kubernetes-sigs/gateway-api doesn't publish an official Helm chart
# - kubernetes_manifest CRD requires CRD-of-CRD which gets circular
# - kubectl apply -f <url> is the upstream-recommended approach

resource "null_resource" "gateway_api_crds" {
  triggers = {
    # Re-apply if version changes
    version = "v1.5.0"
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.0/standard-install.yaml --ignore-not-found
    EOT
  }
}

# LBC-specific Gateway CRDs (ListenerRuleConfiguration, etc)
# These extend standard Gateway API with AWS-specific configuration objects.
# Must be installed AFTER standard Gateway API CRDs.
resource "null_resource" "lbc_gateway_crds" {
  triggers = {
    # Pinned to commit hash to ensure reproducibility
    # See: https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/gateway/gateway/
    version = "v2.14.0"
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.0/config/crd/gateway/gateway-crds.yaml
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.0/config/crd/gateway/gateway-crds.yaml --ignore-not-found
    EOT
  }

  depends_on = [null_resource.gateway_api_crds]
}

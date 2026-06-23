# Secrets Store CSI Driver (generic, not AWS-specific).
# https://secrets-store-csi-driver.sigs.k8s.io/
resource "helm_release" "secrets_store_csi_driver" {
  name       = "secrets-store-csi-driver"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = var.driver_version

  # Enable periodic re-sync so rotated secrets reach pods automatically
  set {
    name  = "enableSecretRotation"
    value = var.enable_secret_rotation
  }

  # Default rotation poll interval (2 minutes is reasonable for dev)
  set {
    name  = "rotationPollInterval"
    value = "2m"
  }

  # Allow SecretProviderClass.spec.secretObjects to create K8s Secrets too
  # (useful for envFrom/secretKeyRef compatibility)
  set {
    name  = "syncSecret.enabled"
    value = var.sync_to_kubernetes_secret
  }

  # Tolerate CriticalAddonsOnly so it runs on bootstrap nodes
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
}

# AWS-specific provider for the CSI driver.
# https://github.com/aws/secrets-store-csi-driver-provider-aws
resource "helm_release" "secrets_csi_provider_aws" {
  name       = "secrets-provider-aws"
  namespace  = "kube-system"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = var.aws_provider_version

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }

  # Must come after generic driver (the provider plugs into it)
  depends_on = [
    helm_release.secrets_store_csi_driver,
  ]
}

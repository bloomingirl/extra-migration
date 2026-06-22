# LoadBalancerConfiguration: AWS-specific config for the ALB.
# Referenced by Gateway via infrastructure.parametersRef.
resource "kubernetes_manifest" "lbconfig_internet_facing" {
  manifest = {
    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "LoadBalancerConfiguration"
    metadata = {
      name      = "internet-facing"
      namespace = "kube-system"
    }
    spec = {
      scheme        = "internet-facing"
      ipAddressType = "dualstack"
    }
  }

  depends_on = [
    helm_release.alb_controller,
    null_resource.lbc_gateway_crds,
  ]
}

# GatewayClass tells Kubernetes which controller materializes Gateways.
resource "kubernetes_manifest" "gatewayclass_alb" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name = "alb"
    }
    spec = {
      controllerName = "gateway.k8s.aws/alb"
    }
  }

  depends_on = [
    helm_release.alb_controller,
    null_resource.gateway_api_crds,
    null_resource.lbc_gateway_crds,
  ]
}

# Gateway: a concrete instance of an ALB.
# Uses LoadBalancerConfiguration via infrastructure.parametersRef to be internet-facing.
resource "kubernetes_manifest" "gateway_default" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "extra-migration-gw"
      namespace = "kube-system"
    }
    spec = {
      gatewayClassName = "alb"
      infrastructure = {
        parametersRef = {
          group = "gateway.k8s.aws"
          kind  = "LoadBalancerConfiguration"
          name  = "internet-facing"
        }
      }
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.gatewayclass_alb,
    kubernetes_manifest.lbconfig_internet_facing,
  ]
}

# GatewayClass tells Kubernetes which controller materializes Gateways.
# The controllerName must match what ALB Controller registers as.
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
# When applied, ALB Controller creates a real ALB in AWS.
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

  depends_on = [kubernetes_manifest.gatewayclass_alb]
}

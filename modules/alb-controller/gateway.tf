# LoadBalancerConfiguration: AWS-specific config for the ALB.
# Includes per-listener cert configuration for HTTPS.
resource "kubernetes_manifest" "lbconfig_internet_facing" {
  manifest = {
    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "LoadBalancerConfiguration"
    metadata = {
      name      = "internet-facing"
      namespace = "kube-system"
    }
    spec = merge(
      {
        scheme        = "internet-facing"
        ipAddressType = "dualstack"
      },
      var.acm_certificate_arn == "" ? {} : {
        listenerConfigurations = [
          {
            protocolPort       = "HTTPS:443"
            defaultCertificate = var.acm_certificate_arn
          }
        ]
      }
    )
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

# Build listener list: HTTP always, HTTPS only when cert ARN provided.
locals {
  http_listener = {
    name     = "http"
    protocol = "HTTP"
    port     = 80
    allowedRoutes = {
      namespaces = {
        from = "All"
      }
    }
  }

  https_listener = {
    name     = "https"
    protocol = "HTTPS"
    port     = 443
    allowedRoutes = {
      namespaces = {
        from = "All"
      }
    }
  }
}

# Gateway: a concrete instance of an ALB.
# Cert config is in LoadBalancerConfiguration; here we just define listeners.
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
      listeners = concat(
        [local.http_listener],
        var.acm_certificate_arn == "" ? [] : [local.https_listener]
      )
    }
  }

  depends_on = [
    kubernetes_manifest.gatewayclass_alb,
    kubernetes_manifest.lbconfig_internet_facing,
  ]
}

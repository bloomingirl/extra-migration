# eks-monitoring

Prometheus + Grafana + Alertmanager observability stack for the `extra-migration-dev` EKS cluster.

## Architecture

```
EKS Cluster
├── monitoring namespace
│   ├── Prometheus          — scrapes cluster + nginx app metrics
│   ├── Grafana             — dashboards (Prometheus + CloudWatch in one pane)
│   └── Alertmanager        — receives alerts; Story 2.3 layers Slack routing on top
└── default namespace
    └── nginx + nginx-exporter  — the app we write an SLO for
```

Deployed as a **locally-vendored Helm chart** (`Chart.yaml` + `values/`) via the `deploy-platform-tools.yaml` workflow.

## How to reach Grafana

URL: `https://grafana-extra-migration-dev.YOUR_DOMAIN_HERE`

- Access is restricted to an allowlisted source IP (configured in ingress annotation)
- Login required — credentials stored in AWS Secrets Manager, never committed
- To retrieve credentials locally:
  ```bash
  aws secretsmanager get-secret-value \
    --secret-id extra-migration-dev/grafana \
    --query SecretString --output text
  ```

## How the SLO is computed

See [SLO.md](./SLO.md) for the full definition.

Short version: Prometheus recording rules compute the 5-minute HTTP success rate for nginx. Grafana shows the rate and error budget remaining. Target: **99.9%** (~43 min/month downtime budget).

## Deploying

```bash
# From roots/environments/dev — apply IRSA role first
terraform apply -target=aws_iam_role.grafana_cloudwatch

# Then deploy the chart
helm dependency update eks-monitoring/
helm upgrade --install eks-monitoring ./eks-monitoring \
  -f eks-monitoring/values/dev.yaml \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminUser=$(aws secretsmanager get-secret-value \
      --secret-id extra-migration-dev/grafana \
      --query SecretString --output text | jq -r .username) \
  --set grafana.adminPassword=$(aws secretsmanager get-secret-value \
      --secret-id extra-migration-dev/grafana \
      --query SecretString --output text | jq -r .password)
```

## Structure

```
eks-monitoring/
├── Chart.yaml                          # Umbrella chart with kube-prometheus-stack dep
├── SLO.md                              # SLO definition and error budget policy
├── README.md                           # This file
├── WORKING-WITH-AI.md                  # AI collaboration memoir
├── values/
│   ├── dev.yaml                        # Dev environment (deployed)
│   ├── staging.yaml                    # Staging (defined, not deployed)
│   └── production.yaml                 # Production (defined, not deployed)
├── dashboards/
│   └── nginx-slo.json                  # Grafana dashboard as code
├── terraform/
│   └── cloudwatch-irsa.tf              # IRSA role for Grafana → CloudWatch
└── charts/
    └── kube-prometheus-stack/
        └── templates/
            └── dashboards-configmap.yaml
```

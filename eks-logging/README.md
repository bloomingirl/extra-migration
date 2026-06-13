# eks-logging

EFK stack (Elasticsearch + Fluent Bit + Kibana) for the `extra-migration-dev` EKS cluster, plus a Claude Code diagnostic skill.

## Why EFK over a managed logging product?

| | Managed (e.g. Datadog Logs) | EFK (this stack) |
|---|---|---|
| Cost | ~$0.10/GB/month + host fees | EC2 + S3 storage only |
| Ops burden | None | You own Elasticsearch |
| Retention control | Plan-limited | You set the policy |
| Data sovereignty | Vendor holds logs | Logs stay in your AWS |
| Failure risk | Vendor SLA | Single ES node in dev = SPOF |

**What we gave up:** managed HA, automatic upgrades, built-in anomaly detection, vendor support.
**What we gained:** full control over retention, no per-GB ingestion cost, logs never leave our AWS account.
**How we ensured no capability was lost:** Fluent Bit ships to both Elasticsearch AND S3 — if ES corrupts or loses an index, the S3 copy is always retrievable.

## Architecture

```
Every Node
└── Fluent Bit (DaemonSet)
        │
        ├──► Elasticsearch (StatefulSet, logging ns) ──► Kibana
        │
        └──► S3 bucket: extra-migration-dev-logs/logs/YYYY/MM/DD/
```

## How to reach Kibana

URL: `https://kibana-extra-migration-dev.YOUR_DOMAIN_HERE`

- Access restricted to allowlisted home IP (ingress annotation)
- Login required — credentials in AWS Secrets Manager
- To retrieve:
  ```bash
  aws secretsmanager get-secret-value \
    --secret-id extra-migration-dev/kibana \
    --query SecretString --output text
  ```

## How the S3 backup works

Fluent Bit has **two output plugins** running simultaneously — `es` and `s3`. Every log line written to Elasticsearch is also written to S3 in gzip format under `logs/YYYY/MM/DD/HH/`.

To verify the backup is real (not just configured):
```bash
# List today's logs
aws s3 ls s3://extra-migration-dev-logs/logs/$(date +%Y/%m/%d)/

# Retrieve a sample
aws s3 cp s3://extra-migration-dev-logs/logs/$(date +%Y/%m/%d)/HH/fluent-bit_HHMMSS.gz /tmp/
gunzip /tmp/fluent-bit_HHMMSS.gz
head -5 /tmp/fluent-bit_HHMMSS
```

## Diagnostic skill

The Claude Code skill lives at `.claude/skills/log-diagnostic.md`.

Usage: `/log-diagnostic service=nginx since=30m`

**Autonomy boundary:** read-only. The skill fetches and analyses logs, proposes a hypothesis. It never restarts pods, deletes resources, or writes to AWS. A human acts on the hypothesis.

## Deploying

```bash
# 1. Apply Terraform (S3 bucket + IRSA role)
cd eks-logging/terraform
terraform init && terraform apply
# Copy fluentbit_s3_role_arn output → values/dev.yaml → fluentbit.s3.roleArn

# 2. Create secrets in AWS Secrets Manager (week-1 manual; Story 1.5 automates)
aws secretsmanager create-secret \
  --name extra-migration-dev/elasticsearch \
  --secret-string '{"username":"elastic","password":"CHANGE_ME"}'

aws secretsmanager create-secret \
  --name extra-migration-dev/kibana \
  --secret-string '{"username":"kibana_system","password":"CHANGE_ME"}'

# 3. Deploy the chart
kubectl create namespace logging
helm upgrade --install eks-logging ./eks-logging \
  -f eks-logging/values/dev.yaml \
  --namespace logging
```

## Structure

```
eks-logging/
├── Chart.yaml
├── README.md
├── WORKING-WITH-AI.md
├── values/
│   ├── dev.yaml
│   ├── staging.yaml
│   └── production.yaml
├── terraform/
│   └── logging-irsa.tf        # S3 bucket + IRSA role for Fluent Bit
├── skills/
│   └── log-diagnostic.md      # Claude Code skill (copy to .claude/skills/)
└── charts/
    └── efk/
        └── templates/
            ├── elasticsearch.yaml
            ├── fluentbit.yaml
            └── kibana.yaml
```

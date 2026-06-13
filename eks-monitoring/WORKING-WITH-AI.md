# WORKING-WITH-AI.md — Story 2.1 Metrics & SLOs

## §1 What I asked Claude to help with

- Scaffolding the `eks-monitoring/` directory structure and Helm chart layout
- Drafting the `values/dev.yaml` with Prometheus, Grafana, and Alertmanager config
- Writing the Terraform IRSA role for Grafana → CloudWatch
- Creating the Grafana dashboard JSON for the SLO panel
- Explaining what 99.9% availability means in practice (error budget = 43.2 min/month)

## §2 What I decided myself (Claude did not pick these)

- **SLI choice:** HTTP error rate over latency — because error rate reflects user-visible failures for a simple HTTP entry point
- **SLO target:** 99.9% — appropriate for a dev cluster without a paid on-call rotation
- **Error budget policy:** freeze deploys at <25% remaining, declare incident at 0%
- **Which app to SLO:** nginx — simple, controllable, demonstrates the concept cleanly

## §3 What Claude got wrong / what I had to fix

_Fill this in as you work through the implementation._

Examples to watch for:
- Recording rule expressions that don't match actual metric names from nginx-exporter
- Dashboard JSON panel types incompatible with your Grafana version
- IRSA trust policy condition keys (exact format matters)

## §4 What I verified myself

_Fill this in as you complete each step._

- [ ] Helm chart renders correctly (`helm template eks-monitoring ./eks-monitoring -f values/dev.yaml`)
- [ ] Prometheus scrapes nginx-exporter metrics
- [ ] Grafana loads dashboards from configmap (not hand-clicked)
- [ ] CloudWatch data source returns data
- [ ] Grafana is NOT reachable from outside allowlisted IP
- [ ] Credentials are NOT in git (`git grep -i password` returns nothing sensitive)
- [ ] SLO panel shows live data tracking against traffic
- [ ] Error budget gauge updates correctly

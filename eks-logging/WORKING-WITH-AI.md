# WORKING-WITH-AI.md — Story 2.2 Logs + diagnostic skill

## §1 What I asked Claude to help with

- Scaffolding the `eks-logging/` directory structure and Helm chart templates
- Drafting Fluent Bit config with dual output (Elasticsearch + S3)
- Writing the Terraform for S3 bucket and IRSA role
- Writing the diagnostic skill template
- Explaining Elasticsearch StatefulSet gotchas (vm.max_map_count, single-node mode)

## §2 What I decided myself (Claude did not pick these)

- **Fluent Bit over Fluentd** — lighter resource footprint, better IPv6 support, actively maintained
- **Single Elasticsearch node in dev** — intentional, not a mistake; dev doesn't need HA
- **Autonomy boundary: read-only** — a diagnostic skill that can also act creates risk; wrong hypothesis + automated restart = worse incident
- **90-day S3 retention** — balances cost vs forensic value
- **log-diagnostic.md skill design** — the two demo scenarios and the hypothesis format

## §3 What Claude got wrong / what I had to fix

_Fill this in as you work through the implementation._

Watch for:
- Fluent Bit S3 plugin key format — `s3_key_format` syntax is specific
- Elasticsearch `vm.max_map_count` init container needs `privileged: true` — flagged by OPA/Gatekeeper if running
- IRSA trust policy condition key format must match exactly
- Kibana version must match Elasticsearch version exactly (both 8.13.4)

## §4 What I verified myself

_Fill this in as you complete each step._

- [ ] Fluent Bit DaemonSet pods running on all nodes
- [ ] Logs visible in Kibana (`fluent-bit-*` index)
- [ ] S3 backup verified by actually retrieving a log file (`aws s3 cp ...`)
- [ ] Kibana NOT reachable from outside allowlisted IP
- [ ] Credentials NOT in git (`git grep -i password` clean)
- [ ] Diagnostic skill demoed against Scenario 1 (CrashLoopBackOff)
- [ ] Diagnostic skill demoed against Scenario 2 (5xx spike)
- [ ] Skill produced a useful hypothesis in both cases

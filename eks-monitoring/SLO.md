# SLO: Nginx HTTP Availability

## Service
nginx — HTTP frontend deployed on EKS cluster `extra-migration-dev`

## SLI (Service Level Indicator)
**HTTP Success Rate** — the proportion of HTTP requests that return a non-5xx response.

```
SLI = (total_requests - 5xx_requests) / total_requests
```

Measured via `nginx_http_requests_total` metric scraped by Prometheus every 30s.

## SLO (Service Level Objective)
**99.9% of HTTP requests return a non-5xx response**, measured over a rolling 30-day window.

## Why this SLI and target?

**Why error rate, not latency:**
nginx here is a traffic entry point. A user notices when they receive an error (502, 503, 504), not when the response takes 200ms vs 100ms. Error rate directly reflects "working or not" — the most honest SLI for a simple HTTP service without strict latency requirements.

**Why 99.9%:**
99.9% allows ~43 minutes of downtime per month — appropriate for a dev/demo cluster without a paid on-call rotation. It's strict enough to be meaningful, but realistic for infrastructure without redundancy SLAs.

## Error Budget
| Window | Allowed downtime | Allowed error requests (per 100k) |
|--------|-----------------|-----------------------------------|
| Monthly (30d) | 43.2 minutes | 100 requests |
| Weekly | 10.1 minutes | 100 requests |

## Measurement Window
Rolling 30-day window, evaluated continuously via Prometheus recording rules.

## Prometheus Recording Rules
```yaml
# Success rate (5m window)
job:nginx_http_requests:success_rate5m =
  1 - (rate(5xx[5m]) / rate(total[5m]))

# Error budget remaining
job:nginx_http_requests:error_budget_remaining =
  1 - ((1 - success_rate) / (1 - 0.999))
```

## Response When Budget Burns

| Budget remaining | Action |
|-----------------|--------|
| > 50% | No action — monitor |
| 25–50% | Investigate recent deploys and error patterns |
| < 25% | Freeze non-critical deploys, escalate to owner |
| 0% (exhausted) | Incident declared — all hands on nginx |

## Dashboard
Grafana: `https://grafana-extra-migration-dev.YOUR_DOMAIN_HERE`
Panel: **Nginx SLO Dashboard** → "SLO: HTTP Success Rate" + "Error Budget Remaining"

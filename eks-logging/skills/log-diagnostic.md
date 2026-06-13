# log-diagnostic

Fetch logs for a specific service and time range, summarise patterns, and propose a root-cause hypothesis.

## Usage

```
/log-diagnostic service=<name> since=<duration>
```

Examples:
```
/log-diagnostic service=nginx since=30m
/log-diagnostic service=elasticsearch since=1h
```

## What this skill does

1. Fetches recent logs for the named service from the cluster
2. Identifies error patterns, repeated messages, and anomalies
3. Summarises what it found
4. Proposes a hypothesis for what caused the issue

## Autonomy boundary (READ-ONLY)

**This skill only reads. It never writes, deletes, restarts, or modifies anything.**

Allowed:
- `kubectl logs` — read pod logs
- `kubectl get`, `kubectl describe` — read pod/deployment status
- `kubectl get events` — read cluster events
- `aws s3 cp` — retrieve logs from S3 backup if needed

Not allowed (requires human):
- `kubectl delete` — deleting pods
- `kubectl rollout restart` — restarting deployments
- `kubectl apply` / `kubectl patch` — changing config
- Any write operation to AWS resources

**Why read-only:** A diagnostic tool that can also act creates risk — a wrong hypothesis followed by an automated restart could make an incident worse. The value here is the hypothesis, not the action. A human reviews the hypothesis and decides what to do.

## Steps

1. Get the pod name(s) for the service
```bash
kubectl get pods -A -l app=$SERVICE --no-headers -o custom-columns=":metadata.namespace,:metadata.name"
```

2. Fetch recent logs (last N minutes)
```bash
kubectl logs -n $NAMESPACE $POD --since=$SINCE --tail=500
```

3. Check pod status and recent events
```bash
kubectl describe pod -n $NAMESPACE $POD
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -20
```

4. Analyse the logs:
   - Count occurrences of ERROR, WARN, FATAL
   - Identify the first error timestamp
   - Find repeated error messages (patterns)
   - Check for OOMKilled, CrashLoopBackOff signals
   - Note any upstream connection failures

5. Summarise findings in this format:

```
## Log Diagnostic: <service> (last <duration>)

### What I found
- <N> errors in the window
- First error at: <timestamp>
- Most common error: "<message>" (<count>x)
- Pod status: <Running|CrashLoopBackOff|OOMKilled|...>

### Patterns
<list of notable patterns>

### Hypothesis
<root cause hypothesis with reasoning>

### Suggested next steps (for human to decide)
1. <action>
2. <action>
```

6. If logs are unavailable in cluster (pod crashed and gone), retrieve from S3:
```bash
aws s3 ls s3://extra-migration-dev-logs/logs/$(date +%Y/%m/%d)/ | grep $SERVICE
aws s3 cp s3://extra-migration-dev-logs/logs/... /tmp/logs.gz
gunzip /tmp/logs.gz && tail -200 /tmp/logs
```

## Scenario examples (for demo)

### Scenario 1: CrashLoopBackOff
Induce: `kubectl set env deployment/nginx BREAK=true`
Expected hypothesis: container exits immediately after start — likely bad env var or missing config

### Scenario 2: 5xx error spike
Induce: `kubectl apply -f bad-configmap.yaml` (point nginx to non-existent upstream)
Expected hypothesis: upstream connection refused — nginx cannot reach backend, returning 502

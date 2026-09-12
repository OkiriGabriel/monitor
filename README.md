# Monitoring Toolkit

Prometheus, Grafana, and Blackbox Exporter stacks plus helper automations for API health checks, SSL renewal, RDS connection management, and log backups.

No company names or live credentials are stored in this repo. Copy the example env files and replace placeholders before you run anything.

## What's included

| Directory | Purpose |
|-----------|---------|
| `grafana-monitoring/` | General Prometheus + Grafana + Blackbox + Node Exporter stack |
| `api-monitoring/` | Same stack, tuned for HTTP API probes and extra scrape jobs |
| `cert-automation/` | Certbot renewal script, cron installer, and expiry CloudFormation |
| `rds-automation/` | CloudFormation for RDS connection/session monitoring and alerts |
| `logs-automation/` | S3 log archive script and example cron entries |
| `rds-mysql-timeout-config.md` | Guide for closing idle MySQL connections on RDS |

## Prerequisites

- Docker 20.10+ and Docker Compose 1.29+
- About 2 GB of free RAM
- Open ports: `3000` (Grafana), `9090` (Prometheus), `9100` (Node Exporter), `9115` (Blackbox)

## Quick start

1. Choose a stack: `grafana-monitoring` or `api-monitoring`.
2. Copy the env template and set a Grafana password:

   ```bash
   cd grafana-monitoring
   cp .env.example .env
   ```

3. Edit `prometheus.yml` and replace `https://api.example.com` with the endpoints you want to probe.
4. Start the stack:

   ```bash
   docker compose up -d
   ```

5. Open the UIs:

   - Grafana: http://localhost:3000 (user from `.env`)
   - Prometheus: http://localhost:9090
   - Blackbox Exporter: http://localhost:9115
   - Node Exporter: http://localhost:9100/metrics

Do not use the example Grafana password in production. Set `GF_SECURITY_ADMIN_PASSWORD` in `.env` to a strong value.

## Configuration

### Prometheus targets

```yaml
scrape_configs:
  - job_name: 'blackbox'
    static_configs:
      - targets:
          - https://your-api.example.com
          - https://your-api.example.com/health
```

Reload after edits:

```bash
curl -X POST http://localhost:9090/-/reload
```

### Grafana

Admin user and password come from `.env`. Dashboards and the Prometheus datasource are provisioned from `grafana/dashboards` and `grafana/datasources`.

### Alerts

`alerts.yml` includes:

- **APIDown** — probe failed for 2+ minutes
- **APISlowResponse** — response time over 2 seconds
- **APIHighErrorRate** — success rate below 95% (`api-monitoring` only)
- **APISSLCertExpiringSoon** — certificate expires in under 30 days

To send notifications, add Alertmanager and point `prometheus.yml` at it.

## Other automations

### Certificate renewal

```bash
export CERTBOT_EMAIL=your-email@example.com
./cert-automation/certbot-renew.sh --dry-run
```

See `cert-automation/CERTBOT_CRON_SETUP.md` for cron and systemd timer setup.

### RDS

`rds-automation/rds_cfn.yaml` deploys Lambda-based connection/session monitoring. Database credentials belong in AWS Secrets Manager — pass the secret ARN as a stack parameter. Do not put usernames or passwords in the template.

### Log backups

```bash
export LOG_DIR=/var/www/html/app/storage/logs
export S3_BUCKET=your-bucket-name
export S3_PATH=app-logs
./logs-automation/s3-log-backup.sh
```

## Maintenance

```bash
docker compose down          # stop
docker compose down -v       # stop and delete volumes
docker compose logs -f       # follow logs
docker compose pull && docker compose up -d   # update images
```

Deleting volumes removes stored metrics and Grafana data.

## Project layout

```
monitoring/
├── grafana-monitoring/
│   ├── alerts.yml
│   ├── blackbox.yml
│   ├── docker-compose.yml
│   ├── prometheus.yml
│   ├── prometheus-queries.txt
│   └── grafana/
├── api-monitoring/
│   └── (same stack layout)
├── cert-automation/
├── rds-automation/
├── logs-automation/
└── rds-mysql-timeout-config.md
```

## Security

- Keep `.env` out of git (already listed in `.gitignore`).
- Rotate any password that was previously committed elsewhere.
- Store database credentials in Secrets Manager or a secret store, not in YAML or scripts.
- Bind Grafana and Prometheus to a private network in production.

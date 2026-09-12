# Grafana Monitoring Stack

Prometheus, Grafana, Blackbox Exporter, and Node Exporter for HTTP health checks and host metrics.

## Start

```bash
cp .env.example .env
# set GF_SECURITY_ADMIN_PASSWORD in .env
# set your probe targets in prometheus.yml
docker compose up -d
```

- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Blackbox: http://localhost:9115
- Node Exporter: http://localhost:9100/metrics

See the [root README](../README.md) for configuration, alerts, and security notes.

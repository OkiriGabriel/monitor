# FEZ Monitoring

A comprehensive monitoring solution for FEZ Delivery services using Prometheus, Grafana, and Blackbox Exporter. This repository contains monitoring configurations for tracking API availability, performance, and system metrics.

##  Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Services](#services)
- [Alerting](#alerting)
- [Useful Queries](#useful-queries)
- [Project Structure](#project-structure)

##  Overview

This monitoring stack provides:

- **API Health Monitoring**: HTTP/HTTPS endpoint availability and response times
- **System Metrics**: Node exporter for host-level metrics
- **Visualization**: Pre-configured Grafana dashboards
- **Alerting**: Prometheus alert rules for critical issues
- **SSL Certificate Monitoring**: Automatic detection of expiring certificates

##  Architecture

The monitoring stack consists of:

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Blackbox Exporter**: HTTP/HTTPS endpoint probing
- **Node Exporter**: System and hardware metrics

All services run in Docker containers and communicate via a dedicated Docker network.

##  Prerequisites

- Docker (version 20.10 or higher)
- Docker Compose (version 1.29 or higher)
- At least 2GB of available RAM
- Ports available: `3000`, `9090`, `9100`, `9115`

##  Quick Start

### 1. Choose Your Monitoring Setup

This repository contains two monitoring configurations:

- **`fez-grafana-monitoring/`**: General FEZ monitoring setup
- **`riders-api-monitoring/`**: Dedicated Riders API monitoring

### 2. Start the Monitoring Stack

Navigate to your desired monitoring directory:

```bash
cd fez-grafana-monitoring
# or
cd riders-api-monitoring
```

Start all services:

```bash
docker-compose up -d
```

### 3. Access the Services

- **Grafana**: http://localhost:3000
  - Username: `admin`
    - Password: `admin123`
- **Prometheus**: http://localhost:9090
- **Blackbox Exporter**: http://localhost:9115
- **Node Exporter**: http://localhost:9100/metrics

### 4. Verify Services

Check that all containers are running:

```bash
docker-compose ps
```

You should see all four services (prometheus, grafana, blackbox, node-exporter) in "Up" status.

##  Configuration

### Prometheus Configuration

Edit `prometheus.yml` to add or modify monitoring targets:

```yaml
scrape_configs:
  - job_name: 'blackbox'
    static_configs:
      - targets:
          - https://your-api-endpoint.com
          - https://another-endpoint.com/health
```

After making changes, reload Prometheus:

```bash
curl -X POST http://localhost:9090/-/reload
```

### Blackbox Exporter Configuration

Edit `blackbox.yml` to customize probe settings:

- **http_2xx**: Standard HTTP GET requests
- **http_post_2xx**: HTTP POST requests with JSON body
- **http_with_auth**: Requests with authentication headers

### Grafana Configuration

- **Dashboards**: Located in `grafana/dashboards/`
- **Data Sources**: Configured in `grafana/datasources/`

Default dashboards are automatically provisioned on startup.

### Alert Rules

Edit `alerts.yml` to customize alert conditions:

- **RidersAPIDown**: Triggers when API is unreachable for 2+ minutes
- **RidersAPISlowResponse**: Triggers when response time exceeds 2 seconds
- **RidersAPIHighErrorRate**: Triggers when success rate drops below 95%
- **RidersAPISSLCertExpiringSoon**: Triggers when SSL certificate expires in <30 days

## Services

| Service | Port | Description |
|---------|------|-------------|
| Grafana | 3000 | Web UI for dashboards and visualization |
| Prometheus | 9090 | Metrics database and query interface |
| Blackbox Exporter | 9115 | HTTP/HTTPS endpoint probing service |
| Node Exporter | 9100 | System metrics exporter |

## Alerting

Prometheus alert rules are defined in `alerts.yml`. Current alerts include:

### Critical Alerts

- **RidersAPIDown**: API endpoint is unreachable
  - Severity: `critical`
  - Duration: 2 minutes

### Warning Alerts

- **RidersAPISlowResponse**: Response time > 2 seconds
- **RidersAPIHighErrorRate**: Success rate < 95%
- **RidersAPISSLCertExpiringSoon**: SSL certificate expires in < 30 days

### Configuring Alertmanager

To send alerts to external systems (email, Slack, PagerDuty, etc.), configure Alertmanager in `prometheus.yml`:

```yaml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
```

## Useful Queries

### Blackbox Exporter Queries

Count total probes per URL (last hour):
```promql
count_over_time(probe_success{job="blackbox"}[1h])
```

Count successful requests per URL:
```promql
sum_over_time(probe_success{job="blackbox"}[1h])
```

Request rate (requests per minute):
```promql
count_over_time(probe_success{job="blackbox"}[1m])
```

Response time (average):
```promql
avg(probe_http_duration_seconds{job="blackbox"})
```

Success rate percentage:
```promql
avg(probe_success{job="blackbox"}) * 100
```

See `prometheus-queries.txt` for more query examples.

## Project Structure

```
fez-monitoring/
├── fez-grafana-monitoring/
│   ├── alerts.yml              # Prometheus alert rules
│   ├── blackbox.yml            # Blackbox exporter configuration
│   ├── docker-compose.yml      # Docker Compose configuration
│   ├── prometheus.yml          # Prometheus configuration
│   ├── prometheus-queries.txt  # Useful PromQL queries
│   └── grafana/
│       ├── dashboards/
│       │   ├── dashboard.yml
│       │   └── riders-api-dashboard.json
│       └── datasources/
│           └── datasource.yml
└── riders-api-monitoring/
    └── [same structure as above]
```

## Maintenance

### Stopping Services

```bash
docker-compose down
```

### Stopping and Removing Volumes

```bash
docker-compose down -v
```

 **Warning**: This will delete all stored metrics and Grafana dashboards.

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f prometheus
docker-compose logs -f grafana
```

### Updating Services

```bash
docker-compose pull
docker-compose up -d
```

## Security Notes

**Important**: The default Grafana credentials (`admin/admin123`) are for development only. Change them in production:

1. Edit `docker-compose.yml`:
   ```yaml
   environment:
     - GF_SECURITY_ADMIN_PASSWORD=your-secure-password
   ```

2. Restart Grafana:
   ```bash
   docker-compose restart grafana
   ```

## License

This project is for internal use by FEZ Delivery.

## Support

For issues or questions, please contact the DevOps team.


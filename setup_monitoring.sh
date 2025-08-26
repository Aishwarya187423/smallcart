#!/bin/bash
# Grafana and OpenTelemetry Collector Setup Script for EC2
# This script installs and configures Grafana, Tempo, and OTEL Collector

set -e

echo "🚀 Setting up Grafana and OpenTelemetry Collector on EC2..."

# Update system
sudo yum update -y

# Install required packages
sudo yum install -y wget curl unzip

# Create directories
sudo mkdir -p /opt/grafana-stack
sudo mkdir -p /var/lib/grafana
sudo mkdir -p /var/lib/tempo
sudo mkdir -p /var/log/grafana-stack

echo "📊 Installing Grafana..."
# Install Grafana
sudo wget https://dl.grafana.com/enterprise/release/grafana-enterprise-10.2.0.linux-amd64.tar.gz
sudo tar -zxvf grafana-enterprise-10.2.0.linux-amd64.tar.gz
sudo mv grafana-10.2.0 /opt/grafana
sudo chown -R ec2-user:ec2-user /opt/grafana
sudo chown -R ec2-user:ec2-user /var/lib/grafana

echo "🔍 Installing Grafana Tempo (for traces)..."
# Install Tempo
sudo wget https://github.com/grafana/tempo/releases/download/v2.3.0/tempo-linux-amd64.tar.gz
sudo tar -zxvf tempo-linux-amd64.tar.gz
sudo mv tempo-linux-amd64 /opt/tempo
sudo chown -R ec2-user:ec2-user /opt/tempo

echo "📡 Installing OpenTelemetry Collector..."
# Install OTEL Collector
sudo wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.88.0/otelcol_0.88.0_linux_amd64.tar.gz
sudo tar -zxvf otelcol_0.88.0_linux_amd64.tar.gz
sudo mv otelcol /opt/otel-collector
sudo chown -R ec2-user:ec2-user /opt/otel-collector

echo "⚙️ Creating configuration files..."

# Create Grafana configuration
cat > /opt/grafana/conf/custom.ini << 'EOF'
[server]
http_port = 3000
http_addr = 0.0.0.0

[security]
admin_user = admin
admin_password = SmallCart@123

[dashboards]
default_home_dashboard_path = /opt/grafana/dashboards/smallcart-overview.json

[datasources]
path = /opt/grafana/conf/provisioning/datasources

[log]
mode = file
file_path = /var/log/grafana-stack/grafana.log
level = info
EOF

# Create datasources directory
sudo mkdir -p /opt/grafana/conf/provisioning/datasources
sudo mkdir -p /opt/grafana/conf/provisioning/dashboards

# Create datasources configuration
cat > /opt/grafana/conf/provisioning/datasources/datasources.yaml << 'EOF'
apiVersion: 1

datasources:
  - name: Tempo
    type: tempo
    access: proxy
    url: http://localhost:3200
    uid: tempo
    editable: false

  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    uid: prometheus
    editable: false
    isDefault: true
EOF

# Create Tempo configuration
cat > /opt/tempo/tempo.yaml << 'EOF'
server:
  http_listen_port: 3200
  log_level: info

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

ingester:
  max_block_duration: 5m

compactor:
  compaction:
    block_retention: 1h

storage:
  trace:
    backend: local
    local:
      path: /var/lib/tempo/blocks
    wal:
      path: /var/lib/tempo/wal

query_frontend:
  search:
    duration_slo: 5s
    throughput_bytes_slo: 1.073741824e+09
  trace_by_id:
    duration_slo: 5s
EOF

# Create OTEL Collector configuration
cat > /opt/otel-collector/config.yaml << 'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
  resource:
    attributes:
      - key: service.namespace
        value: smallcart
        action: insert

exporters:
  otlp/tempo:
    endpoint: http://localhost:4317
    tls:
      insecure: true
  
  prometheus:
    endpoint: "0.0.0.0:8889"
    send_timestamps: true
    metric_expiration: 180m
  
  logging:
    loglevel: debug

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [otlp/tempo, logging]
    
    metrics:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [prometheus, logging]
    
    logs:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [logging]

  extensions: []
EOF

echo "📊 Creating SmallCart Dashboard..."
# Create dashboard directory
sudo mkdir -p /opt/grafana/dashboards

# Create SmallCart overview dashboard
cat > /opt/grafana/dashboards/smallcart-overview.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "SmallCart Application Overview",
    "tags": ["smallcart", "application"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "HTTP Requests per Second",
        "type": "stat",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "User Registrations",
        "type": "stat",
        "targets": [
          {
            "expr": "user_registrations_total",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Total Orders",
        "type": "stat",
        "targets": [
          {
            "expr": "orders_total",
            "refId": "A"
          }
        ],
        "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0}
      },
      {
        "id": 4,
        "title": "Request Duration",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, http_request_duration_seconds_bucket)",
            "refId": "A",
            "legendFormat": "95th percentile"
          },
          {
            "expr": "histogram_quantile(0.50, http_request_duration_seconds_bucket)",
            "refId": "B",
            "legendFormat": "50th percentile"
          }
        ],
        "gridPos": {"h": 8, "w": 18, "x": 0, "y": 8}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "5s"
  }
}
EOF

# Create dashboard provisioning config
cat > /opt/grafana/conf/provisioning/dashboards/dashboards.yaml << 'EOF'
apiVersion: 1

providers:
  - name: 'smallcart'
    orgId: 1
    folder: 'SmallCart'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /opt/grafana/dashboards
EOF

echo "🔧 Installing Prometheus for metrics..."
# Install Prometheus
sudo wget https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz
sudo tar -zxvf prometheus-2.47.0.linux-amd64.tar.gz
sudo mv prometheus-2.47.0.linux-amd64 /opt/prometheus
sudo chown -R ec2-user:ec2-user /opt/prometheus

# Create Prometheus configuration
cat > /opt/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'otel-collector'
    static_configs:
      - targets: ['localhost:8889']

  - job_name: 'smallcart-app'
    static_configs:
      - targets: ['localhost:5000']
    metrics_path: '/metrics'
    scrape_interval: 10s
EOF

echo "🔧 Creating systemd services..."

# Create Grafana service
sudo cat > /etc/systemd/system/grafana.service << 'EOF'
[Unit]
Description=Grafana Server
Documentation=https://grafana.com/docs/
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/grafana
ExecStart=/opt/grafana/bin/grafana-server --config=/opt/grafana/conf/custom.ini --homepath=/opt/grafana
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Tempo service
sudo cat > /etc/systemd/system/tempo.service << 'EOF'
[Unit]
Description=Grafana Tempo
Documentation=https://grafana.com/docs/tempo/
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/tempo
ExecStart=/opt/tempo/tempo -config.file=/opt/tempo/tempo.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create OTEL Collector service
sudo cat > /etc/systemd/system/otel-collector.service << 'EOF'
[Unit]
Description=OpenTelemetry Collector
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/otel-collector
ExecStart=/opt/otel-collector/otelcol --config=/opt/otel-collector/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Create Prometheus service
sudo cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/prometheus
ExecStart=/opt/prometheus/prometheus --config.file=/opt/prometheus/prometheus.yml --storage.tsdb.path=/opt/prometheus/data --web.console.templates=/opt/prometheus/consoles --web.console.libraries=/opt/prometheus/console_libraries --web.listen-address=0.0.0.0:9090
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "🚀 Starting services..."
# Reload systemd and start services
sudo systemctl daemon-reload

# Start Tempo first (for traces)
sudo systemctl enable tempo
sudo systemctl start tempo

# Start Prometheus (for metrics)
sudo systemctl enable prometheus  
sudo systemctl start prometheus

# Start OTEL Collector
sudo systemctl enable otel-collector
sudo systemctl start otel-collector

# Start Grafana last
sudo systemctl enable grafana
sudo systemctl start grafana

echo "⏳ Waiting for services to start..."
sleep 10

echo "✅ Grafana Stack Setup Complete!"
echo ""
echo "🌐 Service URLs:"
echo "  • Grafana: http://$(curl -s http://checkip.amazonaws.com):3000"
echo "    - Username: admin"
echo "    - Password: SmallCart@123"
echo ""
echo "  • Prometheus: http://$(curl -s http://checkip.amazonaws.com):9090"
echo "  • Tempo: http://$(curl -s http://checkip.amazonaws.com):3200"
echo "  • OTEL Collector: http://$(curl -s http://checkip.amazonaws.com):4317 (gRPC)"
echo ""
echo "📊 Your SmallCart application metrics and traces will be available in Grafana!"
echo "🔧 Service status can be checked with: sudo systemctl status <service-name>"
echo ""
echo "📝 Log locations:"
echo "  • Grafana: /var/log/grafana-stack/grafana.log"
echo "  • Tempo: sudo journalctl -u tempo -f"
echo "  • Prometheus: sudo journalctl -u prometheus -f"
echo "  • OTEL Collector: sudo journalctl -u otel-collector -f"

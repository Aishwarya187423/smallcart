#!/bin/bash

# SmallCart Complete Monitoring Setup for EC2 (Amazon Linux 2023)
# This script sets up Grafana + Prometheus + basic telemetry collection
# Bypasses package manager conflicts by using direct downloads

set -e

echo "🚀 Setting up Complete Monitoring Stack for SmallCart..."

# Kill any existing monitoring services
echo "🛑 Stopping any existing monitoring services..."
sudo systemctl stop grafana prometheus tempo otel-collector 2>/dev/null || true
sudo pkill -f "grafana-server|prometheus|tempo|otelcol" 2>/dev/null || true
sleep 2

# Create monitoring directories
echo "📁 Setting up directories..."
mkdir -p /opt/monitoring/{grafana,prometheus,tempo,otel-collector,node_exporter}
cd /opt/monitoring

# Function to check if port is in use and kill process
check_and_free_port() {
    local port=$1
    local service_name=$2
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "⚠️  Port $port is in use by another process, killing it..."
        sudo lsof -ti :$port | xargs sudo kill -9 2>/dev/null || true
        sleep 2
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local port=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:$port >/dev/null 2>&1; then
            echo "✅ $service_name is ready on port $port"
            return 0
        fi
        sleep 2
        ((attempt++))
        echo "⏳ Waiting for $service_name to start... ($attempt/$max_attempts)"
    done
    
    echo "❌ $service_name failed to start on port $port"
    return 1
}

# Install Grafana
echo "📊 Installing Grafana..."
cd /opt/monitoring/grafana

echo "⬇️  Downloading Grafana..."
wget -q https://dl.grafana.com/oss/release/grafana-10.2.0.linux-amd64.tar.gz
tar -xzf grafana-10.2.0.linux-amd64.tar.gz --strip-components=1
rm grafana-10.2.0.linux-amd64.tar.gz
echo "✅ Grafana downloaded"

# Configure Grafana
cat > conf/defaults.ini << 'EOF'
[paths]
data = /opt/monitoring/grafana/data
logs = /opt/monitoring/grafana/logs
plugins = /opt/monitoring/grafana/plugins
provisioning = /opt/monitoring/grafana/provisioning

[server]
http_port = 3000
domain = localhost
root_url = http://localhost:3000/

[security]
admin_user = admin
admin_password = SmallCart@123

[auth.anonymous]
enabled = false

[log]
mode = console file
level = info

[dashboards]
default_home_dashboard_path = /opt/monitoring/grafana/provisioning/dashboards/smallcart-dashboard.json
EOF

# Create Grafana directories
mkdir -p data logs plugins provisioning/{dashboards,datasources}

# Configure Prometheus datasource for Grafana
cat > provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    uid: prometheus
    isDefault: true
EOF

# Create SmallCart Dashboard
cat > provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1
providers:
  - name: 'smallcart'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /opt/monitoring/grafana/provisioning/dashboards
EOF

# SmallCart Application Dashboard
cat > provisioning/dashboards/smallcart-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "SmallCart Application Dashboard",
    "tags": ["smallcart"],
    "style": "dark",
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "HTTP Requests per Second",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(flask_http_request_total[1m])",
            "legendFormat": "{{method}} {{path}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "HTTP Response Times",
        "type": "graph", 
        "targets": [
          {
            "expr": "flask_http_request_duration_seconds",
            "legendFormat": "{{method}} {{path}}"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      }
    ],
    "time": {"from": "now-1h", "to": "now"},
    "refresh": "5s"
  }
}
EOF

# Install Prometheus
echo "📈 Installing Prometheus..."
cd /opt/monitoring/prometheus

echo "⬇️  Downloading Prometheus..."
wget -q https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar -xzf prometheus-2.45.0.linux-amd64.tar.gz --strip-components=1
rm prometheus-2.45.0.linux-amd64.tar.gz
echo "✅ Prometheus downloaded"

# Create Prometheus data directory
mkdir -p data

# Configure Prometheus
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'smallcart-app'
    static_configs:
      - targets: ['localhost:5000']
    scrape_interval: 10s
    metrics_path: /metrics
    scrape_timeout: 10s

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 15s

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
    scrape_interval: 15s
EOF

# Create Prometheus systemd service
cat > /etc/systemd/system/prometheus.service << 'EOF'
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/
After=network.target

[Service]
Type=simple
User=monitoring
Group=monitoring
ExecStart=/opt/monitoring/prometheus/prometheus \
  --config.file=/opt/monitoring/prometheus/prometheus.yml \
  --storage.tsdb.path=/opt/monitoring/prometheus/data \
  --web.console.templates=/opt/monitoring/prometheus/consoles \
  --web.console.libraries=/opt/monitoring/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle \
  --web.enable-admin-api
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=prometheus
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Prometheus configured"

# Install Node Exporter for system metrics
echo "📊 Installing Node Exporter..."
cd /opt/monitoring/node_exporter

echo "⬇️  Downloading Node Exporter..."
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xzf node_exporter-1.6.1.linux-amd64.tar.gz --strip-components=1
rm node_exporter-1.6.1.linux-amd64.tar.gz
echo "✅ Node Exporter downloaded"

# Create Node Exporter systemd service
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
After=network.target

[Service]
Type=simple
User=monitoring
Group=monitoring
ExecStart=/opt/monitoring/node_exporter/node_exporter \
  --web.listen-address=0.0.0.0:9100 \
  --collector.systemd \
  --collector.processes \
  --collector.filesystem.ignored-mount-points="^/(dev|proc|sys|var/lib/docker/.+)($|/)" \
  --collector.filesystem.ignored-fs-types="^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$"
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=node_exporter

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Node Exporter configured"

# Install Tempo
echo "🔍 Installing Tempo..."
cd /opt/monitoring/tempo

echo "⬇️  Downloading Tempo..."
wget -q https://github.com/grafana/tempo/releases/download/v2.3.0/tempo_2.3.0_linux_amd64.tar.gz
tar -xzf tempo_2.3.0_linux_amd64.tar.gz --strip-components=1
rm tempo_2.3.0_linux_amd64.tar.gz
echo "✅ Tempo downloaded"

# Create Tempo data directory
mkdir -p data traces generator

# Configure Tempo
cat > tempo.yml << 'EOF'
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

storage:
  trace:
    backend: local
    local:
      path: /opt/monitoring/tempo/traces

metrics_generator:
  storage:
    path: /opt/monitoring/tempo/generator
EOF

# Create Tempo systemd service
cat > /etc/systemd/system/tempo.service << 'EOF'
[Unit]
Description=Tempo Tracing Backend
Documentation=https://grafana.com/docs/tempo/
After=network.target

[Service]
Type=simple
User=monitoring
Group=monitoring
ExecStart=/opt/monitoring/tempo/tempo -config.file=/opt/monitoring/tempo/tempo.yml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=tempo
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Tempo configured"

# Install OpenTelemetry Collector
echo "📡 Installing OpenTelemetry Collector..."
cd /opt/monitoring/otel-collector

echo "⬇️  Downloading OTEL Collector..."
wget -q https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.88.0/otelcol_0.88.0_linux_amd64.tar.gz
tar -xzf otelcol_0.88.0_linux_amd64.tar.gz --strip-components=1
rm otelcol_0.88.0_linux_amd64.tar.gz
echo "✅ OTEL Collector downloaded"

# Configure OTEL Collector
cat > otel-collector.yml << 'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:

exporters:
  prometheus:
    endpoint: "0.0.0.0:8889"
  otlp/tempo:
    endpoint: http://localhost:3200

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/tempo]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
EOF

# Create OTEL Collector systemd service
cat > /etc/systemd/system/otel-collector.service << 'EOF'
[Unit]
Description=OpenTelemetry Collector
Documentation=https://opentelemetry.io/docs/collector/
After=network.target

[Service]
Type=simple
User=monitoring
Group=monitoring
ExecStart=/opt/monitoring/otel-collector/otelcol --config=/opt/monitoring/otel-collector/otel-collector.yml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=otel-collector

[Install]
WantedBy=multi-user.target
EOF

echo "✅ OTEL Collector configured"

# Create monitoring user and group
echo "👤 Creating monitoring user and group..."
if ! id -u monitoring >/dev/null 2>&1; then
    useradd --system --shell /bin/false --home-dir /opt/monitoring --no-create-home monitoring
    echo "✅ Created monitoring user"
else
    echo "✅ Monitoring user already exists"
fi

# Set proper ownership for all monitoring directories
echo "🔧 Setting ownership and permissions..."
chown -R monitoring:monitoring /opt/monitoring
chmod -R 755 /opt/monitoring

# Port cleanup function
cleanup_port() {
    local port=$1
    local service_name=$2
    
    echo "🧹 Cleaning up port $port for $service_name..."
    
    # Kill any process using the port
    if lsof -t -i:$port > /dev/null 2>&1; then
        echo "Killing processes on port $port..."
        lsof -t -i:$port | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Stop and disable existing service if it exists
    if systemctl is-active --quiet $service_name 2>/dev/null; then
        systemctl stop $service_name
    fi
    
    if systemctl is-enabled --quiet $service_name 2>/dev/null; then
        systemctl disable $service_name
    fi
}

# Wait for service to be ready
wait_for_service() {
    local port=$1
    local service_name=$2
    local max_wait=$3
    
    echo "⏳ Waiting for $service_name on port $port..."
    
    local count=0
    while [ $count -lt $max_wait ]; do
        if curl -s http://localhost:$port > /dev/null 2>&1; then
            echo "✅ $service_name is ready on port $port"
            return 0
        fi
        sleep 2
        count=$((count + 2))
    done
    
    echo "⚠️  $service_name not responding on port $port after ${max_wait}s"
    return 1
}

# Clean up existing services
echo "🧹 Cleaning up existing services..."
cleanup_port 3000 grafana-server
cleanup_port 9090 prometheus
cleanup_port 9100 node_exporter
cleanup_port 3200 tempo
cleanup_port 4317 otel-collector

# Reload systemd
systemctl daemon-reload

# Start services in correct order
echo "🚀 Starting monitoring services..."

# Start Node Exporter first
echo "Starting Node Exporter..."
systemctl enable node_exporter
systemctl start node_exporter
wait_for_service 9100 "Node Exporter" 30

# Start Prometheus
echo "Starting Prometheus..."
systemctl enable prometheus
systemctl start prometheus
wait_for_service 9090 "Prometheus" 60

# Start Tempo
echo "Starting Tempo..."
systemctl enable tempo
systemctl start tempo
sleep 10  # Tempo needs more time to initialize

# Check Tempo status
if ! systemctl is-active --quiet tempo; then
    echo "⚠️  Tempo failed to start, checking logs..."
    journalctl -u tempo --no-pager -n 20
fi

# Start OTEL Collector
echo "Starting OpenTelemetry Collector..."
systemctl enable otel-collector
systemctl start otel-collector
sleep 5

# Start Grafana
echo "Starting Grafana..."
systemctl enable grafana-server
systemctl start grafana-server
wait_for_service 3000 "Grafana" 60

# Final status check
echo ""
echo "🔍 Service Status Check:"
echo "======================="

check_service() {
    local service=$1
    local port=$2
    
    if systemctl is-active --quiet $service; then
        if curl -s http://localhost:$port > /dev/null 2>&1; then
            echo "✅ $service: Running and accessible on port $port"
        else
            echo "⚠️  $service: Running but not accessible on port $port"
        fi
    else
        echo "❌ $service: Not running"
        journalctl -u $service --no-pager -n 5
    fi
}

check_service "node_exporter" "9100"
check_service "prometheus" "9090"
check_service "tempo" "3200"
check_service "otel-collector" "4317"
check_service "grafana-server" "3000"

echo ""
echo "🎉 SmallCart Monitoring Stack Setup Complete!"
echo "============================================="
echo "📊 Grafana Dashboard: http://$(curl -s ifconfig.me):3000"
echo "📈 Prometheus: http://$(curl -s ifconfig.me):9090"
echo "🔍 Tempo: http://$(curl -s ifconfig.me):3200"
echo "📊 Node Exporter: http://$(curl -s ifconfig.me):9100"
echo ""
echo "Default Grafana Login:"
echo "Username: admin"
echo "Password: admin"
echo ""
echo "SmallCart Application: http://$(curl -s ifconfig.me):5000"
echo ""

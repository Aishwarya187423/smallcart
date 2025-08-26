#!/bin/bash

echo "🔧 Simple Grafana Startup..."

# Check if Grafana binary exists
if [ ! -f /opt/monitoring/grafana/bin/grafana ]; then
    echo "❌ Grafana binary not found"
    exit 1
fi

echo "✅ Found Grafana binary"

# Create simple Grafana configuration
cat > /opt/monitoring/grafana/conf/custom.ini << 'EOF'
[server]
http_addr = 0.0.0.0
http_port = 3000

[security]
admin_user = admin
admin_password = admin

[paths]
data = /opt/monitoring/grafana/data
logs = /opt/monitoring/grafana/logs
plugins = /opt/monitoring/grafana/plugins

[log]
mode = console

[log.console]
level = info
format = console
EOF

echo "✅ Configuration created"

echo "✅ Configuration created"

# Set ownership and create directories
chown -R monitoring:monitoring /opt/monitoring/grafana
mkdir -p /opt/monitoring/grafana/logs

# Stop any existing processes
pkill -f grafana || true
sleep 2

# Start Grafana directly in background
echo "🚀 Starting Grafana..."
cd /opt/monitoring/grafana
sudo -u monitoring ./bin/grafana server --config=conf/custom.ini > logs/grafana.log 2>&1 &

sleep 5

# Check if it's running
if curl -s http://localhost:3000/api/health > /dev/null; then
    echo "✅ Grafana is running!"
    echo "🌐 Access: http://$(curl -s ifconfig.me):3000"
    echo "📝 Login: admin / admin"
    echo ""
    echo "🎯 SmallCart Stack Status:"
    echo "   ✅ App: http://$(curl -s ifconfig.me):5000"
    echo "   ✅ Prometheus: http://$(curl -s ifconfig.me):9090"
    echo "   ✅ Grafana: http://$(curl -s ifconfig.me):3000"
else
    echo "❌ Grafana failed to start"
    echo "Last 10 lines of log:"
    tail -10 /opt/monitoring/grafana/logs/grafana.log
fi

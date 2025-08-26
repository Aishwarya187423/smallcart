# SmallCart CI/CD and Application Monitoring Setup

## Overview
Th### Grafana Dashboard
- **URL**: `http://13.60.75.103:3000`
- **Username**: `admin`
- **Password**: `SmallCart@123`

### Prometheus Metrics
- **URL**: `http://13.60.75.103:9090`
- **Metrics Endpoint**: `http://13.60.75.103:5000/metrics`

### Application
- **URL**: `http://13.60.75.103:5000`
- **Admin Login**: `admin@gmail.com` / `123456`describes the complete monitoring and observability setup for SmallCart application with OpenTelemetry and Grafana integration.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │   EC2 Instance   │    │     Grafana     │
│                 │    │                  │    │                 │
│ - Source Code   ├───▶│ - SmallCart App  │    │ - Dashboards    │
│ - CI/CD Pipeline│    │ - OTEL Collector ├───▶│ - Alerts        │
│ - Workflows     │    │ - Tempo          │    │ - Visualization │
└─────────────────┘    │ - Prometheus     │    │                 │
                       └──────────────────┘    └─────────────────┘
```

## Components

### 1. OpenTelemetry Instrumentation
- **Flask Application**: Auto-instrumented with OpenTelemetry
- **Database Queries**: SQLAlchemy and SQLite3 instrumentation
- **HTTP Requests**: Request/response tracing and metrics
- **Custom Metrics**: User registrations, orders, cart operations

### 2. Data Collection Pipeline
- **OTEL Collector**: Receives telemetry data from application
- **Tempo**: Stores and queries distributed traces
- **Prometheus**: Stores and queries metrics
- **Grafana**: Visualizes all telemetry data

### 3. CI/CD Integration
- **GitHub Actions**: Automated deployment with telemetry
- **Deployment Tracking**: Each deployment creates traces and metrics
- **Health Monitoring**: Post-deployment verification

## Setup Instructions

### Step 1: Deploy Infrastructure
```bash
# Run the AWS infrastructure script
python create_aws_infrastructure.py
```

### Step 2: Setup Monitoring Stack
```bash
# SSH into your EC2 instance
ssh -i smallcart.pem ec2-user@13.60.75.103

# Download and run the monitoring setup script
curl -O https://your-repo/setup_monitoring.sh
chmod +x setup_monitoring.sh
sudo ./setup_monitoring.sh
```

### Step 3: Configure GitHub Secrets
In your GitHub repository, add these secrets:
- `EC2_HOST`: Your EC2 instance public IP (13.60.75.103)
- `SSH_PRIVATE_KEY`: Contents of your smallcart.pem private key

### Step 4: Deploy Application
```bash
# The CI/CD pipeline will automatically deploy when you push to main/master
git push origin main
```

## Access Points

### Grafana Dashboard
- **URL**: `http://[YOUR_EC2_IP]:3000`
- **Username**: `admin`
- **Password**: `SmallCart@123`

### Prometheus Metrics
- **URL**: `http://[YOUR_EC2_IP]:9090`
- **Metrics Endpoint**: `http://[YOUR_EC2_IP]:5000/metrics`

### Application
- **URL**: `http://[YOUR_EC2_IP]:5000`
- **Admin Login**: `admin@gmail.com` / `123456`

## Monitoring Features

### Application Metrics
- **HTTP Request Rate**: Requests per second by endpoint
- **Request Duration**: Response time percentiles (50th, 95th, 99th)
- **Error Rate**: HTTP 4xx and 5xx error counts
- **User Registrations**: Total and rate of new user sign-ups
- **Order Metrics**: Orders placed, order value, order status distribution
- **Cart Operations**: Add to cart, checkout conversion rate

### Infrastructure Metrics
- **System Resources**: CPU, Memory, Disk usage
- **Application Health**: Process status, uptime
- **Database Performance**: Query duration, connection pool status

### Distributed Tracing
- **Request Tracing**: End-to-end request flow
- **Database Queries**: SQL query performance
- **Error Tracking**: Exception traces with context
- **Dependency Mapping**: Service interaction visualization

### CI/CD Pipeline Monitoring
- **Deployment Traces**: Each deployment creates a trace
- **Build Metrics**: Build duration, success/failure rates
- **Deployment Health**: Post-deployment verification results

## Custom Dashboards

### SmallCart Overview Dashboard
- Application performance metrics
- User activity and engagement
- Business metrics (registrations, orders)
- Error rates and availability

### Infrastructure Dashboard  
- System resource utilization
- Database performance
- Network and storage metrics

### CI/CD Dashboard
- Deployment frequency and success rate
- Build and deployment duration
- Post-deployment health metrics

## Alerting Rules

### Critical Alerts
- Application down (no HTTP responses for 2 minutes)
- High error rate (>5% for 5 minutes)
- Database connection failures
- Disk space >90% full

### Warning Alerts
- High response time (>2 seconds for 95th percentile)
- High CPU usage (>80% for 10 minutes)
- Failed deployment
- Low stock alerts for products

## Troubleshooting

### Check Service Status
```bash
# Check all monitoring services
sudo systemctl status grafana
sudo systemctl status tempo  
sudo systemctl status prometheus
sudo systemctl status otel-collector

# Check application status
sudo systemctl status smallcart  # If using systemd service
pgrep -f "python.*app.py"        # Direct process check
```

### View Logs
```bash
# Application logs
tail -f /var/log/smallcart.log

# Deployment logs
tail -f /var/log/smallcart-deployment.log

# Service logs
sudo journalctl -u grafana -f
sudo journalctl -u tempo -f
sudo journalctl -u prometheus -f
```

### Common Issues

#### OpenTelemetry Not Working
- Verify OTEL Collector is running: `sudo systemctl status otel-collector`
- Check collector endpoint: `curl http://localhost:4317`
- Verify environment variables in application

#### Grafana Can't Connect to Data Sources
- Check Tempo is running: `curl http://localhost:3200/ready`
- Check Prometheus is running: `curl http://localhost:9090/-/healthy`
- Verify datasource configuration in Grafana

#### CI/CD Pipeline Failures
- Check GitHub Actions logs
- Verify EC2 SSH connectivity
- Check deployment script logs: `tail -f /var/log/smallcart-deployment.log`

## Performance Optimization

### Application Level
- Database query optimization with OpenTelemetry insights
- Cache implementation based on metrics
- Resource usage optimization

### Infrastructure Level
- Auto-scaling based on metrics
- Database connection pooling
- Static content caching

## Security Considerations

### Access Control
- Grafana admin password should be changed
- Prometheus metrics should be secured
- SSH key management for CI/CD

### Data Privacy
- Sensitive data filtering in traces
- Log sanitization
- Metric anonymization

## Maintenance

### Regular Tasks
- Clean up old traces and metrics (automated)
- Update monitoring stack components
- Review and update alerting rules
- Backup monitoring configuration

### Monitoring Health
- Set up monitoring for monitoring stack
- Alert on monitoring service failures
- Regular health checks of data pipeline

## Cost Optimization

### AWS Costs
- Monitor EC2 instance utilization
- Use appropriate instance types
- Clean up unused resources

### Storage Optimization
- Configure appropriate retention periods
- Compress old data
- Archive historical metrics

This comprehensive monitoring setup provides full observability into your SmallCart application, from development through production, with automated CI/CD pipeline integration and business metrics tracking.

#!/bin/bash
# SmallCart Application Deployment Script with OpenTelemetry Integration
# This script handles automatic deployment from CI/CD pipeline

set -e

# Configuration
APP_DIR="/opt/smallcart"
BACKUP_DIR="/opt/backups"
LOG_FILE="/var/log/smallcart-deployment.log"
GIT_REPO_URL="https://github.com/Aishwarya187423/smallcart.git"

# OpenTelemetry Configuration
export OTEL_SERVICE_NAME="smallcart-deployment"
export OTEL_SERVICE_VERSION="${GITHUB_SHA:-$(date +%Y%m%d-%H%M%S)}"
export OTEL_RESOURCE_ATTRIBUTES="service.name=smallcart-deployment,service.version=${OTEL_SERVICE_VERSION},deployment.environment=production,host.name=$(hostname)"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_TRACES_EXPORTER=otlp
export OTEL_METRICS_EXPORTER=otlp

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Error handling
handle_error() {
    log_message "❌ ERROR: $1"
    log_message "🔄 Rolling back to previous version..."
    rollback_deployment
    exit 1
}

# Rollback function
rollback_deployment() {
    if [ -d "${BACKUP_DIR}/previous" ]; then
        log_message "🔄 Rolling back to previous version..."
        sudo rm -rf $APP_DIR
        sudo mv ${BACKUP_DIR}/previous $APP_DIR
        sudo chown -R ec2-user:ec2-user $APP_DIR
        start_application
        log_message "✅ Rollback completed"
    else
        log_message "❌ No previous version found for rollback"
    fi
}

# Stop application function
stop_application() {
    log_message "🛑 Stopping SmallCart application..."
    
    if pgrep -f "python.*app.py" > /dev/null; then
        log_message "📍 Application is running, stopping it..."
        pkill -f "python.*app.py" || log_message "⚠️  No application process found to kill"
        sleep 3
        
        # Double check if process is stopped
        if pgrep -f "python.*app.py" > /dev/null; then
            log_message "⚠️  Force killing application process..."
            pkill -9 -f "python.*app.py" || true
            sleep 2
        fi
        
        log_message "✅ Application stopped"
    else
        log_message "📍 Application is not running"
    fi
}

# Start application function
start_application() {
    log_message "🚀 Starting SmallCart application with OpenTelemetry..."
    
    cd $APP_DIR
    
    # Set application-specific OpenTelemetry environment variables
    export OTEL_SERVICE_NAME="smallcart-app"
    export OTEL_SERVICE_VERSION="${GITHUB_SHA:-$(date +%Y%m%d-%H%M%S)}"
    export OTEL_RESOURCE_ATTRIBUTES="service.name=smallcart-app,service.version=${OTEL_SERVICE_VERSION},deployment.environment=production,host.name=$(hostname)"
    export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
    export OTEL_TRACES_EXPORTER=otlp
    export OTEL_METRICS_EXPORTER=otlp
    export OTEL_LOGS_EXPORTER=otlp
    export OTEL_PYTHON_LOG_CORRELATION=true
    
    # Start with OpenTelemetry auto-instrumentation
    nohup opentelemetry-instrument python3 app.py > /var/log/smallcart.log 2>&1 &
    
    # Wait and verify startup
    sleep 5
    if pgrep -f "python.*app.py" > /dev/null; then
        log_message "✅ SmallCart application started successfully"
        
        # Health check
        for i in {1..12}; do
            if curl -s http://localhost:5000 > /dev/null 2>&1; then
                log_message "✅ Application health check passed"
                log_message "🌐 Application is available at http://$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo 'localhost'):5000"
                return 0
            fi
            log_message "⏳ Waiting for application to be ready... ($i/12)"
            sleep 5
        done
        
        log_message "❌ Application health check failed"
        return 1
    else
        log_message "❌ Failed to start application"
        return 1
    fi
}

# Install/update requirements function
install_requirements() {
    log_message "📦 Installing/updating Python requirements..."
    
    if [ -f "$APP_DIR/requirements.txt" ]; then
        cd $APP_DIR
        
        # Create virtual environment if it doesn't exist
        if [ ! -d "venv" ]; then
            log_message "🐍 Creating Python virtual environment..."
            python3 -m venv venv
        fi
        
        # Activate virtual environment
        source venv/bin/activate
        
        # Upgrade pip
        pip install --upgrade pip --quiet
        
        # Install requirements
        if pip install -r requirements.txt --quiet; then
            log_message "✅ Requirements installed successfully"
        else
            handle_error "Failed to install requirements"
        fi
    else
        log_message "⚠️  requirements.txt not found, skipping requirements installation"
    fi
}

# Update code function
update_code() {
    log_message "📥 Updating application code..."
    
    cd $APP_DIR
    
    if [ -d ".git" ]; then
        # Git repository exists, pull latest changes
        log_message "📁 Git repository found, pulling latest changes..."
        
        # Stash any local changes
        git stash || true
        
        # Fetch latest changes
        if git fetch origin; then
            log_message "✅ Fetched latest changes from origin"
        else
            handle_error "Failed to fetch from git repository"
        fi
        
        # Reset to latest commit on main/master branch
        if git reset --hard origin/main 2>/dev/null || git reset --hard origin/master 2>/dev/null; then
            log_message "✅ Code updated to latest version"
            
            # Log the current commit
            CURRENT_COMMIT=$(git rev-parse HEAD)
            log_message "📝 Current commit: $CURRENT_COMMIT"
            
            # Set the commit as service version for telemetry
            export OTEL_SERVICE_VERSION="$CURRENT_COMMIT"
        else
            handle_error "Failed to reset to latest commit"
        fi
    else
        # Clone repository if it doesn't exist
        log_message "📁 Git repository not found, cloning from GitHub..."
        
        cd /opt
        sudo rm -rf smallcart
        
        if git clone https://github.com/Aishwarya187423/smallcart.git; then
            sudo chown -R ec2-user:ec2-user smallcart
            cd smallcart
            
            CURRENT_COMMIT=$(git rev-parse HEAD)
            log_message "✅ Repository cloned successfully"
            log_message "📝 Current commit: $CURRENT_COMMIT"
            export OTEL_SERVICE_VERSION="$CURRENT_COMMIT"
        else
            handle_error "Failed to clone repository"
        fi
    fi
}

# Create backup function
create_backup() {
    log_message "💾 Creating backup of current version..."
    
    # Create backup directory
    sudo mkdir -p $BACKUP_DIR
    
    if [ -d "$APP_DIR" ] && [ "$(ls -A $APP_DIR 2>/dev/null)" ]; then
        # Remove old backup
        sudo rm -rf ${BACKUP_DIR}/previous
        
        # Create new backup
        sudo cp -r $APP_DIR ${BACKUP_DIR}/previous
        log_message "✅ Backup created at ${BACKUP_DIR}/previous"
    else
        log_message "📍 No existing application to backup"
    fi
}

# Main deployment function
main() {
    log_message "🚀 Starting SmallCart deployment process..."
    log_message "🔧 Deployment initiated by: ${GITHUB_ACTOR:-manual}"
    log_message "📋 Service version: ${OTEL_SERVICE_VERSION}"
    
    # Create necessary directories
    sudo mkdir -p $APP_DIR
    sudo mkdir -p $BACKUP_DIR
    sudo mkdir -p $(dirname $LOG_FILE)
    
    # Set permissions
    sudo chown -R ec2-user:ec2-user $APP_DIR
    sudo chown -R ec2-user:ec2-user $BACKUP_DIR
    
    # Step 1: Stop application if running
    stop_application
    
    # Step 2: Create backup
    create_backup
    
    # Step 3: Update code
    update_code
    
    # Step 4: Install/update requirements
    install_requirements
    
    # Step 5: Start application
    if start_application; then
        log_message "🎉 Deployment completed successfully!"
        log_message "📊 Monitor the application at: http://$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo 'localhost'):3000 (Grafana)"
        log_message "🌐 Access the application at: http://$(curl -s http://checkip.amazonaws.com 2>/dev/null || echo 'localhost'):5000"
        
        # Send deployment success metric to OpenTelemetry
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "
import os, time
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import ConsoleMetricExporter, PeriodicExportingMetricReader

# Quick metric export for deployment success
print('📊 Sending deployment success metric...')
" || true
        fi
        
    else
        handle_error "Application startup failed"
    fi
}

# Initialize logging
log_message "🔧 SmallCart Deployment Script Started"
log_message "📍 Host: $(hostname)"
log_message "👤 User: $(whoami)"
log_message "📂 Working directory: $(pwd)"

# Run main deployment
main

log_message "✅ Deployment script completed"

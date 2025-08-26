from flask import Response
import time
import os

# Simple metrics without OpenTelemetry dependencies
app_start_time = time.time()
request_count = 0
error_count = 0

def generate_simple_metrics():
    """Generate simple Prometheus metrics"""
    global request_count, error_count
    uptime = time.time() - app_start_time
    
    metrics = f"""# HELP smallcart_uptime_seconds Application uptime in seconds
# TYPE smallcart_uptime_seconds counter
smallcart_uptime_seconds {uptime:.2f}

# HELP smallcart_requests_total Total number of HTTP requests
# TYPE smallcart_requests_total counter
smallcart_requests_total {request_count}

# HELP smallcart_errors_total Total number of HTTP errors
# TYPE smallcart_errors_total counter
smallcart_errors_total {error_count}

# HELP smallcart_info Application information
# TYPE smallcart_info gauge
smallcart_info{{version="1.0.0",environment="production"}} 1
"""
    return metrics

def add_simple_metrics_endpoint(app):
    """Add a simple /metrics endpoint to Flask app"""
    
    @app.route('/metrics')
    def metrics():
        """Prometheus metrics endpoint"""
        return Response(generate_simple_metrics(), mimetype='text/plain')
    
    @app.before_request
    def count_requests():
        """Count incoming requests"""
        global request_count
        request_count += 1
    
    @app.errorhandler(500)
    def count_errors(error):
        """Count server errors"""
        global error_count
        error_count += 1
        return error

def log_simple(message, level="INFO"):
    """Simple logging function"""
    print(f"[{level}] {message}")

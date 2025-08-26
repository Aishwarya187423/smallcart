"""
OpenTelemetry Configuration for SmallCart Application
"""

import os
import logging
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.prometheus import PrometheusMetricReader
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.sqlite3 import SQLite3Instrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from prometheus_client import start_http_server, generate_latest, CONTENT_TYPE_LATEST

def configure_telemetry():
    """Configure OpenTelemetry for SmallCart application"""
    
    # Service information
    service_name = os.getenv('OTEL_SERVICE_NAME', 'smallcart-app')
    service_version = os.getenv('OTEL_SERVICE_VERSION', '1.0.0')
    environment = os.getenv('DEPLOYMENT_ENVIRONMENT', 'production')
    
    # Resource attributes (simplified for Prometheus compatibility)
    resource = Resource.create({
        "service_name": service_name,
        "service_version": service_version,
        "environment": environment,
    })
    
    # Configure tracing (disabled for now to avoid OTLP issues)
    # trace.set_tracer_provider(TracerProvider(resource=resource))
    # tracer_provider = trace.get_tracer_provider()
    
    # OTLP Trace Exporter (to Grafana/Tempo) - DISABLED
    # otlp_trace_exporter = OTLPSpanExporter(
    #     endpoint=os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4317'),
    #     insecure=True,
    # )
    
    # span_processor = BatchSpanProcessor(otlp_trace_exporter)
    # tracer_provider.add_span_processor(span_processor)
    
    # Configure metrics with Prometheus exporter
    prometheus_reader = PrometheusMetricReader()
    
    metrics.set_meter_provider(MeterProvider(
        resource=resource,
        metric_readers=[prometheus_reader]
    ))
    
    # Get tracer and meter for application use
    tracer = None  # Disabled tracing for now
    meter = metrics.get_meter(__name__)
    
    # Create custom metrics
    request_counter = meter.create_counter(
        name="http_requests_total",
        description="Total number of HTTP requests",
        unit="1"
    )
    
    request_duration = meter.create_histogram(
        name="http_request_duration_seconds",
        description="Duration of HTTP requests",
        unit="s"
    )
    
    user_registrations = meter.create_counter(
        name="user_registrations_total",
        description="Total number of user registrations",
        unit="1"
    )
    
    orders_total = meter.create_counter(
        name="orders_total",
        description="Total number of orders placed",
        unit="1"
    )
    
    active_users = meter.create_up_down_counter(
        name="active_users",
        description="Number of currently active users",
        unit="1"
    )
    
    return {
        'tracer': tracer,
        'meter': meter,
        'request_counter': request_counter,
        'request_duration': request_duration,
        'user_registrations': user_registrations,
        'orders_total': orders_total,
        'active_users': active_users,
    }

def instrument_flask_app(app):
    """Instrument Flask application with OpenTelemetry"""
    
    # Configure telemetry
    telemetry = configure_telemetry()
    
    # Auto-instrument Flask
    FlaskInstrumentor().instrument_app(app)
    
    # Auto-instrument database connections
    SQLite3Instrumentor().instrument()
    SQLAlchemyInstrumentor().instrument()
    
    # Auto-instrument HTTP requests
    RequestsInstrumentor().instrument()
    
    # Add custom middleware for metrics
    @app.before_request
    def before_request():
        from flask import request
        import time
        
        # Start timing the request
        request.start_time = time.time()
        
        # Increment request counter
        telemetry['request_counter'].add(1, {
            "method": request.method,
            "endpoint": request.endpoint or "unknown",
            "status_code": "pending"
        })
    
    @app.after_request
    def after_request(response):
        from flask import request
        import time
        
        # Calculate request duration
        if hasattr(request, 'start_time'):
            duration = time.time() - request.start_time
            telemetry['request_duration'].record(duration, {
                "method": request.method,
                "endpoint": request.endpoint or "unknown",
                "status_code": str(response.status_code)
            })
        
        return response
    
    # Store telemetry objects in app config for use in routes
    app.config['telemetry'] = telemetry
    
    # Add metrics endpoint
    add_metrics_endpoint(app)
    
    return app

def create_custom_span(tracer, name, attributes=None):
    """Helper function to create custom spans"""
    span = tracer.start_span(name)
    if attributes:
        for key, value in attributes.items():
            span.set_attribute(key, value)
    return span

def log_with_trace(message, level=logging.INFO):
    """Log messages with trace correlation"""
    current_span = trace.get_current_span()
    if current_span:
        trace_id = current_span.get_span_context().trace_id
        span_id = current_span.get_span_context().span_id
        formatted_message = f"[trace_id={trace_id:032x} span_id={span_id:016x}] {message}"
    else:
        formatted_message = message
    
    logging.log(level, formatted_message)

def add_metrics_endpoint(app):
    """Add /metrics endpoint for Prometheus scraping"""
    from flask import Response
    
    @app.route('/metrics')
    def metrics():
        """Prometheus metrics endpoint"""
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

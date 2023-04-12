"""
gunicorn settings with OpenTelemetry(ADOT)
"""
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

from opentelemetry.sdk.extension.aws.trace import AwsXRayIdGenerator
from opentelemetry import propagate
from opentelemetry.propagators.aws import AwsXRayPropagator

from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.jinja2 import Jinja2Instrumentor
from opentelemetry.instrumentation.pymemcache import PymemcacheInstrumentor

import opentelemetry_instrumentation_mysqlclient

FlaskInstrumentor().instrument()
Jinja2Instrumentor().instrument()
PymemcacheInstrumentor().instrument()
opentelemetry_instrumentation_mysqlclient.MySQLClientInstrumentor().instrument()

wsgi_app = "app:app"
daemon = False
bind = "0.0.0.0:8080"

# workers = 2
accesslog = "-"
errorlog = "-"
loglevel = "info"


def post_fork(server, worker):
    propagate.set_global_textmap(AwsXRayPropagator())

    server.log.info("Worker spawned (pid: %s)", worker.pid)

    resource = Resource.create(attributes={"service.name": "private-isu"})

    span_processor = BatchSpanProcessor(
        OTLPSpanExporter(endpoint="http://localhost:4317")
    )

    trace.set_tracer_provider(
        TracerProvider(
            resource=resource,
            active_span_processor=span_processor,
            id_generator=AwsXRayIdGenerator(),
        )
    )

"""
Usage:

from opentelemetry_instrumentation_mysqlclient import MySQLClientInstrumentor
MySQLClientInstrumentor().instrument()
"""

from typing import Collection

import MySQLdb

from opentelemetry.instrumentation import dbapi
from opentelemetry.instrumentation.instrumentor import BaseInstrumentor

_CONNECTION_ATTRIBUTES = {
    "database": "db",
    "port": "port",
    "host": "host",
    "user": "user",
}
_DATABASE_SYSTEM = "mysql"

_INSTRUMENTS = ("mysqlclient > 2",)
_VERSION = "0.0.1"


class MySQLClientInstrumentor(BaseInstrumentor):
    def instrumentation_dependencies(self) -> Collection[str]:
        return _INSTRUMENTS

    def _instrument(self, **kwargs):
        tracer_provider = kwargs.get("tracer_provider")

        dbapi.wrap_connect(
            __name__,
            MySQLdb,
            "connect",
            _DATABASE_SYSTEM,
            _CONNECTION_ATTRIBUTES,
            version=_VERSION,
            tracer_provider=tracer_provider,
        )

    def _uninstrument(self, **kwargs):
        dbapi.unwrap_connect(MySQLdb, "connect")

    @staticmethod
    def instrument_connection(connection, tracer_provider=None):
        return dbapi.instrument_connection(
            __name__,
            connection,
            _DATABASE_SYSTEM,
            _CONNECTION_ATTRIBUTES,
            version=_VERSION,
            tracer_provider=tracer_provider,
        )

    @staticmethod
    def uninstrument_connection(connection):
        return dbapi.uninstrument_connection(connection)

"""structlog setup. Pretty in TTY, JSON in CI/containers."""

from __future__ import annotations

import logging
import sys

import structlog


def configure(level: str = "INFO") -> None:
    """Configure structlog with sensible defaults.

    - TTY: human-readable colored output
    - non-TTY (CI / container logs): JSON
    """
    is_tty = sys.stderr.isatty()

    shared = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        structlog.processors.TimeStamper(fmt="iso"),
    ]

    if is_tty:
        renderer: structlog.types.Processor = structlog.dev.ConsoleRenderer(colors=True)
    else:
        renderer = structlog.processors.JSONRenderer()

    structlog.configure(
        processors=[*shared, structlog.processors.format_exc_info, renderer],
        wrapper_class=structlog.make_filtering_bound_logger(getattr(logging, level.upper())),
        cache_logger_on_first_use=True,
    )

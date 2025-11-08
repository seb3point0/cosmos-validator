"""Service management commands (monitoring services)"""

import sys

from ..output import success, error, info
from ..progress import show_progress
from ..utils.docker import (
    start_container, stop_container, restart_container, get_container_logs,
    is_container_running
)
from ..utils.errors import DockerError


SERVICES = ['prometheus', 'grafana', 'alertmanager']


def start_services():
    """Start all monitoring services"""
    def _start():
        for service in SERVICES:
            start_container(service)
    
    show_progress("Starting monitoring services...", _start)
    success("All monitoring services started")


def stop_services():
    """Stop all monitoring services"""
    def _stop():
        for service in SERVICES:
            if is_container_running(service):
                stop_container(service)
    
    show_progress("Stopping monitoring services...", _stop)
    success("All monitoring services stopped")


def restart_services():
    """Restart all monitoring services"""
    def _restart():
        for service in SERVICES:
            if is_container_running(service):
                restart_container(service)
    
    show_progress("Restarting monitoring services...", _restart)
    success("All monitoring services restarted")


def logs(service: str = None):
    """View service logs"""
    try:
        if service:
            if service not in SERVICES:
                error(f"Unknown service: {service}. Available: {', '.join(SERVICES)}")
                sys.exit(1)
            services = [service]
        else:
            services = SERVICES
        
        for svc in services:
            if is_container_running(svc):
                info(f"Viewing logs for {svc} (Ctrl+C to exit)...")
                get_container_logs(svc, follow=True)
            else:
                info(f"Service {svc} is not running")
    except DockerError as e:
        error(str(e))
        sys.exit(1)
    except KeyboardInterrupt:
        info("Log viewing stopped")


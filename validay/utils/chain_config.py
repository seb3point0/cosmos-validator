"""Chain configuration helpers"""

from typing import Dict
from ..config import get_chain_config


def get_container_name(chain_name: str) -> str:
    """Get Docker container name for a chain"""
    return f"{chain_name}-validator"


def get_daemon_home(chain_name: str) -> str:
    """Get daemon home directory for a chain"""
    config = get_chain_config(chain_name)
    return config.get('daemon_home', f"/root/.{chain_name}")


def get_binary_name(chain_name: str) -> str:
    """Get binary name for a chain"""
    config = get_chain_config(chain_name)
    return config.get('binary_name', chain_name)


def get_rpc_port(chain_name: str) -> int:
    """Get RPC port for a chain"""
    config = get_chain_config(chain_name)
    ports = config.get('ports', {})
    return ports.get('rpc', 26657)


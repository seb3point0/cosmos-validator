"""Input validation utilities"""

from typing import List
from ..config import load_chains_config
from ..utils.errors import ChainNotFoundError


def validate_chain_name(chain_name: str) -> str:
    """Validate and return chain name, raising error if not found"""
    chains_config = load_chains_config()
    chains = chains_config.get('chains', {})
    
    if chain_name not in chains:
        available = ', '.join(sorted(chains.keys()))
        raise ChainNotFoundError(
            f"Chain '{chain_name}' not found in chains.yaml. "
            f"Available chains: {available}"
        )
    
    return chain_name


def get_available_chains() -> List[str]:
    """Get list of available chain names"""
    chains_config = load_chains_config()
    chains = chains_config.get('chains', {})
    return sorted(chains.keys())


"""Custom exceptions for the Validay CLI"""


class ValidatorError(Exception):
    """Base exception for Validay CLI"""
    pass


class ChainNotFoundError(ValidatorError):
    """Chain not found in configuration"""
    pass


class ContainerNotRunningError(ValidatorError):
    """Container is not running"""
    pass


class ConfigError(ValidatorError):
    """Configuration error"""
    pass


class DockerError(ValidatorError):
    """Docker operation error"""
    pass


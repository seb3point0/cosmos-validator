"""Unified output formatting with colors"""

import sys
from typing import Optional, List, Tuple


class Colors:
    """ANSI color codes"""
    RESET = '\033[0m'
    BOLD = '\033[1m'
    
    # Text colors
    BLACK = '\033[30m'
    RED = '\033[31m'
    GREEN = '\033[32m'
    YELLOW = '\033[33m'
    BLUE = '\033[34m'
    MAGENTA = '\033[35m'
    CYAN = '\033[36m'
    WHITE = '\033[37m'
    
    # Bright colors
    BRIGHT_BLACK = '\033[90m'
    BRIGHT_RED = '\033[91m'
    BRIGHT_GREEN = '\033[92m'
    BRIGHT_YELLOW = '\033[93m'
    BRIGHT_BLUE = '\033[94m'
    BRIGHT_MAGENTA = '\033[95m'
    BRIGHT_CYAN = '\033[96m'
    BRIGHT_WHITE = '\033[97m'


def _supports_color() -> bool:
    """Check if terminal supports colors"""
    if not sys.stdout.isatty():
        return False
    # Check if we're in a terminal that supports colors
    try:
        import os
        term = os.environ.get('TERM', '')
        return term != 'dumb' and 'NO_COLOR' not in os.environ
    except:
        return False


def _colorize(text: str, color: str) -> str:
    """Apply color to text if terminal supports it"""
    if _supports_color():
        return f"{color}{text}{Colors.RESET}"
    return text


def success(message: str):
    """Print success message"""
    print(_colorize(f"[SUCCESS] {message}", Colors.GREEN))


def error(message: str):
    """Print error message"""
    print(_colorize(f"[ERROR] {message}", Colors.RED), file=sys.stderr)


def warning(message: str):
    """Print warning message"""
    print(_colorize(f"[WARNING] {message}", Colors.YELLOW))


def info(message: str):
    """Print info message"""
    print(_colorize(f"[INFO] {message}", Colors.BLUE))


def print_table(headers: List[str], rows: List[List[str]], max_width: int = 80):
    """Print a formatted table"""
    if not rows:
        return
    
    # Calculate column widths
    num_cols = len(headers)
    col_widths = [len(h) for h in headers]
    
    for row in rows:
        for i, cell in enumerate(row):
            if i < len(col_widths):
                col_widths[i] = max(col_widths[i], len(str(cell)))
    
    # Limit column widths to prevent overflow
    total_width = sum(col_widths) + (num_cols - 1) * 3  # 3 spaces between cols
    if total_width > max_width:
        excess = total_width - max_width
        # Reduce largest columns first
        while excess > 0:
            max_idx = col_widths.index(max(col_widths))
            if col_widths[max_idx] > 10:  # Don't make columns too small
                col_widths[max_idx] -= 1
                excess -= 1
            else:
                break
    
    # Print header
    header_row = "  ".join(h.ljust(col_widths[i]) for i, h in enumerate(headers))
    print(_colorize(header_row, Colors.BOLD))
    print(_colorize("-" * len(header_row), Colors.BRIGHT_BLACK))
    
    # Print rows
    for row in rows:
        row_str = "  ".join(str(cell).ljust(col_widths[i])[:col_widths[i]] 
                           for i, cell in enumerate(row))
        print(row_str)


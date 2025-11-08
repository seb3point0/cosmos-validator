"""Progress indicators and spinners"""

import sys
import time
import threading
from typing import Optional


class Spinner:
    """Simple spinner for short operations"""
    SPINNER_CHARS = ['|', '/', '-', '\\']
    
    def __init__(self, message: str = "Processing..."):
        self.message = message
        self.spinning = False
        self.thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
    
    def _spin(self):
        """Spin animation"""
        i = 0
        while not self._stop_event.is_set():
            char = self.SPINNER_CHARS[i % len(self.SPINNER_CHARS)]
            sys.stdout.write(f"\r{self.message} {char}")
            sys.stdout.flush()
            time.sleep(0.1)
            i += 1
    
    def start(self):
        """Start the spinner"""
        if not sys.stdout.isatty():
            print(self.message)
            return
        
        self.spinning = True
        self._stop_event.clear()
        self.thread = threading.Thread(target=self._spin, daemon=True)
        self.thread.start()
    
    def stop(self, success: bool = True):
        """Stop the spinner"""
        if not sys.stdout.isatty():
            return
        
        if self.spinning:
            self._stop_event.set()
            if self.thread:
                self.thread.join(timeout=0.5)
            # Clear the line
            sys.stdout.write("\r" + " " * (len(self.message) + 2) + "\r")
            sys.stdout.flush()
            self.spinning = False


class ProgressBar:
    """Simple progress bar for long operations"""
    
    def __init__(self, total: int, message: str = "Progress"):
        self.total = total
        self.current = 0
        self.message = message
        self.width = 40
    
    def update(self, value: int):
        """Update progress"""
        self.current = min(value, self.total)
        self._draw()
    
    def increment(self, amount: int = 1):
        """Increment progress"""
        self.update(self.current + amount)
    
    def _draw(self):
        """Draw the progress bar"""
        if not sys.stdout.isatty():
            if self.current % max(1, self.total // 10) == 0:
                print(f"{self.message}: {self.current}/{self.total}")
            return
        
        percent = (self.current / self.total) if self.total > 0 else 0
        filled = int(self.width * percent)
        bar = '█' * filled + '░' * (self.width - filled)
        percent_str = f"{percent * 100:.1f}%"
        
        sys.stdout.write(f"\r{self.message} [{bar}] {percent_str}")
        sys.stdout.flush()
    
    def finish(self):
        """Finish the progress bar"""
        self.update(self.total)
        print()  # New line after completion


def show_progress(message: str, operation, *args, **kwargs):
    """Show spinner while running an operation"""
    spinner = Spinner(message)
    try:
        spinner.start()
        result = operation(*args, **kwargs)
        spinner.stop(success=True)
        return result
    except Exception as e:
        spinner.stop(success=False)
        raise e


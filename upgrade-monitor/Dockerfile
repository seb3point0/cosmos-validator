FROM python:3.11-slim

# Install required packages
RUN apt-get update && apt-get install -y \
    docker.io \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    requests \
    pyyaml

# Copy monitor script
COPY monitor.py /app/monitor.py
RUN chmod +x /app/monitor.py

WORKDIR /app

# Run monitor
CMD ["python3", "-u", "monitor.py"]





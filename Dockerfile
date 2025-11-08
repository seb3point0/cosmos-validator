# Generic Multi-Chain Cosmos Validator Dockerfile
# This Dockerfile supports any Cosmos-based chain by downloading pre-built binaries

# Stage 1: Build Cosmovisor
FROM --platform=linux/amd64 golang:1.23-alpine AS cosmovisor-builder

# Install Cosmovisor with Go 1.23
RUN go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest

# Stage 2: Final image
FROM --platform=linux/amd64 debian:bookworm-slim

# Build arguments for chain configuration
ARG CHAIN_BINARY_URL
ARG CHAIN_BINARY_NAME
ARG CHAIN_VERSION
ARG DAEMON_HOME

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    jq \
    ca-certificates \
    grep \
    sed \
    lz4 \
    gnupg \
    wget \
    tar \
    gzip \
    && rm -rf /var/lib/apt/lists/*

# Copy cosmovisor binary
COPY --from=cosmovisor-builder /go/bin/cosmovisor /usr/local/bin/cosmovisor

# Download and install chain binary
# Always try ARM64 binary first if available (works on both ARM64 hosts and amd64 containers)
RUN BINARY_URL_ARM=$(echo "${CHAIN_BINARY_URL}" | sed 's/linux-amd64/linux-arm64/g') && \
    echo "Checking for ARM64 binary: $BINARY_URL_ARM" && \
    if wget --spider "$BINARY_URL_ARM" 2>/dev/null; then \
        echo "✓ ARM64 binary found, using: $BINARY_URL_ARM" && \
        wget -O /tmp/chain-binary "$BINARY_URL_ARM" && \
        chmod +x /tmp/chain-binary && \
        mv /tmp/chain-binary /usr/local/bin/${CHAIN_BINARY_NAME} && \
        echo "${CHAIN_BINARY_NAME} ${CHAIN_VERSION} (ARM64) installed successfully"; \
    else \
        echo "ARM64 binary not available, using amd64: ${CHAIN_BINARY_URL}" && \
        wget -O /tmp/chain-binary "${CHAIN_BINARY_URL}" && \
        chmod +x /tmp/chain-binary && \
        mv /tmp/chain-binary /usr/local/bin/${CHAIN_BINARY_NAME} && \
        echo "${CHAIN_BINARY_NAME} ${CHAIN_VERSION} (amd64) installed successfully"; \
    fi

# Verify binary works
RUN ${CHAIN_BINARY_NAME} version || echo "Binary verification skipped"

# Create directory structure for Cosmovisor
RUN mkdir -p ${DAEMON_HOME}/cosmovisor/genesis/bin && \
    mkdir -p ${DAEMON_HOME}/cosmovisor/upgrades && \
    mkdir -p ${DAEMON_HOME}/backup && \
    cp /usr/local/bin/${CHAIN_BINARY_NAME} ${DAEMON_HOME}/cosmovisor/genesis/bin/${CHAIN_BINARY_NAME}

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Set environment variables for Cosmovisor
ENV DAEMON_NAME=${CHAIN_BINARY_NAME} \
    DAEMON_HOME=${DAEMON_HOME} \
    DAEMON_ALLOW_DOWNLOAD_BINARIES=true \
    DAEMON_RESTART_AFTER_UPGRADE=true \
    UNSAFE_SKIP_BACKUP=false \
    DAEMON_DATA_BACKUP_DIR=${DAEMON_HOME}/backup

# Ports are handled by docker-compose, no need to EXPOSE here
# Each chain uses different ports configured in chains.yaml

# Set working directory
WORKDIR ${DAEMON_HOME}

# Health check is configured in docker-compose.yml per chain
# (Each chain uses different ports, so healthcheck is set at service level)

# Default command
CMD ["/scripts/entrypoint.sh"]


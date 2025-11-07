FROM golang:1.23-alpine AS cosmovisor-builder

# Install Cosmovisor with Go 1.23
RUN go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@latest

FROM golang:1.23-bookworm AS gaia-builder

# Install dependencies for Gaia
RUN apt-get update && apt-get install -y \
    git \
    make \
    gcc \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Download and build gaiad
WORKDIR /build
ARG GAIA_VERSION=v18.1.0
RUN git clone https://github.com/cosmos/gaia.git && \
    cd gaia && \
    git checkout ${GAIA_VERSION} && \
    make install

# Final stage - use Debian for glibc compatibility (required by wasmvm)
FROM debian:bookworm-slim

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
    && rm -rf /var/lib/apt/lists/*

# Copy binaries from both builders
COPY --from=cosmovisor-builder /go/bin/cosmovisor /usr/local/bin/cosmovisor
COPY --from=gaia-builder /go/bin/gaiad /usr/local/bin/gaiad

# Copy wasmvm library (required by gaiad)
# v25.1.0 uses wasmvm v2.2.4
COPY --from=gaia-builder /go/pkg/mod/github.com/!cosm!wasm/wasmvm/v2@v2.2.4/internal/api/libwasmvm.aarch64.so /usr/lib/libwasmvm.aarch64.so

# Create directory structure
RUN mkdir -p /root/.gaia/cosmovisor/genesis/bin && \
    mkdir -p /root/.gaia/cosmovisor/upgrades && \
    mkdir -p /root/.gaia/backup && \
    cp /usr/local/bin/gaiad /root/.gaia/cosmovisor/genesis/bin/gaiad

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Set environment variables for Cosmovisor
ENV DAEMON_NAME=gaiad \
    DAEMON_HOME=/root/.gaia \
    DAEMON_ALLOW_DOWNLOAD_BINARIES=true \
    DAEMON_RESTART_AFTER_UPGRADE=true \
    UNSAFE_SKIP_BACKUP=false \
    DAEMON_DATA_BACKUP_DIR=/root/.gaia/backup

# Expose ports
# 26656: P2P
# 26657: RPC
# 26660: Prometheus metrics
# 1317: API
# 9090: gRPC
EXPOSE 26656 26657 26660 1317 9090

# Set working directory
WORKDIR /root/.gaia

# Default command
CMD ["/scripts/entrypoint.sh"]

FROM python:3.9.16-slim-bullseye

ARG GCLOUDSDK_DOWNLOAD_URL="https://storage.googleapis.com/cloud-sdk-release/google-cloud-sdk-521.0.0-linux-x86_64.tar.gz"
ARG WATCHMAN_DEB_URL="http://ftp.us.debian.org/debian/pool/main/w/watchman/watchman_4.9.0-5+b1_amd64.deb"

# Create a non-root user and group
RUN groupadd -r appuser && useradd -r -g appuser -m -s /bin/bash appuser

# Set environment variables
ENV PATH="${PATH}:/usr/local/go/bin"
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies, Google Cloud SDK and kubectl
# - Use && to chain commands and reduce layers
# - Clean up apt cache in the same layer to keep the image smaller
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gnupg2=2.2.27-2+deb11u2 \
        lsb-release \
        apt-transport-https \
        git \
        curl \
        jq \
        wget \
        graphviz \
        dumb-init \
        build-essential \
        python-dev \
        automake \
        autoconf \
        libtool \
        libssl-dev \
        pkg-config && \
    # Install GCloud SDK
    wget -q ${GCLOUDSDK_DOWNLOAD_URL} && \
    tar -zxf $(basename ${GCLOUDSDK_DOWNLOAD_URL}) -C /usr/local/ && \
    ln --symbolic --force /usr/local/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud && \
    ln --symbolic --force /usr/local/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil && \
    rm $(basename ${GCLOUDSDK_DOWNLOAD_URL}) && \
    # Install kubectl
    export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y --no-install-recommends kubectl && \
    # Install Go
    wget -q https://golang.org/dl/go1.24.3.linux-amd64.tar.gz && \
    tar -C /usr/local -xf go1.24.3.linux-amd64.tar.gz && \
    rm go1.24.3.linux-amd64.tar.gz && \
    # Clean up
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create app directories with proper permissions
RUN mkdir -p /code /scripts /entrypoint.d && \
    chown -R appuser:appuser /code /scripts /entrypoint.d

# Copy requirements first for better layer caching
COPY --chown=appuser:appuser ./requirements.txt /code/requirements.txt
WORKDIR /code

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY --chown=appuser:appuser ./scripts /scripts
COPY --chown=appuser:appuser ./entrypoints /entrypoint.d
COPY --chown=appuser:appuser . /code

# Build Go application
WORKDIR /code/check_libp2p
RUN go mod download && \
    go build && \
    chown -R appuser:appuser .

# Set proper permissions on scripts (avoiding 777)
RUN chmod -R 755 /scripts/ /entrypoint.d/ && \
    chmod +x /scripts/entrypoint.sh

# Switch to non-root user
USER appuser
WORKDIR /code

# Use dumb-init as the entry point to handle signals properly
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/scripts/entrypoint.sh"]
CMD ["bash", "main.sh"]

FROM ubuntu:18.04

# Run with `docker build --build-arg mina_deb_version=<version>`
ARG mina_deb_version
ARG deb_repo=stable

ENV DEBIAN_FRONTEND noninteractive
RUN echo "Building image with version $mina_deb_version"

# Dependencies
RUN apt-get -y update && \
  DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install \
    curl \
    jq \
    strace \
    dumb-init \
    libssl1.1 \
    libprocps6 \
    libgmp10 \
    libgomp1 \
    libffi6 \
    apt-transport-https \
    ca-certificates \
    dnsutils \
    tzdata \
    postgresql && \
  rm -rf /var/lib/apt/lists/*

RUN mkdir /healthcheck && curl https://raw.githubusercontent.com/MinaProtocol/mina/develop/dockerfiles/scripts/healthcheck-utilities.sh -o /healthcheck/utilities.sh

# archive-node package
RUN echo "deb [trusted=yes] http://packages.o1test.net $deb_repo main" > /etc/apt/sources.list.d/o1.list \
  && apt-get -y update \
  && apt-get install -y "mina-archive=$mina_deb_version"

FROM ubuntu:18.04

ARG coda_deb_version
ARG deb_repo=stable

# archive-node package
RUN echo "deb [trusted=yes] http://packages.o1test.net $deb_repo main" > /etc/apt/sources.list.d/coda.list \
  && apt-get update \
  && apt-get install -y "archive=$coda_deb_version"



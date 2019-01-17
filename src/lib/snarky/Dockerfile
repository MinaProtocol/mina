# Creates an environment for building both snarky 
# and things that use snarky.

FROM debian:stretch-slim

# Recent version.
ARG OCAML_VERSION=4.07.1

# Install the libsnark dependencies and a bootstrap OCaml environment.
RUN apt-get -q update && \
    apt-get -q -y install \
        build-essential=12.3 \
        cmake=3.7.2-1 \
        git=1:2.11.0-3+deb9u4 \
        libboost-dev=1.62.0.1 \
        libboost-program-options-dev=1.62.0.1 \
        libffi-dev=3.2.1-6 \
        libgmp-dev=2:6.1.2+dfsg-1 \
        libgmp3-dev=2:6.1.2+dfsg-1 \
        libprocps-dev=2:3.3.12-3+deb9u1 \
        libssl-dev=1.1.0j-1~deb9u1 \
        m4=1.4.18-1 \
        nano=2.7.4-1 \
        ocaml=4.02.3-9 \
        opam=1.2.2-5+b7 \
        pkg-config=0.29-4+b1 \
        python-markdown=2.6.8-1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# We want to drop root! First, add a user to be and create a homedir.
RUN useradd snarky -m

# Create a volume we can work in. For initial build, 
# we'll copy the local context. To update the snarky 
# library itself later, bind mount your updated source 
# over this and run the build again.
COPY . /source
RUN chown -R snarky:snarky /source
VOLUME ["/source"]

# Be the new user before initializing OPAM.
USER snarky

# Move to a newer version of OCaml and install dune/jbuilder.
RUN opam init -y && \
    opam switch $OCAML_VERSION && \
    opam install dune

WORKDIR /source

# Pin and install the dependencies.
RUN eval `opam config env` && \
    opam pin add -y interval_union .

RUN eval `opam config env` && \
    opam pin add -y bitstring_lib .

RUN eval `opam config env` && \
    opam pin add -y snarky .

# Docker inception
COPY Dockerfile /

# Use a slight hack to always have the current OCaml environment.
CMD ["/bin/bash", "--init-file", "/home/snarky/.opam/opam-init/init.sh"]

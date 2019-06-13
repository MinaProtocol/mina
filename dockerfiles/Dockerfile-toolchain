FROM ocaml/opam2:debian-9-ocaml-4.07

# OS package dependencies
RUN sudo apt-get update && sudo apt-get install --yes \
    cmake \
    jq \
    libboost-dev \
    libboost-program-options-dev \
    libffi-dev \
    libgmp-dev \
    libgmp3-dev \
    libprocps-dev \
    libsodium-dev \
    libssl-dev \
    lsb \
    m4 \
    pandoc \
    patchelf \
    python \
    perl \
    pkg-config \
    python-jinja2 \
    rubygems \
    zlib1g-dev \
    libbz2-dev

RUN sudo gem install deb-s3

# Google Cloud tools
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - && \
    sudo apt-get update -y && sudo apt-get install google-cloud-sdk -y

# Source copy of rocksdb
RUN sudo git clone https://github.com/facebook/rocksdb -b v5.17.2 /rocksdb
# This builds and installs just the static lib for us
RUN cd /rocksdb && sudo make static_lib PORTABLE=1 -j$(nproc) && sudo cp librocksdb.a /usr/local/lib/librocksdb_coda.a && sudo rm -rf /rocksdb && sudo strip -S /usr/local/lib/librocksdb_coda.a

# Opam dependencies
# Pull freshest repository
RUN git -C /home/opam/opam-repository pull
RUN opam update -y && opam upgrade -y

# Install other OPAM packages
ADD /src/opam.export .
RUN opam switch import opam.export ; rm opam.export

# Source copy of ocaml-sodium (modified for static linking)
ADD /src/external/ocaml-sodium /ocaml-sodium
RUN cd /ocaml-sodium && yes | opam pin add .

# Source copy of rpc_parallel (modified for macOS support)
ADD /src/external/rpc_parallel /rpc_parallel
RUN sudo rm -rf /rpc_parallel/.git && cd /rpc_parallel && yes | opam pin add .

# Source copy of ocaml-extlib (modified to remove module name conflict)
ADD /src/external/ocaml-extlib /ocaml-extlib
RUN sudo rm -rf /ocaml-extlib/.git && cd /ocaml-extlib && yes | opam pin add .

# Source copy of digestif (modified to support unpadded SHA256)
ADD /src/external/digestif /digestif
RUN sudo rm -rf /digestif/.git && cd /digestif && yes | opam pin add .

ADD /src/external/async_kernel /async_kernel
RUN sudo rm -rf /async_kernel/.git && cd /async_kernel && yes | opam pin add .

# Source copy of mransan version of base58 (OPAM repo has two versions with different APIs)
ADD /src/external/coda_base58 /coda_base58
RUN sudo rm -rf /coda_base58/.git && cd /coda_base58 && yes | opam pin add .

# Get coda-kademlia from packages repo
RUN sudo apt-get install --yes apt-transport-https ca-certificates && \
      echo "deb [trusted=yes] https://packages.o1test.net unstable main" | sudo tee -a /etc/apt/sources.list.d/coda.list && \
      sudo apt-get update && \
      sudo apt-get install --yes coda-kademlia

# The Ocaml images are set to London time for reason. UTC makes reading the logs
# easier.
RUN sudo ln -sf /usr/share/zoneinfo/UTC /etc/localtime

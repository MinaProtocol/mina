FROM python:3.7-slim-stretch

ARG GCLOUDSDK_DOWNLOAD_URL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-296.0.1-linux-x86_64.tar.gz"
ARG WATCHMAN_DEB_URL="http://ftp.us.debian.org/debian/pool/main/w/watchman/watchman_4.9.0-5+b1_amd64.deb"

RUN apt update && apt install -y \
    gnupg2 lsb-core apt-transport-https git curl jq wget \
    graphviz dumb-init build-essential python-dev automake autoconf libtool \
    libssl-dev pkg-config

# Install GCloud SDK
RUN wget ${GCLOUDSDK_DOWNLOAD_URL} && tar -zxf $(basename ${GCLOUDSDK_DOWNLOAD_URL}) -C /usr/local/
RUN ln --symbolic --force /usr/local/google-cloud-sdk/bin/gcloud /usr/local/bin/gcloud
RUN ln --symbolic --force /usr/local/google-cloud-sdk/bin/gsutil /usr/local/bin/gsutil

# Install K8s/network utilities
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" \
    | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN apt update && apt install -y kubectl

# Install Watchman utility
RUN cd /tmp && git clone https://github.com/facebook/watchman.git -b v4.9.0 --depth 1

WORKDIR /tmp/watchman

RUN ./autogen.sh && ./configure --enable-statedir=/tmp
RUN make && make install && mv watchman /usr/local/bin/watchman

WORKDIR /root

RUN wget https://golang.org/dl/go1.15.7.linux-amd64.tar.gz
RUN tar -C /usr/local -xf go1.15.7.linux-amd64.tar.gz
ENV PATH="${PATH}:/usr/local/go/bin"

ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache

COPY . /code
COPY ./scripts /scripts

WORKDIR /code/check_libp2p
RUN go mod download
RUN go build


# TODO: find better mechanism for sharing files across repo DIRs
ADD https://raw.githubusercontent.com/MinaProtocol/mina/develop/automation/scripts/random_restart.py /scripts/random_restart.py

COPY ./entrypoints /entrypoint.d

RUN chmod -R 777 /code/ /scripts/

COPY ./requirements.txt requirements.txt
RUN pip install -r requirements.txt

WORKDIR /code

ENTRYPOINT ["/scripts/entrypoint.sh"]

CMD [ "bash", "main.sh" ]

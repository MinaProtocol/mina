FROM debian:stretch


RUN apt-get update
RUN apt-get install -y apt-transport-https ca-certificates
RUN echo "deb [trusted=yes] http://packages.o1test.net unstable main" | tee /etc/apt/sources.list.d/coda.list

RUN apt-get update

RUN apt-get install -y curl coda-testnet-postake-medium-curves=0.0.16-beta7+-feature-mainnet-parameter-test-d020cb4-PV84ecd12e

RUN apt-get install -y graphviz

ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache

COPY ./daemon.json /config/daemon.json

CMD [ "/bin/bash", "" ]

# The the base image from which we should build this image
ARG base_image_tag
FROM codaprotocol/coda-daemon:$base_image_tag

RUN apt-get -y update && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install \
    python3-pip \ 
    jq \
    tzdata

RUN pip3 install awscli

RUN mkdir /wallet-keys && chmod 700 /wallet-keys

WORKDIR /code
ADD entrypoint.sh entrypoint.sh 
RUN chmod +x entrypoint.sh

ENTRYPOINT ["bash", "entrypoint.sh"]

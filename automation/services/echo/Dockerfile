FROM node:10

WORKDIR /code

RUN apt-get -y update && \
  DEBIAN_FRONTEND=noninteractive apt-get -y upgrade && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install \
    dumb-init

COPY package.json ./
COPY yarn.lock ./

RUN yarn

COPY index.js /code/index.js
COPY logger.js /code/logger.js

CMD ["/usr/bin/dumb-init", "node", "index.js"]

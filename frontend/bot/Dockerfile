FROM node:12.9.0-stretch-slim

ADD https://raw.githubusercontent.com/MinaProtocol/mina/develop/dockerfiles/scripts/healthcheck-utilities.sh /healthcheck/utilities.sh

WORKDIR /code

COPY package.json yarn.lock ./

RUN yarn && \
    yarn cache clean

COPY bsconfig.json graphql_schema.json ./
COPY ./src ./src

RUN yarn build-without-copy


ENV MINA_GRAPHQL_HOST=localhost
ENV MINA_GRAPHQL_PORT=8304

ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

ENTRYPOINT ["bash", "-c"]
CMD ["dockerize -wait tcp://$MINA_GRAPHQL_HOST:$MINA_GRAPHQL_PORT -timeout 90s && yarn start" ]

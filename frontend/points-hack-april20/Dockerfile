FROM node:12.9.0-stretch-slim

WORKDIR /app

COPY package.json .
COPY yarn.lock .

RUN yarn install && yarn cache clean

COPY lib.js .

ENV MINA_GRAPHQL_HOST=localhost
ENV MINA_GRAPHQL_PORT=3085

ENV GOOGLE_CLOUD_STORAGE_API_KEY=

ENV DOCKERIZE_VERSION v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

ENTRYPOINT ["bash", "-c"]
CMD ["dockerize -wait tcp://$MINA_GRAPHQL_HOST:$MINA_GRAPHQL_PORT -timeout 90s && node lib.js" ]


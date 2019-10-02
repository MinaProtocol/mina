FROM node:12.9.0-stretch-slim

WORKDIR /code

COPY package.json yarn.lock ./

RUN yarn && \
    yarn cache clean

COPY graphql_schema.json bsconfig.json ./
COPY ./src ./src

RUN yarn build-without-copy


ENV CODA_GRAPHQL_HOST=localhost
ENV CODA_GRAPHQL_PORT=8304
ADD wait-for-it.sh wait-for-it.sh

ENTRYPOINT ["bash", "-c"]
CMD ["./wait-for-it.sh --host=$CODA_GRAPHQL_HOST --port=$CODA_GRAPHQL_PORT --timeout=90 --strict -- yarn start" ]

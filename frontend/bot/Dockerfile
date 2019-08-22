FROM node:12.9.0-stretch-slim

COPY package.json yarn.lock ./

RUN yarn && \
    yarn cache clean

COPY ./graphql_schema.json bsconfig.json ./
COPY ./src ./src

RUN yarn build-without-copy

ENTRYPOINT ["yarn", "start" ]

FROM node:12.9.0-stretch-slim

WORKDIR /code

COPY package.json yarn.lock ./

RUN yarn && \
    yarn cache clean

COPY bsconfig.json ./
COPY __tests__ ./__tests__
COPY ./src ./src

RUN yarn build

ENV SPREADSHEET_ID=1dkHatzBcaN_5rb3sQEDIcwdh0qTc_9t7pHGAVfdHACY

ENTRYPOINT ["bash", "-c"]
CMD ["node lib/js/src/Main.bs.js"]
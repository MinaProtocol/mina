FROM node:12

WORKDIR /app

COPY package.json .
COPY yarn.lock .
COPY lib.js .

RUN yarn install

CMD [ "node", "lib.js" ]


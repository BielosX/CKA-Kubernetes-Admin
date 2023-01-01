FROM node:19-alpine3.16

WORKDIR /app

COPY build/* /app
COPY package.json /app
COPY yarn.lock /app
RUN yarn install

CMD ["node", "main.js"]
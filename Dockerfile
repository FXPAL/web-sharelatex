FROM node:6.15.1 as app

WORKDIR /app

#wildcard as some files may not be in all repos
COPY package.json npm-shrinkwrap.json /app/

RUN npm install --quiet

RUN npm run linit
RUN npm run format

COPY . /app

RUN make compile_full

FROM node:6.15.1

COPY --from=app /app /app

WORKDIR /app
RUN chmod 0755 ./install_deps.sh && ./install_deps.sh
USER node

CMD ["node", "--expose-gc", "app.js"]

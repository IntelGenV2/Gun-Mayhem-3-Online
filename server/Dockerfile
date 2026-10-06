FROM node:22-alpine
WORKDIR /app
COPY server.mjs package.json ./
USER node
EXPOSE 47633/tcp
CMD ["node", "server.mjs"]

FROM node:22-alpine
WORKDIR /app
# Set ownership to node user
COPY --chown=1000:1000 package.json .
RUN npm install
COPY --chown=1000:1000 server.js .
USER 1000
CMD ["node", "server.js"]

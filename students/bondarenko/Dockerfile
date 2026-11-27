FROM node:24-alpine AS verify
WORKDIR /app
COPY src/ ./src/
COPY test/ ./test/
RUN node --test

FROM node:24-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production PORT=3000
COPY --from=verify --chown=node:node /app/src/ ./src/
USER node
EXPOSE 3000
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=5 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.PORT || 3000)+'/healthz').then(r=>{if(!r.ok) process.exit(1)}).catch(()=>process.exit(1))"]
CMD ["node", "src/server.mjs"]

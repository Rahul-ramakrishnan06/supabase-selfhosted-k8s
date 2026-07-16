# Reproducible, non-root image for the chat backend.
FROM node:22-alpine

ENV NODE_ENV=production
WORKDIR /app

# Install deps first for layer caching. Use the lockfile for reproducibility.
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY server.js ./
COPY public ./public

# Drop root (node:alpine ships an unprivileged "node" user).
USER node

EXPOSE 8080
CMD ["node", "server.js"]

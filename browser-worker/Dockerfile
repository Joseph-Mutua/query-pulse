FROM mcr.microsoft.com/playwright:v1.52.0-noble
WORKDIR /worker
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
ENV NODE_ENV=production PORT=3100
EXPOSE 3100
CMD ["node", "dist/server.js"]

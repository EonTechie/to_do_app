FROM node:18-alpine
WORKDIR /app
COPY . .
RUN ls node_modules || npm install
EXPOSE 4000
CMD ["npm", "start"]

# Stage 1: Build React App
FROM node:18 AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy build output to Nginx HTML folder
COPY --from=builder /app/build /usr/share/nginx/html

# Expose frontend port
EXPOSE 3000

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]


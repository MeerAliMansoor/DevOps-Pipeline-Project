# Stage 1: Build
FROM node:18 AS builder

WORKDIR /app

# Copy dependency files and install
COPY package*.json ./
RUN npm install

# Copy rest of the source and build
COPY . .
RUN npm run build

# Stage 2: Production Image
FROM node:18-alpine

WORKDIR /app

# Copy only build artifacts and necessary files
COPY --from=builder /app/dist ./dist
COPY package*.json ./

RUN npm install --only=production

# Expose backend port
EXPOSE 5000

# Start the backend app
CMD ["npm", "run", "start:prod"]


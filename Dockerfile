# Use the official Node.js 14 image
FROM node:14

# Set the working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the application files
COPY . .

# Build the React frontend
RUN npm run build

# Expose the port the app runs on
EXPOSE 3000

# Start the server
CMD ["npm", "start"]

# Make sure there is no volume mount for the container in docker compose yaml file
FROM node:23-alpine3.20 AS builder

WORKDIR /app

# install build tools, some packages will require it, in this case bcrypt require it to build from source.
RUN apk add --no-cache python3 make g++

COPY package*.json ./

RUN npm install

COPY src ./src

COPY tsconfig.json .swcrc* ./ 

RUN npx prisma generate

RUN npm run build


# ---- Stage 2: Create the production image ----
FROM node:23-alpine3.20 AS production

WORKDIR /app

ENV NODE_ENV=production

# Create a non-root user and group for security
# Using -S for system user/group, -D to not assign a password
RUN addgroup -S appgroup && adduser -S -D -G appgroup appuser

COPY package*.json ./

# Install only production dependencies using npm ci
# `npm ci` is generally preferred for production as it's faster and more reliable.
# It strictly uses package-lock.json.
# --omit=dev ensures devDependencies are not installed.
# --ignore-scripts can be useful if some postinstall scripts (like prisma generate)
# are not needed or would fail in this minimal environment. We copy the pre-generated client.
RUN npm ci --omit=dev --ignore-scripts

# Copy the built application from the builder stage
# Ensure ownership is set to the non-root user
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist

# Copy bcrypt from builder stage
COPY --from=builder --chown=appuser:appgroup /app/node_modules/bcrypt ./node_modules/bcrypt
# Copy the generated Prisma client from the builder stage
# Prisma client is typically generated into node_modules/@prisma/client
# Ensure this path is correct for your setup.
COPY --from=builder --chown=appuser:appgroup /app/node_modules/@prisma/client ./node_modules/@prisma/client
# If your Prisma client is generated into node_modules/.prisma/client (older versions/custom config):
COPY --from=builder --chown=appuser:appgroup /app/node_modules/.prisma ./node_modules/.prisma

# If you have other static assets (e.g., a 'public' folder) that are served
# and not part of the 'dist' build, copy them here:
# COPY --chown=appuser:appgroup public ./public

# Switch to the non-root user
USER appuser


# Command to run the application
CMD ["npm", "run", "start"]

# Test issues
# CMD ["node", "-e", "console.log('[NODE CMD TEST 2] Attempting to require dist/src/server.js...'); try { require('./dist/src/server.js'); console.log('[NODE CMD TEST 2] Successfully required dist/src/server.js.'); } catch (e) { console.error('[NODE CMD TEST 2] ERROR REQUIRING SCRIPT:', e); process.exit(1); } process.exit(0);"]

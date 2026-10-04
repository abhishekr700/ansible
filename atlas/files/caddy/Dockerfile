# Stage 1: Build the custom Caddy binary
# We use the official 'builder' image which contains Go and xcaddy
FROM caddy:2.10-builder AS builder

# Use xcaddy to build Caddy with the Cloudflare DNS module
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare

# Stage 2: Create the final, lean image
# Start from the official Caddy image
FROM caddy:2.10

# Copy our custom-built Caddy binary from the 'builder' stage
# This replaces the standard Caddy binary in the final image
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

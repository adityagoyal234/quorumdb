# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /quorumdb ./cmd/quorumdb

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user
RUN addgroup -g 1000 quorumdb && \
    adduser -u 1000 -G quorumdb -s /bin/sh -D quorumdb

# Create data directory
RUN mkdir -p /data && chown quorumdb:quorumdb /data

# Copy binary from builder
COPY --from=builder /quorumdb /usr/local/bin/quorumdb

# Switch to non-root user
USER quorumdb

# Set default environment variables
ENV QUORUMDB_ADDRESS=0.0.0.0
ENV QUORUMDB_PORT=8080
ENV QUORUMDB_GOSSIP_PORT=7946
ENV QUORUMDB_DATA_DIR=/data

# Expose ports
EXPOSE 8080 7946/udp

# Health check
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:8080/health || exit 1

# Default command
ENTRYPOINT ["/usr/local/bin/quorumdb"]
CMD ["--address=0.0.0.0", "--port=8080", "--data-dir=/data"]


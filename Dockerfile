# Stage 1: Build the binary from local source
FROM golang:1.24-alpine AS builder
RUN apk add --no-cache git

# Copy local source code into the container
COPY source/ /go/src/snowflake
WORKDIR /go/src/snowflake/proxy

# Build the binary
RUN go build -o /snowflake-proxy .

# Stage 2: Create the minimal runtime image
FROM alpine:3.19
# busybox-extras adds the httpd applet (not in the default busybox build) --
# used below to serve the stats dashboard. Still no Node/Python/etc: this is
# a small (~200KB) sibling of the busybox binary already in the base image.
RUN apk add --no-cache ca-certificates busybox-extras

# Copy the binary from the builder
COPY --from=builder /snowflake-proxy /usr/bin/snowflake-proxy
COPY docker_entrypoint.sh /docker_entrypoint.sh
RUN chmod +x /docker_entrypoint.sh

# Dependency-free stats dashboard: runs the proxy + a busybox httpd serving
# a small status page generated from the proxy's own log output. Nothing
# extra installed here -- busybox (sh, awk, grep, sed, date, tee, httpd) is
# already part of this alpine base image.
COPY scripts/dashboard.sh /usr/local/bin/dashboard.sh
RUN chmod +x /usr/local/bin/dashboard.sh

ENTRYPOINT ["/docker_entrypoint.sh"]

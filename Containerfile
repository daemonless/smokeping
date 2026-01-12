ARG BASE_VERSION=15
FROM ghcr.io/daemonless/nginx-base:${BASE_VERSION}

ARG FREEBSD_ARCH=amd64
ARG PKG_NAME=smokeping
ARG HEALTHCHECK_ENDPOINT="http://localhost:80/daemonless-ping"

ENV HEALTHCHECK_URL="${HEALTHCHECK_ENDPOINT}"

# --- Metadata (Injected by Generator) ---
LABEL org.opencontainers.image.title="SmokePing" \
      org.opencontainers.image.description="SmokePing network latency monitor on FreeBSD." \
      org.opencontainers.image.source="https://github.com/daemonless/smokeping" \
      org.opencontainers.image.url="https://oss.oetiker.ch/smokeping/" \
      org.opencontainers.image.documentation="https://oss.oetiker.ch/smokeping/doc/smokeping.en.html" \
      org.opencontainers.image.licenses="GPL-2.0-or-later" \
      org.opencontainers.image.vendor="daemonless" \
      org.opencontainers.image.authors="daemonless" \
      io.daemonless.category="Utilities" \
      io.daemonless.port="80" \
      io.daemonless.volumes="/config,/data" \
      io.daemonless.arch="${FREEBSD_ARCH}" \
      io.daemonless.pkg-name="${PKG_NAME}" \
      io.daemonless.healthcheck-url="${HEALTHCHECK_ENDPOINT}"

# Install from FreeBSD packages
RUN pkg update && \
    pkg install -y ${PKG_NAME} fcgiwrap spawn-fcgi && \
    SMOKEPING_VERSION=$(pkg info ${PKG_NAME} | sed -n 's/.*Version.*: *//p') && \
    mkdir -p /app && echo "$SMOKEPING_VERSION" > /app/version && \
    pkg clean -ay && \
    rm -rf /var/cache/pkg/* /var/db/pkg/repos/*

# Create required directories with proper permissions for traversal
RUN mkdir -p /var/lib/smokeping/data /var/lib/smokeping/images \
             /var/run/smokeping /var/log/smokeping /data && \
    chmod 755 /var/lib /var/lib/smokeping /var/lib/smokeping/data /var/lib/smokeping/images /data && \
    chown -R bsd:bsd /var/lib/smokeping /var/run/smokeping /var/log/smokeping /data && \
    # Create symlink for source-build path compatibility
    mkdir -p /usr/local/smokeping && \
    ln -sf /usr/local/etc/smokeping /usr/local/smokeping/etc

# Copy configuration and service scripts
COPY root/ /

# Use pkg service script
RUN cp /etc/services.d/smokeping/run.pkg /etc/services.d/smokeping/run 2>/dev/null || true

# Make scripts executable
RUN chmod +x /etc/cont-init.d/* /etc/services.d/*/run 2>/dev/null || true

# Set up s6 service links for smokeping and fcgiwrap
RUN mkdir -p /run/s6/services/smokeping /run/s6/services/fcgiwrap && \
    ln -sf /etc/services.d/smokeping/run /run/s6/services/smokeping/run && \
    ln -sf /etc/services.d/fcgiwrap/run /run/s6/services/fcgiwrap/run

# --- Expose (Injected by Generator) ---
EXPOSE 80

# --- Volumes (Injected by Generator) ---
VOLUME /config /data
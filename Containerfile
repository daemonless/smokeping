ARG BASE_VERSION=15
FROM ghcr.io/daemonless/nginx-base:${BASE_VERSION}

ARG FREEBSD_ARCH=amd64
ARG PACKAGES="gmake autoconf automake gawk perl5 p5-CGI p5-CGI-Fast p5-CGI-Session p5-FCGI p5-Config-Grammar p5-Digest-HMAC p5-IO-Pty-Easy p5-IO-Socket-SSL p5-libwww p5-LWP-Protocol-https p5-Net-DNS p5-Net-OpenSSH p5-Net-SNMP p5-Net-Telnet p5-perl-ldap p5-SNMP_Session p5-Socket6 rrdtool fping fcgiwrap spawn-fcgi"
LABEL org.opencontainers.image.title="SmokePing" \
    org.opencontainers.image.description="SmokePing network latency monitor on FreeBSD" \
    org.opencontainers.image.source="https://github.com/daemonless/smokeping" \
    org.opencontainers.image.url="https://oss.oetiker.ch/smokeping/" \
    org.opencontainers.image.documentation="https://oss.oetiker.ch/smokeping/doc/smokeping.en.html" \
    org.opencontainers.image.licenses="GPL-2.0-or-later" \
    org.opencontainers.image.vendor="daemonless" \
    org.opencontainers.image.authors="daemonless" \
    io.daemonless.port="80" \
    io.daemonless.arch="${FREEBSD_ARCH}" \
    io.daemonless.base="nginx" \
    io.daemonless.category="Utilities" \
    io.daemonless.upstream-mode="source" \
    io.daemonless.packages="${PACKAGES}"

# Install build tools and all perl dependencies
# This avoids smokeping trying to install modules via CPAN
RUN pkg update && \
    pkg install -y \
    ${PACKAGES} && \
    pkg clean -ay && \
    rm -rf /var/cache/pkg/* /var/db/pkg/repos/*

# Download and build SmokePing from source
RUN SMOKEPING_TAG=$(fetch -qo - "https://api.github.com/repos/oetiker/SmokePing/releases/latest" | \
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p') && \
    SMOKEPING_VERSION=$(echo "$SMOKEPING_TAG" | sed 's/^v//') && \
    mkdir -p /app && echo "${SMOKEPING_VERSION}" > /app/version && \
    ln -sf /usr/local/bin/gmake /usr/local/bin/make && \
    fetch -o /tmp/smokeping.tar.gz "https://github.com/oetiker/SmokePing/releases/download/${SMOKEPING_TAG}/smokeping-${SMOKEPING_VERSION}.tar.gz" && \
    cd /tmp && \
    tar -xzf smokeping.tar.gz && \
    cd smokeping-${SMOKEPING_VERSION} && \
    PERL5LIB=$(perl -e 'print join(":", grep { /site_perl/ } @INC)') ./configure --prefix=/usr/local/smokeping && \
    # Patch Makefile to skip thirdparty (like FreeBSD port does)
    sed -i '' 's/SUBDIRS = lib thirdparty/SUBDIRS = lib/' Makefile && \
    gmake install && \
    # Fix permissions so bsd user can read libs
    chmod -R o+rX /usr/local/smokeping && \
    # Copy .dist files to non-.dist names
    cd /usr/local/smokeping/etc && \
    cp smokemail.dist smokemail && \
    cp tmail.dist tmail && \
    cp basepage.html.dist basepage.html && \
    # Create symlink for nginx config compatibility
    ln -sf /usr/local/smokeping/bin/smokeping_cgi /usr/local/bin/smokeping_cgi && \
    cd / && \
    rm -rf /tmp/smokeping*

# Create smokeping user/group (UID 295 matches FreeBSD port)

# Create required directories
RUN mkdir -p /var/lib/smokeping/data /var/lib/smokeping/images \
    /var/run/smokeping /var/log/smokeping && \
    chown -R bsd:bsd /var/lib/smokeping /var/run/smokeping /var/log/smokeping

# Copy configuration and service scripts
COPY root/ /

# Make scripts executable (use source build run script, not run.pkg)
RUN chmod +x /etc/cont-init.d/* /etc/services.d/*/run 2>/dev/null || true

# Set up s6 service links for smokeping and fcgiwrap

EXPOSE 80

VOLUME ["/config"]







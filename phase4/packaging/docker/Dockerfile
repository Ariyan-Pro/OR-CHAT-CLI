FROM alpine:3.18

# Install dependencies
RUN apk add --no-cache \
    bash \
    python3 \
    jq \
    curl \
    && python3 -m ensurepip \
    && pip3 install --no-cache --upgrade pip setuptools

# Create non-root user
RUN adduser -D -u 1000 orchat

# Create directory structure
RUN mkdir -p /app /config /sessions \
    && chown -R orchat:orchat /app /config /sessions

# Install ORCHAT
COPY --chown=orchat:orchat bin/orchat /app/bin/
COPY --chown=orchat:orchat src/ /app/src/
COPY --chown=orchat:orchat config/orchat.toml /app/config/orchat.toml.dist

# Create entrypoint script
RUN echo '#!/bin/bash' > /app/entrypoint.sh \
    && echo 'set -e' >> /app/entrypoint.sh \
    && echo '' >> /app/entrypoint.sh \
    && echo '# Copy default config if not exists' >> /app/entrypoint.sh \
    && echo 'if [ ! -f /config/orchat.toml ]; then' >> /app/entrypoint.sh \
    && echo '    cp /app/config/orchat.toml.dist /config/orchat.toml' >> /app/entrypoint.sh \
    && echo 'fi' >> /app/entrypoint.sh \
    && echo '' >> /app/entrypoint.sh \
    && echo '# Set environment variables' >> /app/entrypoint.sh \
    && echo 'export ORCHAT_CONFIG_DIR=/config' >> /app/entrypoint.sh \
    && echo 'export ORCHAT_HISTORY_DIR=/sessions' >> /app/entrypoint.sh \
    && echo 'export PATH="/app/bin:$PATH"' >> /app/entrypoint.sh \
    && echo '' >> /app/entrypoint.sh \
    && echo '# Run as non-root user' >> /app/entrypoint.sh \
    && echo 'exec gosu orchat "$@"' >> /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh

# Install gosu for user switching
RUN apk add --no-cache gosu

WORKDIR /home/orchat
USER orchat

# Set environment variables
ENV ORCHAT_CONFIG_DIR=/config
ENV ORCHAT_HISTORY_DIR=/sessions
ENV PATH="/app/bin:$PATH"

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["orchat", "--help"]

# Build-time metadata
LABEL org.opencontainers.image.title="ORCHAT"
LABEL org.opencontainers.image.description="OpenRouter CLI with multi-turn chat and streaming"
LABEL org.opencontainers.image.version="0.3.0"
LABEL org.opencontainers.image.source="https://github.com/orchat/orchat"
LABEL maintainer="ORCHAT Team <orchat@example.com>"

FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash orchat
USER orchat
WORKDIR /home/orchat

# Install ORCHAT
COPY --chown=orchat:orchat bin/orchat /home/orchat/.local/bin/orchat
COPY --chown=orchat:orchat src/ /home/orchat/.local/lib/orchat/
COPY --chown=orchat:orchat docs/ /home/orchat/.local/share/doc/orchat/

# Set up environment
ENV PATH="/home/orchat/.local/bin:$PATH"
ENV ORCHAT_HOME="/home/orchat/.local/lib/orchat"

# Create config directory
RUN mkdir -p /home/orchat/.config/orchat

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD orchat --version || exit 1

# Entry point
ENTRYPOINT ["orchat"]
CMD ["--help"]

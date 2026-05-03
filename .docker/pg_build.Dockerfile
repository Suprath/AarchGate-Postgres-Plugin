FROM ubuntu:22.04

# Set non-interactive mode to avoid timezone prompts
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC

# Add PostgreSQL official repository
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    && curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Install build tools and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    clang-15 \
    cmake \
    ninja-build \
    git \
    pkg-config \
    postgresql-server-dev-16 \
    postgresql-16 \
    && rm -rf /var/lib/apt/lists/*

# Set up clang as default
RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-15 100 && \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-15 100

WORKDIR /plugin

COPY . .

RUN git submodule update --init --recursive

# Build the extension and AarchGate
RUN make

# Install into PostgreSQL
RUN make install

CMD ["postgres"]

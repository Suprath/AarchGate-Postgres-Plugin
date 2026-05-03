FROM ubuntu:22.04

# Install build tools and dependencies
RUN apt-get update && apt-get install -y \
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

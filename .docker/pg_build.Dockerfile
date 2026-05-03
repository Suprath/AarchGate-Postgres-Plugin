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
    ninja-build \
    git \
    pkg-config \
    libacl1-dev \
    postgresql-server-dev-14 \
    postgresql-14 \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and install CMake 3.28 (required for AarchGate's asmjit)
RUN curl -fsSL https://github.com/Kitware/CMake/releases/download/v3.28.3/cmake-3.28.3-linux-aarch64.tar.gz -o /tmp/cmake.tar.gz && \
    tar -xzf /tmp/cmake.tar.gz -C /usr/local --strip-components=1 && \
    rm /tmp/cmake.tar.gz && \
    cmake --version

# Set up clang as default
RUN update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-15 100 && \
    update-alternatives --install /usr/bin/clang clang /usr/bin/clang-15 100

# Set Clang as the primary compiler for M3 optimizations
ENV CC=clang-15 \
    CXX=clang++-15

WORKDIR /plugin

COPY . .

RUN git submodule update --init --recursive

# Build AarchGate core engine with strict exclusion of bindings
RUN cmake -B external/AarchGate/build-release \
          -S external/AarchGate \
          -DCMAKE_BUILD_TYPE=Release \
          -DAPEX_BUILD_JAVA=OFF \
          -DAPEX_BUILD_PYTHON=OFF \
          -DAPEX_BUILD_TESTS=OFF \
          -DAPEX_BUILD_BENCHMARKS=OFF \
          -DAPEX_BUILD_FLATBUFFERS=OFF \
          -DAPEX_BUILD_EXAMPLES=OFF \
          -DIOX_PLATFORM_FEATURE_ACL=OFF \
          -DFLATBUFFERS_BUILD_FLATC=OFF \
          -G Ninja && \
    cmake --build external/AarchGate/build-release --target aarchgate --parallel 8

# Build the extension and install into PostgreSQL
RUN make && make install

CMD ["postgres"]

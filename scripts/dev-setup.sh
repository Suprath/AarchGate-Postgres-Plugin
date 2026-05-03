#!/bin/bash
set -e

echo "🔧 Setting up AarchGate-Postgres-Plugin for local development..."

# Check for PostgreSQL dev headers
if ! pg_config --includedir-server > /dev/null 2>&1; then
    echo "❌ PostgreSQL dev headers not found. Install with:"
    echo "   macOS (Homebrew): brew install postgresql@16"
    echo "   Ubuntu/Debian: sudo apt-get install postgresql-server-dev-16"
    exit 1
fi

PG_VERSION=$(pg_config --version)
echo "✓ Found: $PG_VERSION"

# Check for clang
if ! command -v clang++-15 &> /dev/null; then
    echo "⚠️  clang++-15 not found. Trying clang++..."
    if ! command -v clang++ &> /dev/null; then
        echo "❌ clang++ not found. Install with:"
        echo "   macOS: xcode-select --install"
        echo "   Ubuntu: sudo apt-get install clang"
        exit 1
    fi
fi

echo "✓ Found clang++"

# Check CMake
if ! command -v cmake &> /dev/null; then
    echo "❌ CMake not found. Install with:"
    echo "   macOS: brew install cmake"
    echo "   Ubuntu: sudo apt-get install cmake"
    exit 1
fi

echo "✓ Found CMake $(cmake --version | head -1)"

# Initialize submodule
if [ ! -f "external/AarchGate/CMakeLists.txt" ]; then
    echo "📦 Cloning AarchGate submodule..."
    git submodule update --init --recursive
fi

echo "✓ Submodule ready"

echo ""
echo "✅ Setup complete! Run: make"

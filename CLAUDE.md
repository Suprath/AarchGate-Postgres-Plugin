# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**AarchGate-Postgres-Plugin** is a PostgreSQL 16 extension that bridges PostgreSQL to the AarchGate JIT vectorized filter engine via a C/C++ glue layer.

The extension exposes a single SQL function:
```sql
aarchgate_filter(strategy text, data bytea) RETURNS bigint
```

It is built using PGXS (PostgreSQL Extension Building System) and includes AarchGate as a git submodule.

## Build System

The project uses **PGXS** to build the PostgreSQL extension. The Makefile automatically:
1. Builds AarchGate from the `external/AarchGate` submodule using CMake
2. Compiles the extension using PGXS
3. Links against the AarchGate shared library with rpath for portability

### Common Build Commands

```bash
# Build the extension and AarchGate submodule
make

# Install into PostgreSQL (requires sudo or pg_config in PATH)
make install

# Clean build artifacts
make clean

# Clean everything including AarchGate build
make clean-all
```

### Build Output

The compiled extension shared library will be located at:
- **macOS**: `aarchgate.dylib`
- **Linux**: `aarchgate.so`

Installation location (via `make install`): PostgreSQL's extension directory (determined by `pg_config`).

## Project Structure

```
.
├── Makefile                         # PGXS + CMake build driver
├── aarchgate.control                # PostgreSQL extension metadata
├── src/
│   └── aarchgate_pg.cpp             # C++ bridge with dispatcher and PG entry points
├── sql/
│   └── aarchgate--1.0.sql           # SQL DDL (function registration)
├── .docker/
│   └── pg_build.Dockerfile          # Multi-arch build container
├── external/
│   └── AarchGate/                   # Git submodule (https://github.com/Suprath/AarchGate.git)
└── .gitignore
```

## Architecture: Kernel Dispatcher

The `src/aarchgate_pg.cpp` implements a **kernel dispatcher** that:

1. **Caches compiled logic per session**: A static `std::unordered_map<std::string, void*>` stores compiled IR trees, keyed by strategy name. On first call or strategy change, AarchGate's JIT compiles once; subsequent calls reuse the cached kernel.

2. **Maps strategy names to execution logic**:
   - `"simple"` → `apex_create_simple_logic()` (Filter0 > 10)
   - `"arbitrage"` → `apex_create_universal_test_logic()` ((Field0 + Field1) > Field2)
   - Unknown → `ereport(ERROR)` with helpful message

3. **Zero-copy bytea access**: Uses PostgreSQL's `PG_DETOAST_DATUM_PACKED` macro to point AarchGate directly at Postgres's internal buffer memory (no copy).

4. **Schema mapping**: Hardcoded as a single 64-bit unsigned integer field at offset 0, stride 8 bytes. Data count is `byte_len / 8`.

## Development Workflow

1. Edit `src/aarchgate_pg.cpp`
2. Run `make` to build
3. Run `make install` to install (requires PostgreSQL dev environment)
4. Test in `psql`:
   ```sql
   CREATE EXTENSION aarchgate;
   SELECT aarchgate_filter('simple', '\x0102030405060708'::bytea);
   ```

## PostgreSQL Integration Notes

- **Module magic**: `PG_MODULE_MAGIC` ensures version compatibility
- **Function info**: `PG_FUNCTION_INFO_V1(aarchgate_filter)` declares stable C function signature
- **SQL registration**: `sql/aarchgate--1.0.sql` defines the SQL wrapper; PGXS automates deployment
- **Extension metadata**: `aarchgate.control` declares version, module path, and relocatability
- **Postgres version**: Targets PostgreSQL 16; adjust `postgresql-server-dev-16` in Dockerfile for other versions

## Submodule Management

Update AarchGate to latest:
```bash
git submodule update --remote --merge external/AarchGate
```

Pull with submodules on clone:
```bash
git clone --recursive <repo-url>
```

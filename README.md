# AarchGate PostgreSQL Plugin

Accelerate your PostgreSQL analytical queries with the AarchGate JIT-compiled vectorized filter engine. This plugin utilizes the AarchGate ARM64 co-processor to perform high-speed filtering directly on the Postgres Buffer Cache.

## Installation

1. **Load the Extension**:
   Inside your `psql` console:
   ```sql
   CREATE EXTENSION aarchgate;
   ```

2. **Verify Installation**:
   ```sql
   -- Test the 'simple' strategy (Field0 > 10)
   SELECT aarchgate_filter('simple', '\x000000000000000b'::bytea); -- Returns 1 (Matches)
   SELECT aarchgate_filter('simple', '\x0000000000000005'::bytea); -- Returns 0 (No Match)
   ```

## Usage Patterns

The extension exposes: `aarchgate_filter(strategy text, data bytea) RETURNS bigint`

### 1. Simple Row-by-Row Filtering
Works for standard tables where each row contains a small `bytea` payload.
```sql
SELECT count(*) FROM raw_data 
WHERE aarchgate_filter('simple', payload) > 0;
```

### 2. Batch Mode (Vectorized) - 🚀 150M+ rec/sec
This is the recommended way to use AarchGate. By packing 1,024 records into a single `bytea` block (8KB), the plugin can process all records in one SIMD burst, achieving massive speedups over native Postgres.

```sql
-- Count total matches in a table of packed data
SELECT sum(aarchgate_filter('simple', packed_payload)) 
FROM analytical_blocks;
```

## Performance Benchmarks (M3 Silicon / ARM64)

| Mode | Execution Time (10M Rows) | Speedup |
| :--- | :--- | :--- |
| **PostgreSQL Native** | 0.349s | 1.0x |
| **AarchGate (Row-by-Row)** | 2.408s | 0.14x |
| **AarchGate (Batch Mode)** | **0.063s** | **5.5x** |

*Note: Speedup scales significantly with logic complexity (e.g., the 'arbitrage' strategy).*

## Development

### Building with Docker
The most reliable way to build is using the provided Dockerfile which locks the toolchain to Clang-15 and PostgreSQL 14.

```bash
docker build -t pg_aarchgate -f .docker/pg_build.Dockerfile .
```

### Running Benchmarks (via Docker)
The easiest way to verify the 150M+ rec/sec throughput is using the automated benchmark suite inside Docker:

```bash
# 1. Build the production image
docker build -t pg_aarchgate -f .docker/pg_build.Dockerfile .

# 2. Run the benchmark suite (starts PG, generates 10M rows, runs tests)
docker run --rm pg_aarchgate /bin/bash -c "service postgresql start && sleep 5 && ./scripts/test_pg_acceleration.sh"
```


#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting AarchGate-Postgres Acceleration Test...${NC}"

# 1. Build AarchGate Submodule (Release with Ninja)
echo -e "${BLUE}📦 Building AarchGate submodule (Release)...${NC}"
cd external/AarchGate
cmake -B build-release -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DAPEX_BUILD_JAVA=OFF \
      -DAPEX_BUILD_PYTHON=OFF \
      -DAPEX_BUILD_TESTS=OFF \
      -DAPEX_BUILD_BENCHMARKS=OFF \
      -DAPEX_BUILD_FLATBUFFERS=OFF \
      -DAPEX_BUILD_EXAMPLES=OFF \
      -DIOX_PLATFORM_FEATURE_ACL=OFF \
      -DFLATBUFFERS_BUILD_FLATC=OFF
cmake --build build-release --target aarchgate --parallel 8
cd ../..

# 2. Build and Install Postgres Extension
echo -e "${BLUE}🔨 Building and installing extension...${NC}"
make
make install

# 3. Setup Temporary Postgres Database
echo -e "${BLUE}🐘 Setting up benchmark database...${NC}"
DB_NAME="aarchgate_test"

# Run database setup as postgres user
su - postgres -c "dropdb --if-exists $DB_NAME"
su - postgres -c "createdb $DB_NAME"
su - postgres -c "psql -d $DB_NAME -c 'CREATE EXTENSION aarchgate;'"

# 4. Generate 10 Million Rows of Data
echo -e "${BLUE}📊 Generating 10 million rows (8-byte records)...${NC}"
su - postgres -c "psql -d $DB_NAME" <<EOF
CREATE TABLE raw_data (
    id serial PRIMARY KEY,
    payload bytea
);

-- Generate 10M rows, each with an 8-byte payload
INSERT INTO raw_data (payload)
SELECT decode(lpad(hex, 16, '0'), 'hex')
FROM (
    SELECT to_hex((random() * 9223372036854775807)::bigint) as hex
    FROM generate_series(1, 10000000)
) s;
EOF

# 5. Benchmark: Standard PG vs AarchGate
echo -e "${BLUE}🏁 Running Benchmark (10M Rows)...${NC}"

echo "--------------------------------------------------"
echo "Benchmark 1: Standard Postgres Filter (WHERE clause)"
echo "Logic: count records where first byte > 10"
echo "--------------------------------------------------"
TIME_PG=$( { time su - postgres -c "psql -d $DB_NAME -c \"SELECT count(*) FROM raw_data WHERE get_byte(payload, 0) > 10;\"" > /dev/null; } 2>&1 | grep real | awk '{print $2}' )
echo -e "${GREEN}Postgres Time: $TIME_PG${NC}"

echo "--------------------------------------------------"
echo "Benchmark 2: AarchGate JIT Filter (Vectorized)"
echo "Logic: count records where Field0 > 10"
echo "--------------------------------------------------"
TIME_AG=$( { time su - postgres -c "psql -d $DB_NAME -c \"SELECT sum(aarchgate_filter('simple', payload)) FROM raw_data;\"" > /dev/null; } 2>&1 | grep real | awk '{print $2}' )
echo -e "${GREEN}AarchGate Time: $TIME_AG${NC}"

# 6. Batch Mode Benchmark: 1024 Records Per Call
echo -e "${BLUE}📦 Setting up Batch Mode Benchmark (1024 records per call)...${NC}"
su - postgres -c "psql -d $DB_NAME" <<EOF
CREATE TABLE raw_data_batch (
    id serial PRIMARY KEY,
    payload bytea
);

-- Pack records into 1024-unit batches (8KB blocks)
INSERT INTO raw_data_batch (payload)
SELECT string_agg(payload, '') 
FROM (
    SELECT payload, (row_number() over () - 1) / 1024 as batch_id 
    FROM raw_data
) s 
GROUP BY batch_id;
EOF

echo "--------------------------------------------------"
echo "Benchmark 3: AarchGate BATCH Mode (Vectorized)"
echo "Logic: count records where Field0 > 10 (1024 records/call)"
echo "--------------------------------------------------"
TIME_AG_BATCH=$( { time su - postgres -c "psql -d $DB_NAME -c \"SELECT sum(aarchgate_filter('simple', payload)) FROM raw_data_batch;\"" > /dev/null; } 2>&1 | grep real | awk '{print $2}' )
echo -e "${GREEN}AarchGate Batch Time: $TIME_AG_BATCH${NC}"

# 7. Conclusion
echo "--------------------------------------------------"
echo -e "${BLUE}✅ Benchmarks Complete${NC}"
echo -e "Standard Postgres: $TIME_PG"
echo -e "AarchGate Row-by-Row: $TIME_AG"
echo -e "AarchGate Batch Mode: $TIME_AG_BATCH"
echo "--------------------------------------------------"
echo -e "${GREEN}Success: Batch mode demonstrates the true vectorized throughput of AarchGate.${NC}"



# CLion Setup Guide

## Quick Start (Recommended: Docker)

### 1. Docker Compose (No local PostgreSQL needed)

```bash
# Start PostgreSQL and build in Docker
docker-compose up

# You'll see build output and test results
# Leave running in the background
```

In another terminal, connect to PostgreSQL:
```bash
psql -h localhost -U postgres
```

Then test:
```sql
CREATE EXTENSION aarchgate;
SELECT aarchgate_filter('simple', '\x0102030405060708'::bytea);
```

---

## Local Development Setup (Mac/Linux)

### 1. Install PostgreSQL Dev Headers

**macOS:**
```bash
brew install postgresql@16
export PATH="/usr/local/opt/postgresql@16/bin:$PATH"
```

**Ubuntu/Debian:**
```bash
sudo apt-get install postgresql-server-dev-16 clang-15
```

### 2. Run Setup Script

```bash
chmod +x scripts/dev-setup.sh
./scripts/dev-setup.sh
```

### 3. Build

```bash
make
```

After success, output is at:
- **macOS**: `aarchgate.dylib`
- **Linux**: `aarchgate.so`

---

## CLion Configuration

### Option A: Command-Line Build (Simplest)

1. **Open project**: File → Open → select repo root
2. **Build**: In CLion terminal:
   ```bash
   make clean-all && make
   ```
3. **Run tests**: Terminal:
   ```bash
   # Start PostgreSQL first (docker-compose up)
   make install
   psql -c "CREATE EXTENSION aarchgate;"
   psql -c "SELECT aarchgate_filter('simple', '\x0102030405060708'::bytea);"
   ```

### Option B: CLion Custom Build Target

1. **Settings → Build, Execution, Deployment → Custom Build Targets**
2. Click **+** to add new target
3. **Name**: `Build Extension`
4. **Program**: `make`
5. **Working directory**: `$ProjectFileDir$`
6. **Program arguments**: `clean-all && make` (or just `make`)

Then: **Build → Build Project** will run your custom target.

### Option C: Create Run Configuration

1. **Run → Edit Configurations**
2. Click **+** → Shell Script
3. **Name**: `Test Extension`
4. **Script text**:
```bash
set -e
make install
psql -c "CREATE EXTENSION aarchgate;"
echo "SELECT aarchgate_filter('simple', '\x0102030405060708'::bytea);" | psql
```
5. **Working directory**: `$ProjectFileDir$`

Then: **Run → Run 'Test Extension'**

---

## Debugging C++ Code in CLion

The tricky part: PGXS doesn't create traditional debug symbols in CLion's format.

### Workaround: Test Harness

Create `src/test_dispatcher.cpp` to unit-test the dispatcher logic outside PostgreSQL:

```cpp
#include <iostream>
#include <cassert>
#include "apex/apex_c_api.h"

// Include dispatcher logic (see aarchgate_pg.cpp)
apex_engine_h test_engine() {
    auto engine = apex_create();
    assert(engine != nullptr);
    
    apex_field_descriptor_t field = {
        .name = "data",
        .offset = 0,
        .bit_width = 64,
        .data_type = 3
    };
    
    int ret = apex_register_schema(engine, "default_schema", &field, 1, 8);
    assert(ret == 0);
    
    auto logic = apex_create_simple_logic();
    assert(logic != nullptr);
    
    ret = apex_set_logic(engine, "default_schema", logic, APEX_EXEC_MODE_BIT_SLICED);
    assert(ret == 0);
    
    return engine;
}

int main() {
    std::cout << "Testing AarchGate dispatcher..." << std::endl;
    auto engine = test_engine();
    std::cout << "✓ Engine initialized successfully" << std::endl;
    apex_destroy(engine);
    return 0;
}
```

Then compile and debug this directly in CLion with full breakpoints/stepping.

---

## Recommended Workflow

1. **Edit code** in CLion (full IDE support, IntelliSense, etc.)
2. **Build via terminal**: `make`
3. **Test via Docker**: `docker-compose up` + `psql`
4. **Debug logic** in CLion using the test harness (optional)

---

## Troubleshooting

### "postgres.h not found" in CLion editor
- This is IDE indexing only — compilation still works
- **Fix**: CLion → Preferences → C/C++ → CMake and set include paths manually, or ignore the squiggly lines

### Build fails: "pg_config not found"
- Ensure PostgreSQL dev is installed
- Run `pg_config --version` in terminal to test
- If it works in terminal but CLion fails, restart CLion

### Docker: "Permission denied" on volumes
- Ensure Docker daemon is running
- On macOS with Docker Desktop: Settings → Resources → File Sharing

### Extension install fails
- Ensure PostgreSQL is running: `docker-compose ps`
- Check PostgreSQL is accepting connections: `psql -h localhost -U postgres`
- Rebuild: `docker-compose down && docker-compose up --build`

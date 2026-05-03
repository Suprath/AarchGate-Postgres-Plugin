#ifdef __clang__
#define PG_PRINTF_ATTRIBUTE printf
#endif

extern "C" {
#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"
}

#include "apex/apex_c_api.h"
#include <string>
#include <cstring>

extern "C" {

PG_MODULE_MAGIC;

/**
 * Global state for the AarchGate engine to avoid JIT overhead on every row.
 * In a real production system, this would be managed per-backend or per-query.
 */
static apex_engine_h g_engine = nullptr;
static std::string g_current_logic;

/**
 * Lazy-initializes the AarchGate engine and compiles the requested logic.
 */
static void init_aarchgate_engine(const char* strategy) {
    if (g_engine == nullptr) {
        g_engine = apex_create();
        if (g_engine == nullptr) {
            ereport(ERROR, (errmsg("AarchGate-Postgres: Failed to create engine instance")));
        }

        // Register a default 64-bit schema for vectorized processing
        apex_field_descriptor_t field = {
            .name = "Field0",
            .offset = 0,
            .bit_width = 64,
            .data_type = 3  // UINT64
        };

        if (apex_register_schema(g_engine, "default", &field, 1, 8) != 0) {
            ereport(ERROR, (errmsg("AarchGate-Postgres: Failed to register schema")));
        }
    }

    if (g_current_logic != strategy) {
        void* logic_ptr = nullptr;

        if (strcmp(strategy, "simple") == 0) {
            logic_ptr = apex_create_simple_logic();
        } else if (strcmp(strategy, "arbitrage") == 0) {
            logic_ptr = apex_create_universal_test_logic();
        } else {
            ereport(ERROR, (errmsg("AarchGate-Postgres: Unknown strategy '%s'", strategy)));
        }

        if (logic_ptr == nullptr) {
            ereport(ERROR, (errmsg("AarchGate-Postgres: Failed to create logic for '%s'", strategy)));
        }

        // Set the logic into the engine (JIT compilation happens here)
        if (apex_set_logic(g_engine, "default", logic_ptr, APEX_EXEC_MODE_BIT_SLICED) != 0) {
            ereport(ERROR, (errmsg("AarchGate-Postgres: Failed to set engine logic")));
        }

        g_current_logic = strategy;
    }
}

PG_FUNCTION_INFO_V1(aarchgate_filter);

/**
 * The hot-path filter function.
 * Arg 0: Strategy Name (text)
 * Arg 1: Data Block (bytea, 64 records)
 */
Datum aarchgate_filter(PG_FUNCTION_ARGS) {
    // 1. Get arguments
    text* strategy_text = PG_GETARG_TEXT_PP(0);
    
    // 2. STRICT ZERO-COPY: Use PG_DETOAST_DATUM_PACKED to get direct buffer access
    Datum data_datum = PG_GETARG_DATUM(1);
    struct varlena* data_bytea = PG_DETOAST_DATUM_PACKED(data_datum);

    // 3. Dispatch & Cache Check
    char* strategy = text_to_cstring(strategy_text);
    init_aarchgate_engine(strategy);

    // 4. Data Extraction: VARDATA_ANY provides the pointer into the Postgres Buffer Cache
    const void* raw_data = VARDATA_ANY(data_bytea);
    size_t data_size = VARSIZE_ANY_EXHDR(data_bytea);
    
    // Calculate number of records based on payload size (8 bytes per UINT64)
    size_t num_records = data_size / 8;
    
    if (num_records == 0) {
        PG_RETURN_INT64(0);
    }

    // 5. Execution: Call the vectorized co-processor
    uint64_t match_count = apex_execute(g_engine, raw_data, num_records);

    if (match_count == (uint64_t)-1) {
        ereport(ERROR, (errmsg("AarchGate-Postgres: Execution kernel failure")));
    }

    // Free the strategy string (palloc'd by text_to_cstring)
    pfree(strategy);
    
    // If we detoasted (copied), we should free it, but PG_DETOAST_DATUM_PACKED 
    // usually returns the original pointer if it's already aligned and not compressed.
    // However, PG manages this memory if it's part of the datum.
    
    PG_RETURN_INT64((int64_t)match_count);
}

} // extern "C"


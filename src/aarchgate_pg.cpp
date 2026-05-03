#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

#include "apex/apex_c_api.h"
#include <unordered_map>
#include <string>
#include <cstring>

PG_MODULE_MAGIC;

extern "C" {

static apex_engine_h g_engine = nullptr;
static std::string g_last_logic_tag;
static std::unordered_map<std::string, void*> g_logic_cache;

apex_engine_h get_or_create_engine(const char* logic_tag) {
    if (g_engine == nullptr) {
        g_engine = apex_create();
        if (g_engine == nullptr) {
            ereport(ERROR, (errmsg("Failed to create AarchGate engine")));
        }

        apex_field_descriptor_t field = {
            .name = "data",
            .offset = 0,
            .bit_width = 64,
            .data_type = 3  // UINT64
        };

        int ret = apex_register_schema(g_engine, "default_schema", &field, 1, 8);
        if (ret != 0) {
            ereport(ERROR, (errmsg("Failed to register schema with AarchGate engine")));
        }
    }

    if (g_last_logic_tag != logic_tag) {
        void* logic = nullptr;

        if (strcmp(logic_tag, "simple") == 0) {
            logic = apex_create_simple_logic();
        } else if (strcmp(logic_tag, "arbitrage") == 0) {
            logic = apex_create_universal_test_logic();
        } else {
            ereport(ERROR, (errmsg("Unknown AarchGate logic strategy: '%s'. Supported: 'simple', 'arbitrage'", logic_tag)));
        }

        if (logic == nullptr) {
            ereport(ERROR, (errmsg("Failed to create logic for strategy '%s'", logic_tag)));
        }

        int ret = apex_set_logic(g_engine, "default_schema", logic, APEX_EXEC_MODE_BIT_SLICED);
        if (ret != 0) {
            ereport(ERROR, (errmsg("Failed to set logic for strategy '%s'", logic_tag)));
        }

        g_last_logic_tag = logic_tag;
    }

    return g_engine;
}

PG_FUNCTION_INFO_V1(aarchgate_filter);

Datum aarchgate_filter(PG_FUNCTION_ARGS) {
    text* strategy_text = PG_GETARG_TEXT_PP(0);
    bytea* data_bytea = PG_DETOAST_DATUM_PACKED(PG_GETARG_DATUM(1));

    const char* strategy = text_to_cstring(strategy_text);
    const void* data_ptr = VARDATA_ANY(data_bytea);
    size_t byte_len = VARSIZE_ANY_EXHDR(data_bytea);

    apex_engine_h engine = get_or_create_engine(strategy);

    size_t count = byte_len / 8;
    uint64_t result = apex_execute(engine, data_ptr, count);

    if (result == UINT64_MAX) {
        ereport(ERROR, (errmsg("AarchGate execution failed")));
    }

    PG_RETURN_INT64((int64_t)result);
}

}

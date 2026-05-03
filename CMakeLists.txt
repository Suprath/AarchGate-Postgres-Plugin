cmake_minimum_required(VERSION 3.20)
project(aarchgate_pg)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find PostgreSQL
find_package(PostgreSQL REQUIRED)

# Include directories
include_directories(
    ${PostgreSQL_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}/external/AarchGate/include
)

# Server headers (needed for postgres.h etc)
execute_process(COMMAND pg_config --includedir-server OUTPUT_VARIABLE PG_SERVER_INCLUDE_DIR OUTPUT_STRIP_TRAILING_WHITESPACE)
include_directories(${PG_SERVER_INCLUDE_DIR})

# AarchGate Library Location
set(AARCHGATE_LIB_DIR ${CMAKE_CURRENT_SOURCE_DIR}/external/AarchGate/build-release/src/api)
link_directories(${AARCHGATE_LIB_DIR})

# Extension source
add_library(aarchgate_pg SHARED src/aarchgate_pg.cpp)

# Linking
target_link_libraries(aarchgate_pg PRIVATE aarchgate)

# Compilation flags
target_compile_options(aarchgate_pg PRIVATE -fPIC)

# IDE Helpers: Show the SQL and control files in the project tree
add_custom_target(extension_files SOURCES 
    aarchgate.control 
    sql/aarchgate--1.0.sql
    scripts/test_pg_acceleration.sh
)

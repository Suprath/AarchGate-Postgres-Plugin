# AarchGate-Postgres-Plugin Makefile

EXTENSION = aarchgate
MODULE_big = aarchgate_pg
OBJS = src/aarchgate_pg.o

# Submodule paths
AARCHGATE_HOME = $(CURDIR)/external/AarchGate
AARCHGATE_BUILD = $(AARCHGATE_HOME)/build-release
AARCHGATE_API = $(AARCHGATE_BUILD)

# Compilation flags
PG_CPPFLAGS = -I$(AARCHGATE_HOME)/include -std=c++20 -fPIC

# Linking flags
# Ensure we use the build root for the library and rpath
SHLIB_LINK = -L$(AARCHGATE_API) -laarchgate \
             -Wl,-rpath,'$(AARCHGATE_API)'


DATA = sql/aarchgate--1.0.sql

# PGXS Integration
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# Custom rule for C++ compilation to ensure clang-15 and C++20
src/aarchgate_pg.o: src/aarchgate_pg.cpp
	clang++-15 -std=c++20 -fPIC $(CPPFLAGS) $(PG_CPPFLAGS) \
		-I$(shell $(PG_CONFIG) --includedir-server) \
		-c -o $@ $<

.PHONY: clean-all
clean-all: clean
	# Note: We preserve the AARCHGATE_BUILD to avoid redundant co-processor recompilation


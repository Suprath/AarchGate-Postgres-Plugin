AARCHGATE_BUILD = external/AarchGate/build-release
AARCHGATE_DIST  = external/AarchGate/dist

MODULE_big = aarchgate
OBJS       = src/aarchgate_pg.o

PG_CPPFLAGS = -I$(AARCHGATE_DIST)/include -std=c++20
SHLIB_LINK  = -L$(AARCHGATE_DIST)/lib -laarchgate -Wl,-rpath,$(AARCHGATE_DIST)/lib

DATA = sql/aarchgate--1.0.sql

# Ensure AarchGate is built before compiling the extension
$(OBJS): build-aarchgate

.PHONY: build-aarchgate
build-aarchgate:
	cmake -B $(AARCHGATE_BUILD) -S external/AarchGate -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$(AARCHGATE_DIST)
	cmake --build $(AARCHGATE_BUILD)
	cmake --install $(AARCHGATE_BUILD)

# Include PGXS at the end
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# Override the C++ compilation rule
src/aarchgate_pg.o: src/aarchgate_pg.cpp
	clang++-15 -std=c++20 -fPIC $(CPPFLAGS) $(PG_CPPFLAGS) \
		-I$(shell $(PG_CONFIG) --includedir-server) \
		-c -o $@ $<

.PHONY: clean-all
clean-all: clean
	rm -rf $(AARCHGATE_BUILD) $(AARCHGATE_DIST)

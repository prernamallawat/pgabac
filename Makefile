MODULE_big  = pg_abac
OBJS        = pg_abac.o
EXTENSION   = pg_abac
DATA        = sql/pg_abac--1.0.sql
PGFILEDESC  = "pg_abac - Attribute Based Access Control extension for University DB"

PG_CONFIG  ?= pg_config
PGXS       := $(shell $(PG_CONFIG) --pgxs)
override with_llvm = no
include $(PGXS)

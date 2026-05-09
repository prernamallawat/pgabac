#ifndef PG_ABAC_H
#define PG_ABAC_H

#include "postgres.h"
#include "fmgr.h"

Datum abac_text_equals(PG_FUNCTION_ARGS);
Datum abac_text_not_equals(PG_FUNCTION_ARGS);
Datum abac_text_compare(PG_FUNCTION_ARGS);

#endif
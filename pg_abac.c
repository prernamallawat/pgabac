/*
 * pg_abac.c
 *
 * Small C helper layer for the ABAC PostgreSQL extension.
 * The policy metadata, University schema, and RLS policy setup are written in SQL.
 * This file provides fast, SQL-callable predicate helpers used by the policy engine.
 */

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(abac_text_equals);
PG_FUNCTION_INFO_V1(abac_text_not_equals);
PG_FUNCTION_INFO_V1(abac_text_compare);
PG_FUNCTION_INFO_V1(abac_text_like);
PG_FUNCTION_INFO_V1(abac_text_not_like);

/*
 * abac_text_equals(left text, right text) returns boolean
 * Used for the required equality predicate support.
 */
Datum
abac_text_equals(PG_FUNCTION_ARGS)
{
    text *left_arg;
    text *right_arg;
    char *left;
    char *right;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
        PG_RETURN_BOOL(false);

    left_arg = PG_GETARG_TEXT_PP(0);
    right_arg = PG_GETARG_TEXT_PP(1);

    left = text_to_cstring(left_arg);
    right = text_to_cstring(right_arg);

    PG_RETURN_BOOL(strcmp(left, right) == 0);
}

/*
 * abac_text_not_equals(left text, right text) returns boolean
 * Optional predicate useful for testing denied rows or non-matching attributes.
 */
Datum
abac_text_not_equals(PG_FUNCTION_ARGS)
{
    text *left_arg;
    text *right_arg;
    char *left;
    char *right;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
        PG_RETURN_BOOL(false);

    left_arg = PG_GETARG_TEXT_PP(0);
    right_arg = PG_GETARG_TEXT_PP(1);

    left = text_to_cstring(left_arg);
    right = text_to_cstring(right_arg);

    PG_RETURN_BOOL(strcmp(left, right) != 0);
}

/*
 * abac_text_compare(left text, operator text, right text) returns boolean
 * Supports the main equality operator and a small optional != extension.
 */
Datum
abac_text_compare(PG_FUNCTION_ARGS)
{
    text *left_arg;
    text *operator_arg;
    text *right_arg;
    char *left;
    char *operator_text;
    char *right;
    int cmp;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1) || PG_ARGISNULL(2))
        PG_RETURN_BOOL(false);

    left_arg = PG_GETARG_TEXT_PP(0);
    operator_arg = PG_GETARG_TEXT_PP(1);
    right_arg = PG_GETARG_TEXT_PP(2);

    operator_text = text_to_cstring(operator_arg);

    /* Handle LIKE/NOT LIKE before cstring conversion — needs text* pointers. */
    if (strcmp(operator_text, "LIKE") == 0)
        PG_RETURN_BOOL(
            DatumGetBool(DirectFunctionCall2Coll(
                textlike,
                PG_GET_COLLATION(),
                PointerGetDatum(left_arg),
                PointerGetDatum(right_arg)
            ))
        );

    if (strcmp(operator_text, "NOT LIKE") == 0)
        PG_RETURN_BOOL(
            DatumGetBool(DirectFunctionCall2Coll(
                textnlike,
                PG_GET_COLLATION(),
                PointerGetDatum(left_arg),
                PointerGetDatum(right_arg)
            ))
        );

    left = text_to_cstring(left_arg);
    right = text_to_cstring(right_arg);

    cmp = strcmp(left, right);

    if (strcmp(operator_text, "=") == 0 || strcmp(operator_text, "==") == 0)
        PG_RETURN_BOOL(cmp == 0);

    if (strcmp(operator_text, "!=") == 0 || strcmp(operator_text, "<>") == 0)
        PG_RETURN_BOOL(cmp != 0);

    if (strcmp(operator_text, ">") == 0)
        PG_RETURN_BOOL(cmp > 0);

    if (strcmp(operator_text, "<") == 0)
        PG_RETURN_BOOL(cmp < 0);

    if (strcmp(operator_text, ">=") == 0)
        PG_RETURN_BOOL(cmp >= 0);

    if (strcmp(operator_text, "<=") == 0)
        PG_RETURN_BOOL(cmp <= 0);

    ereport(ERROR,
            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
             errmsg("unsupported ABAC operator: %s", operator_text),
             errhint("Supported C text operators are =, ==, !=, <>, >, <, >=, <=, LIKE, and NOT LIKE.")));

    PG_RETURN_BOOL(false);
}

/*
 * abac_text_like(str text, pattern text) returns boolean
 * Returns true when str matches the SQL LIKE pattern.
 */
Datum
abac_text_like(PG_FUNCTION_ARGS)
{
    text *str;
    text *pattern;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
        PG_RETURN_BOOL(false);

    str     = PG_GETARG_TEXT_PP(0);
    pattern = PG_GETARG_TEXT_PP(1);

    PG_RETURN_BOOL(
        DatumGetBool(DirectFunctionCall2Coll(
            textlike,
            PG_GET_COLLATION(),
            PointerGetDatum(str),
            PointerGetDatum(pattern)
        ))
    );
}

/*
 * abac_text_not_like(str text, pattern text) returns boolean
 * Returns true when str does NOT match the SQL LIKE pattern.
 */
Datum
abac_text_not_like(PG_FUNCTION_ARGS)
{
    text *str;
    text *pattern;

    if (PG_ARGISNULL(0) || PG_ARGISNULL(1))
        PG_RETURN_BOOL(false);

    str     = PG_GETARG_TEXT_PP(0);
    pattern = PG_GETARG_TEXT_PP(1);

    PG_RETURN_BOOL(
        DatumGetBool(DirectFunctionCall2Coll(
            textnlike,
            PG_GET_COLLATION(),
            PointerGetDatum(str),
            PointerGetDatum(pattern)
        ))
    );
}

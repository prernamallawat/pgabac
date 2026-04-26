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

    left = text_to_cstring(left_arg);
    operator_text = text_to_cstring(operator_arg);
    right = text_to_cstring(right_arg);

    cmp = strcmp(left, right);

    if (strcmp(operator_text, "=") == 0 || strcmp(operator_text, "==") == 0)
        PG_RETURN_BOOL(cmp == 0);

    if (strcmp(operator_text, "!=") == 0 || strcmp(operator_text, "<>") == 0)
        PG_RETURN_BOOL(cmp != 0);

    ereport(ERROR,
            (errcode(ERRCODE_INVALID_PARAMETER_VALUE),
             errmsg("unsupported ABAC operator: %s", operator_text),
             errhint("Supported C operators are =, ==, !=, and <>.")));

    PG_RETURN_BOOL(false);
}

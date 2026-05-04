# LIKE Operator Implementation

## Overview

The `LIKE` and `NOT LIKE` operators were added to the ABAC policy engine so that conditions can match row column values or user attributes against SQL wildcard patterns (e.g., `'Comp%'`, `'%Sci.'`, `'_iology'`).

---

## What Changed

### 1. `pg_abac.c` — C Layer

Two new SQL-callable C functions were added:

#### `abac_text_like(str text, pattern text) → boolean`
Returns `true` when `str` matches the SQL LIKE `pattern`. Wildcards `%` (any sequence) and `_` (any single character) are supported.

#### `abac_text_not_like(str text, pattern text) → boolean`
The inverse — returns `true` when `str` does **not** match the pattern.

Both functions delegate directly to PostgreSQL's internal `textlike` / `textnlike` functions via `DirectFunctionCall2Coll`, passing `PG_GET_COLLATION()` so the match respects the database collation correctly.

```c
PG_RETURN_BOOL(
    DatumGetBool(DirectFunctionCall2Coll(
        textlike,
        PG_GET_COLLATION(),
        PointerGetDatum(str),
        PointerGetDatum(pattern)
    ))
);
```

#### `abac_text_compare` — LIKE branch added

The existing generic compare function was extended. LIKE/NOT LIKE are handled **before** the `text_to_cstring` / `strcmp` path because `DirectFunctionCall2Coll` requires the original `text *` pointers, not C strings.

```c
operator_text = text_to_cstring(operator_arg);

if (strcmp(operator_text, "LIKE") == 0)
    PG_RETURN_BOOL(DirectFunctionCall2Coll(textlike, ...));

if (strcmp(operator_text, "NOT LIKE") == 0)
    PG_RETURN_BOOL(DirectFunctionCall2Coll(textnlike, ...));

// cstring conversion and strcmp happen only for other operators
left = text_to_cstring(left_arg);
right = text_to_cstring(right_arg);
cmp = strcmp(left, right);
```

---

### 2. `sql/pg_abac--1.0.sql` — SQL Layer

#### New SQL wrappers
```sql
CREATE FUNCTION abac_text_like(str text, pattern text)
RETURNS boolean LANGUAGE C IMMUTABLE
AS '$libdir/pg_abac', 'abac_text_like';

CREATE FUNCTION abac_text_not_like(str text, pattern text)
RETURNS boolean LANGUAGE C IMMUTABLE
AS '$libdir/pg_abac', 'abac_text_not_like';
```

#### CHECK constraint extended
The `abac_rule_conditions` table validates the `operator` column. `'LIKE'` and `'NOT LIKE'` were added:

```sql
CHECK (operator IN ('=', '==', '!=', '<>', '>', '<', '>=', '<=', 'LIKE', 'NOT LIKE'))
```

#### `abac_compare_values` extended
The PL/pgSQL comparison function used by the RLS engine was extended with two new branches in the text path:

```sql
IF p_operator = 'LIKE'     THEN RETURN p_left_value LIKE     p_right_value; END IF;
IF p_operator = 'NOT LIKE' THEN RETURN p_left_value NOT LIKE p_right_value; END IF;
```

---

## How It Fits Into the RLS Engine

The main RLS predicate `abac_check_access(table_name, row_attrs jsonb)` evaluates each condition by calling `abac_compare_values(left, operator, right, value_type)`. Since LIKE is a text-only operation, it is handled in the text branch (when `value_type = 'text'`). Numeric conditions (`value_type = 'numeric'`) are unaffected.

---

## Usage Example

**Define a LIKE-based rule:**
```sql
SELECT abac_add_rule('student_name_pattern', 'student', 'Match students by name prefix');
SELECT abac_add_condition('student_name_pattern', 'name', 'name_pattern', 'LIKE');
SELECT abac_set_user_attribute('alice', 'name_pattern', 'A%');
```

**Use the helper functions directly:**
```sql
SELECT abac_text_like('Comp. Sci.', 'Comp%');       -- true
SELECT abac_text_like('Biology', 'Comp%');           -- false
SELECT abac_text_not_like('Biology', 'Comp%');       -- true

SELECT abac_compare_values('Comp. Sci.', 'LIKE',     'Comp%', 'text');  -- true
SELECT abac_compare_values('Biology',    'NOT LIKE',  'Comp%', 'text'); -- true
```

---

## Design Notes

- **Collation-aware**: Both functions pass `PG_GET_COLLATION()` so results are consistent with the database collation — no hardcoded `DEFAULT_COLLATION_OID`.
- **NULL-safe**: Both functions return `false` when either argument is NULL, consistent with the rest of the engine.
- **LIKE is text-only**: The numeric branch of `abac_compare_values` does not include LIKE — it raises an exception for unsupported operators, which is the correct behavior.

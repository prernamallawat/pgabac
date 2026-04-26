\echo Use "CREATE EXTENSION pg_abac" to load this file. \quit

CREATE FUNCTION abac_text_equals(left_value text, right_value text)
RETURNS boolean
LANGUAGE C
IMMUTABLE
AS '$libdir/pg_abac', 'abac_text_equals';

CREATE FUNCTION abac_text_not_equals(left_value text, right_value text)
RETURNS boolean
LANGUAGE C
IMMUTABLE
AS '$libdir/pg_abac', 'abac_text_not_equals';

CREATE FUNCTION abac_text_compare(left_value text, operator_value text, right_value text)
RETURNS boolean
LANGUAGE C
IMMUTABLE
AS '$libdir/pg_abac', 'abac_text_compare';

CREATE TABLE IF NOT EXISTS abac_user_attributes (
    username text NOT NULL,
    attribute_name text NOT NULL,
    attribute_value text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (username, attribute_name)
);

CREATE TABLE IF NOT EXISTS abac_policies (
    policy_id bigserial PRIMARY KEY,
    policy_name text NOT NULL UNIQUE,
    table_name text NOT NULL,
    column_name text,
    user_attribute text NOT NULL,
    operator text NOT NULL DEFAULT '=',
    constant_value text,
    is_enabled boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (operator IN ('=', '==', '!=', '<>')),
    CHECK (
        (column_name IS NOT NULL AND constant_value IS NULL)
        OR
        (column_name IS NULL AND constant_value IS NOT NULL)
    )
);

CREATE OR REPLACE FUNCTION abac_set_user_attribute(
    p_username text,
    p_attribute_name text,
    p_attribute_value text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO abac_user_attributes(username, attribute_name, attribute_value, updated_at)
    VALUES (p_username, p_attribute_name, p_attribute_value, now())
    ON CONFLICT (username, attribute_name)
    DO UPDATE SET
        attribute_value = EXCLUDED.attribute_value,
        updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION abac_get_user_attribute(
    p_username text,
    p_attribute_name text
)
RETURNS text
LANGUAGE sql
STABLE
AS $$
    SELECT attribute_value
    FROM abac_user_attributes
    WHERE username = p_username
      AND attribute_name = p_attribute_name
$$;

CREATE OR REPLACE FUNCTION abac_add_policy(
    p_policy_name text,
    p_table_name text,
    p_column_name text,
    p_user_attribute text,
    p_operator text DEFAULT '=',
    p_constant_value text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_policy_id bigint;
BEGIN
    INSERT INTO abac_policies(
        policy_name,
        table_name,
        column_name,
        user_attribute,
        operator,
        constant_value
    )
    VALUES (
        p_policy_name,
        p_table_name,
        p_column_name,
        p_user_attribute,
        p_operator,
        p_constant_value
    )
    ON CONFLICT (policy_name)
    DO UPDATE SET
        table_name = EXCLUDED.table_name,
        column_name = EXCLUDED.column_name,
        user_attribute = EXCLUDED.user_attribute,
        operator = EXCLUDED.operator,
        constant_value = EXCLUDED.constant_value,
        is_enabled = true
    RETURNING policy_id INTO v_policy_id;

    RETURN v_policy_id;
END;
$$;

CREATE OR REPLACE FUNCTION abac_disable_policy(p_policy_name text)
RETURNS void
LANGUAGE sql
AS $$
    UPDATE abac_policies
    SET is_enabled = false
    WHERE policy_name = p_policy_name
$$;

CREATE OR REPLACE FUNCTION abac_enable_policy(p_policy_name text)
RETURNS void
LANGUAGE sql
AS $$
    UPDATE abac_policies
    SET is_enabled = true
    WHERE policy_name = p_policy_name
$$;

/*
 * Main RLS helper.
 * It returns true only when all enabled policies for a table are satisfied.
 *
 * For column policies:
 *   user.attribute operator row.column_value
 *
 * For nominal policies:
 *   user.attribute operator constant_value
 */
CREATE OR REPLACE FUNCTION abac_check_text(
    p_table_name text,
    p_column_name text,
    p_row_value text
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT NOT EXISTS (
        SELECT 1
        FROM abac_policies p
        LEFT JOIN abac_user_attributes a
          ON a.username = current_user
         AND a.attribute_name = p.user_attribute
        WHERE p.table_name = p_table_name
          AND p.is_enabled = true
          AND (
                (p.column_name = p_column_name
                 AND NOT abac_text_compare(a.attribute_value, p.operator, p_row_value))
                OR
                (p.column_name IS NULL
                 AND NOT abac_text_compare(a.attribute_value, p.operator, p.constant_value))
              )
    )
$$;

COMMENT ON FUNCTION abac_check_text(text, text, text) IS
'ABAC RLS predicate helper. Checks enabled metadata policies against current_user attributes.';

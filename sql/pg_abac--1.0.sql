\echo Use "CREATE EXTENSION pg_abac" to load this file. \quit

/*
 * pg_abac extension
 * Metadata-driven ABAC engine for PostgreSQL RLS.
 * Design:
 *   - abac_user_attributes stores subject/user attributes.
 *   - abac_rules stores one rule for one table.
 *   - abac_rule_conditions stores AND-ed conditions inside a rule.
 *   - Multiple rules for the same table are evaluated with OR semantics.
 */

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

COMMENT ON TABLE abac_user_attributes IS
'Subject attribute table. Each PostgreSQL role/user can have attributes such as department, status, clearance, and salary_limit.';

CREATE TABLE IF NOT EXISTS abac_rules (
    rule_id bigserial PRIMARY KEY,
    rule_name text NOT NULL UNIQUE,
    table_name text NOT NULL,
    description text,
    created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE abac_rules IS
'One ABAC rule for a table. Multiple rules on the same table are OR-ed: access is granted if any rule is satisfied.';

CREATE TABLE IF NOT EXISTS abac_rule_conditions (
    condition_id bigserial PRIMARY KEY,
    rule_id bigint NOT NULL REFERENCES abac_rules(rule_id) ON DELETE CASCADE,
    condition_order integer NOT NULL DEFAULT 1,
    column_name text,
    user_attribute text NOT NULL,
    operator text NOT NULL DEFAULT '=',
    constant_value text,
    value_type text NOT NULL DEFAULT 'text',
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (upper(operator) IN ('=', '==', '!=', '<>', '>', '<', '>=', '<=', 'LIKE', 'NOT LIKE')),
    CHECK (value_type IN ('text', 'numeric')),
    CHECK (
        (column_name IS NOT NULL AND constant_value IS NULL)
        OR
        (column_name IS NULL AND constant_value IS NOT NULL)
    )
);

COMMENT ON TABLE abac_rule_conditions IS
'Conditions inside one ABAC rule. All conditions with the same rule_id are AND-ed.';

/* Backward-compatible view name for older scripts. */
CREATE OR REPLACE VIEW abac_policies AS
SELECT
    r.rule_id AS policy_id,
    r.rule_name AS policy_name,
    r.table_name,
    c.column_name,
    c.user_attribute,
    c.operator,
    c.constant_value,
    c.value_type,
    r.created_at
FROM abac_rules r
JOIN abac_rule_conditions c ON c.rule_id = r.rule_id;

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

CREATE OR REPLACE FUNCTION abac_add_rule(
    p_rule_name text,
    p_table_name text,
    p_description text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rule_id bigint;
BEGIN
    INSERT INTO abac_rules(rule_name, table_name, description)
    VALUES (p_rule_name, p_table_name, p_description)
    ON CONFLICT (rule_name)
    DO UPDATE SET
        table_name = EXCLUDED.table_name,
        description = EXCLUDED.description
    RETURNING rule_id INTO v_rule_id;

    RETURN v_rule_id;
END;
$$;

CREATE OR REPLACE FUNCTION abac_add_condition(
    p_rule_name text,
    p_column_name text,
    p_user_attribute text,
    p_operator text DEFAULT '=',
    p_constant_value text DEFAULT NULL,
    p_value_type text DEFAULT 'text',
    p_condition_order integer DEFAULT 1
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_rule_id bigint;
    v_condition_id bigint;
BEGIN
    SELECT rule_id INTO v_rule_id
    FROM abac_rules
    WHERE rule_name = p_rule_name;

    IF v_rule_id IS NULL THEN
        RAISE EXCEPTION 'ABAC rule % does not exist. Call abac_add_rule first.', p_rule_name;
    END IF;

    INSERT INTO abac_rule_conditions(
        rule_id,
        condition_order,
        column_name,
        user_attribute,
        operator,
        constant_value,
        value_type
    )
    VALUES (
        v_rule_id,
        p_condition_order,
        p_column_name,
        p_user_attribute,
        p_operator,
        p_constant_value,
        p_value_type
    )
    RETURNING condition_id INTO v_condition_id;

    RETURN v_condition_id;
END;
$$;


CREATE OR REPLACE FUNCTION abac_compare_values(
    p_left_value text,
    p_operator text,
    p_right_value text,
    p_value_type text DEFAULT 'text'
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    l_num numeric;
    r_num numeric;
BEGIN
    IF p_left_value IS NULL OR p_operator IS NULL OR p_right_value IS NULL THEN
        RETURN false;
    END IF;

    IF p_value_type = 'numeric' THEN
        BEGIN
            l_num := p_left_value::numeric;
            r_num := p_right_value::numeric;
        EXCEPTION WHEN invalid_text_representation THEN
            RETURN false;
        END;

        IF p_operator IN ('=', '==') THEN RETURN l_num = r_num; END IF;
        IF p_operator IN ('!=', '<>') THEN RETURN l_num <> r_num; END IF;
        IF p_operator = '>' THEN RETURN l_num > r_num; END IF;
        IF p_operator = '<' THEN RETURN l_num < r_num; END IF;
        IF p_operator = '>=' THEN RETURN l_num >= r_num; END IF;
        IF p_operator = '<=' THEN RETURN l_num <= r_num; END IF;
        RAISE EXCEPTION 'Unsupported ABAC numeric operator: %', p_operator;
    END IF;

    IF p_operator IN ('=', '==') THEN RETURN p_left_value = p_right_value; END IF;
    IF p_operator IN ('!=', '<>') THEN RETURN p_left_value <> p_right_value; END IF;
    IF p_operator = '>' THEN RETURN p_left_value > p_right_value; END IF;
    IF p_operator = '<' THEN RETURN p_left_value < p_right_value; END IF;
    IF p_operator = '>=' THEN RETURN p_left_value >= p_right_value; END IF;
    IF p_operator = '<=' THEN RETURN p_left_value <= p_right_value; END IF;
    IF upper(p_operator) = 'LIKE' THEN
        RETURN p_left_value LIKE p_right_value;
    END IF;

    IF upper(p_operator) = 'NOT LIKE' THEN
        RETURN p_left_value NOT LIKE p_right_value;
    END IF;
    RAISE EXCEPTION 'Unsupported ABAC text operator: %', p_operator;
END;
$$;

/*
 * Main generic RLS helper.
 * p_row_attrs is a JSONB object containing current row attributes, for example:
 * jsonb_build_object('dept_name', dept_name, 'salary', salary)
 *
 * Semantics:
 *   - Every condition within one rule must be true (AND).
 *   - At least one rule for the table must be true (OR).
 */
CREATE OR REPLACE FUNCTION abac_check_access(
    p_table_name text,
    p_row_attrs jsonb
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    r record;
    c record;
    left_value text;
    right_value text;
    rule_passed boolean;
    has_rule boolean := false;
BEGIN
    FOR r IN
        SELECT *
        FROM abac_rules
        WHERE table_name = p_table_name
        ORDER BY rule_id
    LOOP
        has_rule := true;
        rule_passed := true;

        FOR c IN
            SELECT *
            FROM abac_rule_conditions
            WHERE rule_id = r.rule_id
            ORDER BY condition_order, condition_id
        LOOP
            IF c.column_name IS NULL THEN
                /* user attribute compared to a constant, e.g. user.status = 'active' */
                left_value := abac_get_user_attribute(current_user, c.user_attribute);
                right_value := c.constant_value;
            ELSE
                /* row column compared to a user attribute, e.g. row.dept_name = user.department */
                left_value := p_row_attrs ->> c.column_name;
                right_value := abac_get_user_attribute(current_user, c.user_attribute);
            END IF;

            IF NOT abac_compare_values(left_value, c.operator, right_value, c.value_type) THEN
                rule_passed := false;
                EXIT;
            END IF;
        END LOOP;

        IF rule_passed THEN
            RETURN true;
        END IF;
    END LOOP;

    /* Fail closed: if no rule is defined for an RLS-protected table, deny access. */
    IF NOT has_rule THEN
        RETURN false;
    END IF;

    RETURN false;
END;
$$;

/* Older helper retained for compatibility with previous static demos. */
CREATE OR REPLACE FUNCTION abac_check_text(
    p_table_name text,
    p_column_name text,
    p_row_value text
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
    SELECT abac_check_access(p_table_name, jsonb_build_object(p_column_name, p_row_value))
$$;

COMMENT ON FUNCTION abac_check_access(text, jsonb) IS
'Generic ABAC RLS predicate. Conditions in one rule are AND-ed. Multiple rules per table are OR-ed. Supports equality, inequality, ordered numeric comparisons, LIKE, and NOT LIKE.';
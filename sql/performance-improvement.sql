CREATE INDEX IF NOT EXISTS idx_abac_user_attr_lookup
ON abac_user_attributes(username, attribute_name);

CREATE INDEX IF NOT EXISTS idx_student_dept
ON student(dept_name);

CREATE INDEX IF NOT EXISTS idx_course_dept
ON course(dept_name);

CREATE INDEX IF NOT EXISTS idx_instructor_dept
ON instructor(dept_name);

CREATE INDEX IF NOT EXISTS idx_instructor_salary
ON instructor(salary);

CREATE INDEX IF NOT EXISTS idx_course_credits
ON course(credits);

CREATE INDEX IF NOT EXISTS idx_abac_rules_table_enabled
ON abac_rules(table_name);

CREATE INDEX IF NOT EXISTS idx_abac_conditions_rule_order
ON abac_rule_conditions(rule_id, condition_order, condition_id);
-- Run after selecting the isolated assessment schema. MySQL 8.0+.
SELECT DATABASE() AS selected_database, VERSION() AS mysql_version;
SHOW TABLES;

-- Inspect actual columns and types before executing Task 1 assumptions.
SELECT TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = DATABASE()
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- Explicit counts; run only for tables that SHOW TABLES confirms exist.
SELECT 'departments' AS table_name, COUNT(*) AS row_count FROM departments
UNION ALL SELECT 'programs', COUNT(*) FROM programs
UNION ALL SELECT 'students', COUNT(*) FROM students
UNION ALL SELECT 'admissions', COUNT(*) FROM admissions
UNION ALL SELECT 'fee_transactions', COUNT(*) FROM fee_transactions
UNION ALL SELECT 'fee_transaction_details', COUNT(*) FROM fee_transaction_details;

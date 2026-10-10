-- TASK 1 — MySQL database and data processing
-- IMPORTANT: Task 1's input DDL is absent. Verify the assumed column contract
-- in README.md using verification.sql before running. These are not claimed as
-- executed against the missing dataset. Currency is treated as DECIMAL.

-- 1. Six-table population counts (execute only after confirming all tables).
SELECT 'departments' AS table_name, COUNT(*) AS row_count FROM departments
UNION ALL SELECT 'programs', COUNT(*) FROM programs
UNION ALL SELECT 'students', COUNT(*) FROM students
UNION ALL SELECT 'admissions', COUNT(*) FROM admissions
UNION ALL SELECT 'fee_transactions', COUNT(*) FROM fee_transactions
UNION ALL SELECT 'fee_transaction_details', COUNT(*) FROM fee_transaction_details;

-- 2. Duplicate admission numbers.
SELECT admission_no, COUNT(*) AS student_rows
FROM students
GROUP BY admission_no
HAVING COUNT(*) > 1
ORDER BY student_rows DESC, admission_no;

-- 3. Exact duplicate transactions. Date is included so payments of the same
-- type and amount on different days are not incorrectly called duplicates.
SELECT admission_id, transaction_type, amount, transaction_date,
       COUNT(*) AS duplicate_count,
       GROUP_CONCAT(transaction_id ORDER BY transaction_id) AS transaction_ids
FROM fee_transactions
GROUP BY admission_id, transaction_type, amount, transaction_date
HAVING COUNT(*) > 1
ORDER BY admission_id, transaction_date;

-- 4. Students with a positive current due. Assumption: DUE parent rows are
-- charges and PAID/CONCESSION rows are credits; verify status/type semantics.
WITH balances AS (
  SELECT admission_id,
         SUM(CASE
               WHEN UPPER(transaction_type) = 'DUE' THEN COALESCE(amount, 0)
               WHEN UPPER(transaction_type) IN ('PAID', 'CONCESSION') THEN -COALESCE(amount, 0)
               ELSE 0
             END) AS outstanding_amount
  FROM fee_transactions
  GROUP BY admission_id
)
SELECT a.admission_no, s.student_id, s.admission_no AS student_admission_no,
       b.outstanding_amount
FROM balances b
JOIN admissions a ON a.admission_id = b.admission_id
LEFT JOIN students s ON s.student_id = a.student_id
WHERE b.outstanding_amount > 0
ORDER BY b.outstanding_amount DESC, a.admission_no;

-- 5. Due by admission number, combining admissions that share the number.
WITH balances AS (
  SELECT a.admission_no,
         SUM(CASE
               WHEN UPPER(ft.transaction_type) = 'DUE' THEN COALESCE(ft.amount, 0)
               WHEN UPPER(ft.transaction_type) IN ('PAID', 'CONCESSION') THEN -COALESCE(ft.amount, 0)
               ELSE 0
             END) AS outstanding_amount
  FROM admissions a
  LEFT JOIN fee_transactions ft ON ft.admission_id = a.admission_id
  GROUP BY a.admission_no
)
SELECT admission_no, outstanding_amount
FROM balances
WHERE outstanding_amount > 0
ORDER BY outstanding_amount DESC, admission_no;

-- 6. Top 10 students by total PAID transaction amount. Aggregate parent rows
-- before joining details to avoid parent/detail join multiplication.
SELECT a.admission_no, s.student_id, SUM(ft.amount) AS total_paid
FROM fee_transactions ft
JOIN admissions a ON a.admission_id = ft.admission_id
LEFT JOIN students s ON s.student_id = a.student_id
WHERE UPPER(ft.transaction_type) = 'PAID'
GROUP BY a.admission_no, s.student_id
ORDER BY total_paid DESC, a.admission_no
LIMIT 10;

-- 7. Program collections (PAID parents only); each parent transaction maps
-- through its admission to one program. Confirm this relationship in the DDL.
SELECT p.program_id, p.program_name, SUM(ft.amount) AS total_fee_collected
FROM fee_transactions ft
JOIN admissions a ON a.admission_id = ft.admission_id
JOIN programs p ON p.program_id = a.program_id
WHERE UPPER(ft.transaction_type) = 'PAID'
GROUP BY p.program_id, p.program_name
ORDER BY total_fee_collected DESC, p.program_name;

-- 8. Parent/detail amount mismatch; pre-aggregate detail rows per parent.
WITH detail_totals AS (
  SELECT transaction_id, COUNT(*) AS detail_count,
         SUM(COALESCE(amount, 0)) AS detail_amount
  FROM fee_transaction_details
  GROUP BY transaction_id
)
SELECT ft.transaction_id, a.admission_no, ft.amount AS parent_amount,
       COALESCE(dt.detail_count, 0) AS detail_count,
       COALESCE(dt.detail_amount, 0) AS detail_amount,
       ft.amount - COALESCE(dt.detail_amount, 0) AS difference
FROM fee_transactions ft
JOIN admissions a ON a.admission_id = ft.admission_id
LEFT JOIN detail_totals dt ON dt.transaction_id = ft.transaction_id
WHERE ABS(COALESCE(ft.amount, 0) - COALESCE(dt.detail_amount, 0)) >= 0.01
ORDER BY ft.transaction_id;

-- 9. Parents without child details.
SELECT ft.transaction_id, a.admission_no, ft.transaction_type, ft.amount,
       ft.transaction_date
FROM fee_transactions ft
JOIN admissions a ON a.admission_id = ft.admission_id
WHERE NOT EXISTS (
  SELECT 1 FROM fee_transaction_details d
  WHERE d.transaction_id = ft.transaction_id
)
ORDER BY ft.transaction_id;

-- 10. Orphan details (works where the schema permits them).
SELECT d.detail_id, d.transaction_id, d.fee_head, d.amount
FROM fee_transaction_details d
WHERE NOT EXISTS (
  SELECT 1 FROM fee_transactions ft
  WHERE ft.transaction_id = d.transaction_id
)
ORDER BY d.transaction_id, d.detail_id;

-- 11. Admission-level reconciliation. Parent transactions and detail lines
-- are counted independently; one-sided admissions remain in the result.
WITH parent_by_admission AS (
  SELECT a.admission_no, COUNT(ft.transaction_id) AS transaction_count,
         SUM(COALESCE(ft.amount, 0)) AS transaction_amount
  FROM admissions a
  LEFT JOIN fee_transactions ft ON ft.admission_id = a.admission_id
  GROUP BY a.admission_no
),
details_by_admission AS (
  SELECT a.admission_no, COUNT(d.detail_id) AS detail_count,
         SUM(COALESCE(d.amount, 0)) AS detail_amount
  FROM admissions a
  JOIN fee_transactions ft ON ft.admission_id = a.admission_id
  JOIN fee_transaction_details d ON d.transaction_id = ft.transaction_id
  GROUP BY a.admission_no
),
all_admissions AS (
  SELECT admission_no FROM parent_by_admission
  UNION SELECT admission_no FROM details_by_admission
)
SELECT x.admission_no AS `Admission Number`,
       COALESCE(p.transaction_count, 0) AS `Transaction Count`,
       COALESCE(p.transaction_amount, 0.00) AS `Transaction Amount`,
       COALESCE(d.detail_count, 0) AS `Detail Count`,
       COALESCE(d.detail_amount, 0.00) AS `Detail Amount`,
       COALESCE(p.transaction_amount, 0.00) - COALESCE(d.detail_amount, 0.00) AS Difference
FROM all_admissions x
LEFT JOIN parent_by_admission p ON p.admission_no = x.admission_no
LEFT JOIN details_by_admission d ON d.admission_no = x.admission_no
ORDER BY x.admission_no;

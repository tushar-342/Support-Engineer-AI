-- TASK 3 — standalone parent/child reconciliation, MySQL 8.0+
-- Uses the exact columns stated in the assignment. Parent records are unique
-- transactions; child lines can repeat admission_no across fee heads/transactions.

-- 1. Confirm tables/counts. SHOW TABLES and information_schema inspection are
-- in verification.sql; counts below require both expected tables to exist.
SELECT 'FINANCIAL_TRANSACTION' AS table_name, COUNT(*) AS row_count
FROM FINANCIAL_TRANSACTION
UNION ALL
SELECT 'FINANCIAL_TRANSACTION_DETAIL', COUNT(*)
FROM FINANCIAL_TRANSACTION_DETAIL;

-- 2. A local source file is required for independent loaded-without-loss proof.
-- These checks expose basic content fingerprints for comparison with its source.
SELECT 'parent' AS side, COUNT(*) AS row_count,
       COUNT(DISTINCT transaction_id) AS distinct_ids,
       MIN(transaction_id) AS min_id, MAX(transaction_id) AS max_id,
       SUM(COALESCE(total_amount, 0)) AS amount_sum
FROM FINANCIAL_TRANSACTION
UNION ALL
SELECT 'child', COUNT(*), COUNT(DISTINCT detail_id), MIN(detail_id), MAX(detail_id),
       SUM(COALESCE(amount, 0))
FROM FINANCIAL_TRANSACTION_DETAIL;

-- 3. Compare amounts per parent transaction; parents without children appear.
WITH child_by_tx AS (
  SELECT transaction_id, COUNT(*) AS detail_count,
         SUM(COALESCE(amount, 0)) AS child_amount
  FROM FINANCIAL_TRANSACTION_DETAIL
  GROUP BY transaction_id
)
SELECT p.transaction_id, p.admission_no, p.total_amount AS parent_amount,
       COALESCE(c.detail_count, 0) AS detail_count,
       COALESCE(c.child_amount, 0.00) AS child_amount,
       COALESCE(p.total_amount, 0.00) - COALESCE(c.child_amount, 0.00) AS difference,
       CASE WHEN ABS(COALESCE(p.total_amount, 0) - COALESCE(c.child_amount, 0)) < 0.01
            THEN 'MATCH' ELSE 'MISMATCH' END AS amount_status
FROM FINANCIAL_TRANSACTION p
LEFT JOIN child_by_tx c ON c.transaction_id = p.transaction_id
ORDER BY p.transaction_id;

-- 4-5. Admission-level amounts and distinct transaction counts. Union keys
-- preserve child-only admissions, including orphan child rows.
WITH parent_by_admission AS (
  SELECT admission_no, COUNT(*) AS parent_count,
         SUM(COALESCE(total_amount, 0)) AS parent_amount
  FROM FINANCIAL_TRANSACTION
  GROUP BY admission_no
),
child_by_admission AS (
  SELECT admission_no, COUNT(DISTINCT transaction_id) AS child_count,
         SUM(COALESCE(amount, 0)) AS child_amount
  FROM FINANCIAL_TRANSACTION_DETAIL
  GROUP BY admission_no
),
all_admissions AS (
  SELECT admission_no FROM parent_by_admission
  UNION
  SELECT admission_no FROM child_by_admission
),
reconciled AS (
  SELECT a.admission_no,
         COALESCE(p.parent_amount, 0.00) AS parent_amount,
         COALESCE(c.child_amount, 0.00) AS child_amount,
         COALESCE(p.parent_count, 0) AS parent_count,
         COALESCE(c.child_count, 0) AS child_count
  FROM all_admissions a
  LEFT JOIN parent_by_admission p ON p.admission_no = a.admission_no
  LEFT JOIN child_by_admission c ON c.admission_no = a.admission_no
)
SELECT admission_no AS `Admission No`, parent_amount AS `Parent Amount`,
       child_amount AS `Child Amount`, parent_amount - child_amount AS Difference,
       parent_count AS `Parent Count`, child_count AS `Child Count`,
       CASE WHEN ABS(parent_amount - child_amount) < 0.01
                  AND parent_count = child_count
            THEN 'MATCH' ELSE 'MISMATCH' END AS Status
FROM reconciled
ORDER BY admission_no;

-- 5. All admission-level amount and/or count mismatches.
WITH p AS (
  SELECT admission_no, COUNT(*) AS parent_count,
         SUM(COALESCE(total_amount, 0)) AS parent_amount
  FROM FINANCIAL_TRANSACTION GROUP BY admission_no
),
c AS (
  SELECT admission_no, COUNT(DISTINCT transaction_id) AS child_count,
         SUM(COALESCE(amount, 0)) AS child_amount
  FROM FINANCIAL_TRANSACTION_DETAIL GROUP BY admission_no
),
k AS (SELECT admission_no FROM p UNION SELECT admission_no FROM c)
SELECT k.admission_no, COALESCE(p.parent_amount, 0) AS parent_amount,
       COALESCE(c.child_amount, 0) AS child_amount,
       COALESCE(p.parent_count, 0) AS parent_count,
       COALESCE(c.child_count, 0) AS child_count
FROM k LEFT JOIN p USING (admission_no) LEFT JOIN c USING (admission_no)
WHERE ABS(COALESCE(p.parent_amount, 0) - COALESCE(c.child_amount, 0)) >= 0.01
   OR COALESCE(p.parent_count, 0) <> COALESCE(c.child_count, 0)
ORDER BY k.admission_no;

-- 6a. Parents with no children.
SELECT p.* FROM FINANCIAL_TRANSACTION p
WHERE NOT EXISTS (
  SELECT 1 FROM FINANCIAL_TRANSACTION_DETAIL c
  WHERE c.transaction_id = p.transaction_id
)
ORDER BY p.transaction_id;

-- 6b. Orphan child rows: retained in child-side totals above.
SELECT c.* FROM FINANCIAL_TRANSACTION_DETAIL c
WHERE NOT EXISTS (
  SELECT 1 FROM FINANCIAL_TRANSACTION p
  WHERE p.transaction_id = c.transaction_id
)
ORDER BY c.transaction_id, c.detail_id;

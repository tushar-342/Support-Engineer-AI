-- TASK 2 — ADM10025 payment investigation
-- Task 1 schema is unavailable. Verify the identifier and status columns/types
-- against the real DDL before execution; identifiers follow README's contract.

-- 1. Inspect all admission rows and their student/program links.
SELECT a.* FROM admissions a WHERE a.admission_no = 'ADM10025';

-- 2. Inspect parent transaction chronology, amounts, and types.
SELECT ft.*
FROM fee_transactions ft
JOIN admissions a ON a.admission_id = ft.admission_id
WHERE a.admission_no = 'ADM10025'
ORDER BY ft.transaction_date, ft.transaction_id;

-- 3. Inspect child detail rows without filtering away unexpected fee heads.
SELECT d.*
FROM fee_transaction_details d
JOIN fee_transactions ft ON ft.transaction_id = d.transaction_id
JOIN admissions a ON a.admission_id = ft.admission_id
WHERE a.admission_no = 'ADM10025'
ORDER BY ft.transaction_date, ft.transaction_id, d.detail_id;

-- 4. Compare each parent to the aggregate of its children.
WITH detail_totals AS (
  SELECT transaction_id, COUNT(*) AS detail_count,
         SUM(COALESCE(amount, 0)) AS detail_amount,
         GROUP_CONCAT(CONCAT(COALESCE(fee_head, '<NULL>'), ':', amount)
                      ORDER BY detail_id SEPARATOR '; ') AS fee_head_lines
  FROM fee_transaction_details
  GROUP BY transaction_id
)
SELECT ft.transaction_id, a.admission_no, ft.transaction_type,
       ft.amount AS parent_amount, COALESCE(dt.detail_count, 0) AS detail_count,
       COALESCE(dt.detail_amount, 0) AS detail_amount,
       ft.amount - COALESCE(dt.detail_amount, 0) AS difference,
       dt.fee_head_lines
FROM fee_transactions ft
JOIN admissions a ON a.admission_id = ft.admission_id
LEFT JOIN detail_totals dt ON dt.transaction_id = ft.transaction_id
WHERE a.admission_no = 'ADM10025'
ORDER BY ft.transaction_id;

-- 5. Check duplicate transaction keys, including date.
SELECT admission_id, transaction_type, amount, transaction_date,
       COUNT(*) AS occurrences, GROUP_CONCAT(transaction_id) AS transaction_ids
FROM fee_transactions ft
JOIN admissions a ON a.admission_id = ft.admission_id
WHERE a.admission_no = 'ADM10025'
GROUP BY admission_id, transaction_type, amount, transaction_date
HAVING COUNT(*) > 1;

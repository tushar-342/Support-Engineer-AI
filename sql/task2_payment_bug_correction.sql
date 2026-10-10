-- TASK 2 — guarded correction review template
-- DO NOT run a financial correction based only on the ticket's reported values.
-- First execute task2_payment_bug_investigation.sql, verify the exact missing
-- fee head against payment allocation/gateway evidence, confirm the real DDL,
-- and obtain finance approval. This file intentionally performs NO INSERT or
-- UPDATE: the dataset, fee-head allocation, and target transaction are absent.
-- Once verified, prepare a reviewed migration with:
--   1. backup/export of the target parent and all its children;
--   2. START TRANSACTION;
--   3. SELECT ... FOR UPDATE for the exact parent;
--   4. abort unless admission, paid status, amount, and existing detail sum
--      still match the approved preconditions;
--   5. insert the verified missing allocation using the actual required columns
--      (allowing the database to generate the detail key);
--   6. verify exactly one row inserted and new child sum equals parent amount;
--   7. COMMIT only after independent verification, otherwise ROLLBACK.
-- Do not invent a fee head or mark a payment settled to force reconciliation.

SELECT 'Correction not executable: source data and verified allocation required'
       AS review_gate;

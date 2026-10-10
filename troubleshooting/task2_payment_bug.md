# Task 2: ADM10025 payment discrepancy

## Evidence and finding

The assignment states that ADM10025 paid ₹15,000 and still shows ₹5,000 due. This is a symptom, not enough evidence by itself to identify the specific bad row or missing fee head. The referenced Task 1 SQL file is not present, so the actual parent/detail rows, status values, and table constraints could not be inspected. The root cause is therefore **unverified**. A parent-to-child allocation gap is one plausible cause, but it must be demonstrated by `sql/task2_payment_bug_investigation.sql` before any correction.

## Investigation

Run the investigation script in an isolated database after confirming the actual DDL. It fetches every admission row, all parent transactions and all corresponding detail lines, then compares each parent amount to a pre-aggregated detail amount and checks exact duplicate keys including transaction date. Review status/type semantics and payment gateway allocation evidence before interpreting a mismatch.

## Correction and prevention

`sql/task2_payment_bug_correction.sql` is a review gate only. No missing fee head, row identifier, or settlement state can safely be inferred from the ticket. If source evidence confirms a missing allocation, prepare a transaction-scoped correction against the real schema: lock and re-read the exact parent, verify admission/status/amount and current details, insert only the approved allocation, confirm exactly one insert and balanced totals, then commit. Any changed precondition, duplicate key, failed check, or unknown allocation must roll back. Preserve an export/backup and have Finance approve the allocation. Prevention includes atomic parent-plus-detail writes, foreign keys, generated child IDs, idempotency keys, reconciliation alerts, and no due calculation from partially committed detail rows.

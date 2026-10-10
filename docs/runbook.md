# Support and reconciliation runbook

## Before execution

1. Use disposable MySQL schemas and obtain the original dataset files.
2. Record MySQL version, selected database, table list, and exact columns/types using `sql/verification.sql`.
3. Compare the actual Task 1 DDL with the documented working assumptions. Correct identifiers and type semantics before running the Task 1 queries.
4. Keep source SQL files unchanged and preserve a copy of the disposable database before any correction experiment.

## Investigating payment discrepancies

Run `sql/task2_payment_bug_investigation.sql`. Compare all parent transactions and child lines for the admission, including statuses, fee heads, dates, and gateway/payment identifiers. Confirm the claimed payment against gateway evidence. Establish whether the difference is a missing detail, duplicate, wrong allocation, or another cause. Do not infer a fee head from the balance difference alone.

## Applying a correction

The checked-in correction file is intentionally non-mutating because the source rows and allocation are unavailable. For an approved correction, create a reviewed script for the verified schema. Export the target parent and children; start a transaction; lock and re-read the exact rows; assert all preconditions; insert only the source-verified allocation; verify one insertion and balanced amounts; commit only if every check passes. Roll back on any unexpected state. Keep the export and change/audit reference. Do not update payment status to make totals agree.

## Reconciliation and API recovery

Run Task 1/3 reconciliation queries and investigate every mismatch, missing-child parent, and orphan. For a gateway-success/database-missing payment, inspect the gateway by its existing payment ID/reference and the local payment/idempotency ledger. Search for duplicate or partial records. Reconcile that same gateway event once; never charge again merely because persistence failed. For lock timeouts, inspect lock waits and long-running transactions, roll back the full unit, and retry only bounded idempotent work after checking state.

## Post-fix

Re-run the exact parent/detail and admission-level reconciliations, confirm due calculation against the authoritative balance logic, verify API response and persisted rows, and retain query outputs plus the change reference. Monitor gateway-success/database-missing, transaction rollback, duplicate-key, lock timeout, and reconciliation mismatch metrics.

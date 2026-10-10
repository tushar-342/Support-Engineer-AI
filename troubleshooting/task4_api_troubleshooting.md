# Task 4: API troubleshooting

## Scenario A — ADM10025 returns HTTP 200 with an incorrect balance

**Facts in the supplied log:** payment gateway returned success for PAY45872; parent transaction 518 was logged for ₹15,000; Tuition Fee detail ₹10,000 inserted; Exam Fee detail ₹5,000 failed on duplicate `detail_id_seq` value 3024; the exception was caught without transaction rollback; controller returned HTTP 200 success; due job used detail aggregation and computed ₹5,000 due.

**Likely cause and category:** application transaction/error-handling defect, with a database key collision as the immediate trigger. The application allowed a partial parent/detail write to appear successful. The logs strongly support this chain; actual persisted rows still need database verification. The duplicate sequence generator may be misconfigured or out of sync, but its underlying cause is not proven by the log alone.

Verify using the real schema (identifiers below reflect the assignment's Task 1 naming):

```sql
SELECT ft.transaction_id, a.admission_no, ft.transaction_type, ft.amount,
       COUNT(d.detail_id) AS detail_count, COALESCE(SUM(d.amount), 0) AS detail_amount,
       ft.amount - COALESCE(SUM(d.amount), 0) AS difference
FROM fee_transactions ft
JOIN admissions a ON a.admission_id = ft.admission_id
LEFT JOIN fee_transaction_details d ON d.transaction_id = ft.transaction_id
WHERE ft.transaction_id = 518 AND a.admission_no = 'ADM10025'
GROUP BY ft.transaction_id, a.admission_no, ft.transaction_type, ft.amount;

SELECT * FROM fee_transaction_details WHERE transaction_id = 518 ORDER BY detail_id;
SELECT * FROM fee_transactions WHERE transaction_id = 518;
```

Write the parent and all detail rows in one database transaction. On any detail failure, roll back the entire unit and report failure/pending status. Allocate IDs from the database's supported mechanism and inspect/fix the sequence only after confirming its source. Enforce a unique gateway payment/idempotency key so retries return the original payment outcome rather than creating another charge. Return success only after durable commit; if gateway capture succeeded but persistence failed, return an explicit pending/reconciliation outcome (or server error with a safe retry contract), never a false success. Log trace ID, payment ID, gateway reference, DB transaction outcome, and sanitized failure reason; alert on gateway-success/database-missing and parent/detail imbalance.

Tests: successful multi-line payment; forced failure on second detail and full rollback; duplicate child ID; repeated same idempotency key; concurrent retry; gateway success plus DB failure; and subsequent reconciliation/recovery without a second charge. Assert HTTP response and persisted rows together.

## Scenario B — ADM10089 returns HTTP 500

**Facts in supplied log:** gateway reported success for PAY51190; insert into `fee_transactions` hit a lock-wait timeout after roughly 30 seconds; controller returned HTTP 500; reconciliation found no matching fee transaction. The log does not identify the blocking transaction, the table engine, transaction age, or whether gateway capture was later reversed.

**Likely cause and category:** database contention/transaction lock timeout surfaced as an unhandled application error. This is a database-triggered failure with an application recovery/idempotency gap. The exact blocker and whether any partial side effects exist remain hypotheses until inspected.

Database-side checks (adapt key/payment columns to actual DDL):

```sql
SELECT * FROM fee_transactions WHERE admission_id IN
  (SELECT admission_id FROM admissions WHERE admission_no = 'ADM10089')
ORDER BY transaction_date DESC;
SHOW ENGINE INNODB STATUS;
SELECT * FROM information_schema.innodb_trx ORDER BY trx_started;
SELECT * FROM performance_schema.data_lock_waits;
SELECT * FROM performance_schema.data_locks;
```

Also inspect the gateway ledger for PAY51190 and its gateway reference, database audit/application logs, and any idempotency/payment table; search for duplicates and partial details. Capture blocker SQL, transaction start time, isolation level, and lock wait graph. Reduce transaction scope and time spent holding locks; keep gateway calls outside DB transactions. Handle lock timeout/deadlock by rolling back the whole DB transaction. Retry only a bounded number of times with jittered backoff when the operation is idempotent and the payment's existing state has been checked.

Recovery: query gateway state by the existing payment ID/reference; verify it was captured and not refunded/reversed; query DB and audit logs for partial persistence; then record/reconcile that same gateway payment once using its unique idempotency key in a transaction. Do not charge the student again. If safe persistence cannot be established, leave it pending and route to finance/support for reconciliation. Test lock contention, deadlock, timeout, gateway success with DB rollback, duplicate recovery attempt, and eventual single-record reconciliation.

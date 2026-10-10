# Support Engineer AI Technical Assignment

This repository contains an SQL-first submission for the iCloudEMS support engineering assessment. The assignment document is supplied in the conversation, but the two SQL datasets it names are not available in this checkout or the provided attachments. The schema of the six Task 1 tables is therefore unverified. Queries that depend on those columns are marked with their assumed column contract; no result, row count, or correction is presented as dataset-derived.

## Contents

- `sql/task1_database_processing.sql` — Task 1 queries (requires column-name verification against the missing dataset).
- `sql/task2_payment_bug_investigation.sql` and `sql/task2_payment_bug_correction.sql` — investigation and guarded correction workflow.
- `sql/task3_reconciliation.sql` — Task 3 checks using the column names stated in the assignment.
- `sql/verification.sql` — reusable database and table inspection queries.
- `troubleshooting/` — evidence-based Task 2, Task 4, and Task 5 reports.
- `docs/runbook.md` — safe execution, correction, and recovery procedures.
- `reports/execution_report.md` — environment checks and actual execution status.
- `reports/query_results/` — reserved for real exports; currently no dataset outputs are claimed.

## Prerequisites

- MySQL 8.0 or compatible (CTEs and window functions are used where noted).
- The original files `task1_university_erp_dataset.sql` and `task3_reconciliation_dataset.sql`.
- An isolated disposable database. Do not load assessment data into production.

The SQL assumes Task 1 names `admissions.admission_id`, `admissions.admission_no`, `admissions.student_id`, `admissions.program_id`; `students.student_id`, `students.admission_no`; `programs.program_id`, `programs.program_name`, `programs.department_id`; `departments.department_id`, `departments.department_name`; `fee_transactions.transaction_id`, `admission_id`, `transaction_type`, `amount`, `transaction_date`; and `fee_transaction_details.detail_id`, `transaction_id`, `fee_head`, `amount`. Verify the actual DDL first and adjust identifiers/types if they differ. This contract is a working assumption, not a discovered schema.

## Loading and running

Create a disposable schema, then load each self-contained input into separate schemas because both scripts may create overlapping table names. For example, from a MySQL client with appropriate local credentials:

```sql
CREATE DATABASE assignment_task1;
CREATE DATABASE assignment_task3;
```

Load `task1_university_erp_dataset.sql` while connected to `assignment_task1`; load `task3_reconciliation_dataset.sql` while connected to `assignment_task3`. Inspect DDL and counts with `sql/verification.sql`, then run the matching task script. Run Task 2 correction only after review, business approval, and the preconditions in that script are satisfied.

Task 3 uses the supplied exact column names: `FINANCIAL_TRANSACTION(transaction_id, admission_no, transaction_date, total_amount, status)` and `FINANCIAL_TRANSACTION_DETAIL(detail_id, transaction_id, admission_no, fee_head, amount, status)`. Check whether the source uses case-sensitive identifiers or different numeric types before execution.

## Assignment checklist

- [x] Task 1: labeled queries drafted for all 11 requirements; dataset execution pending actual input and DDL.
- [x] Task 2: evidence-based investigation and conditional correction procedure drafted; actual student records and fee-head mapping unavailable.
- [x] Task 3: reconciliation queries drafted against the stated schema; dataset execution and independent load validation pending input.
- [x] Task 4: both supplied log scenarios analyzed with verification and test plans.
- [x] Task 5: stale retrieved context analyzed and reliability controls/test cases documented.
- [ ] Execute all dataset SQL, export real results, and validate correction on disposable data once datasets and a running MySQL server are available.

See `reports/execution_report.md` for the checks actually performed and current blockers.

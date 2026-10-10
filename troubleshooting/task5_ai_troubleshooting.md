# Task 5: AI balance answer troubleshooting

## Evidence-based assessment

The supplied live database value is ₹8,500; the assistant's retrieved context already says ₹12,500 and is timestamped 2025-09-15 23:00 IST. Since the model repeated the stale context, the strongest evidence points to stale data retrieval/context generation (cache, snapshot, or RAG freshness), rather than a value invented by the LLM. The live value and context are supplied facts in the assignment; access to the production database and the retrieval pipeline was not available for independent validation.

## Trace and investigation checklist

Trace one request with a correlation ID across: user query and extracted admission number; AI application; data API and SQL; authoritative database value and as-of time; cache/snapshot or vector retrieval; context construction and provenance; model prompt/input; model output and final response. Record the retrieved document ID, source, admission key, snapshot timestamp and timezone, cache age, SQL parameters/result, and model version.

- Validate SQL joins, filters, aggregation, and parameter binding for exact admission-number matching.
- Check cache TTL, invalidation after payment, replication lag, and snapshot-generation schedule.
- Normalize timestamps and display timezone; reject over-age balance snapshots.
- Inspect retrieval filters, tenant/university scope, admission identifier, stale documents and embedding refresh if a vector store is used.
- Verify context provenance and detect conflicting balance values before prompting.
- Review prompt instructions and ensure the model is told to abstain when authoritative data is unavailable.
- Validate output amount/admission against the tool result before returning it.
- Emit trace IDs, retrieval freshness, source version, and outcome metrics; never log unnecessary personal data.

## Recommended fix and tests

Treat a current balance as structured financial data, not a semantic-search answer. Fetch it from an authoritative, parameterized balance API/SQL source at answer time, include an `as_of` timestamp and admission number, enforce a freshness threshold, and validate the final answer against that exact result. If the authoritative source is unavailable or stale, say the balance cannot currently be verified. Do not calculate a live balance from stale narrative context.

Regression cases: current ₹8,500 with stale ₹12,500 retrieval must return ₹8,500 from the authoritative tool; missing admission returns not found; similar/incorrect admission must not cross-match; database outage returns a safe unavailable response; contradictory retrieved context is ignored or escalated; stale snapshot exceeds threshold and triggers refresh/abstention; and valid fresh source returns the correct amount with provenance.

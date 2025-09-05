## Background
Track C (Data Layer) has landed (SQLite.swift + migrations + encrypted connections). AI suggestions caching was deferred until the AI response schema is finalized. This issue proposes the table design and usage plan for `ai_suggestions`.

## Goals
- Define a forward-compatible schema for storing AI suggestions
- Enable deterministic cache lookups via input hash and context fingerprint
- Support analytics: acceptance rate, model/provider, latency
- Provide clear CRUD/service APIs and pruning strategy

## Proposed Schema (v1)
Table: `ai_suggestions`
- `id` TEXT PRIMARY KEY (UUID)
- `input_hash` TEXT NOT NULL (normalized query + minimal context; indexed)
- `query` TEXT NOT NULL (raw user query)
- `context_json` TEXT NULL (JSON-serialized context, e.g., working dir, OS, session meta)
- `suggestion` TEXT NOT NULL (rendered command or JSON for composite suggestions)
- `confidence` REAL NULL
- `accepted` BOOLEAN NOT NULL DEFAULT 0
- `model_id` TEXT NULL (e.g., gpt-4o-mini-2024-xx, local-ml-v1)
- `provider` TEXT NULL (apple-intelligence/openai/claude/local)
- `latency_ms` INTEGER NULL
- `created_at_ms` INTEGER NOT NULL (Unix ms)
- `expires_at_ms` INTEGER NULL (TTL for cache)

Indexes:
- `idx_ai_suggestions_input_hash` on (`input_hash`, `created_at_ms` DESC)
- `idx_ai_suggestions_expires` on (`expires_at_ms`)

Constraints:
- Optionally UNIQUE(`input_hash`, `model_id`, `provider`) to avoid duplicates across providers

Migration note:
- Current placeholder table lacks timestamps. Plan migration v2 to add `created_at_ms`, `expires_at_ms`, and new columns.

## Security
- Suggestions themselves are generally non-sensitive; however, if `context_json` could contain secrets, encrypt it using AES-GCM (same Keychain-backed key used for connections).
- Do not log plaintext secrets.

## Service/API Surface (Data layer)
- `putSuggestion(entry)`: upsert by (input_hash, model_id, provider)
- `getSuggestions(input_hash, limit=N)`: return most recent suggestions
- `markAccepted(id, accepted: Bool)`: analytics toggle
- `pruneExpired(now)` and `pruneByCapacity(maxRows)`

## Caching Strategy
- TTL: default 7 days (configurable)
- Capacity guard: e.g., 5k rows (LRU prune by created_at_ms)
- Cache key: SHA256(normalized query + minimal context fingerprint)

## Usage Flow
1. On NL input: compute `input_hash` from normalized query + minimal context (OS, shell, cwd).
2. Try cache: if hits, show top suggestions (sorted by confidence/created_at).
3. On miss: call AI Engine -> store suggestion(s) with model/provider/latency metrics.
4. When user executes suggestion: mark `accepted = 1`, update acceptance analytics.

## Open Questions
- Should we store multiple variants (top-k) per input or only the top-1?
- Need embeddings / vector search in future? (could add `embedding` BLOB + Annoy/FAISS external index later)
- iCloud sync: do we sync ai_suggestions? If yes, how to handle merges and TTL?
- Prompt versioning: include `prompt_version` to avoid stale cache after prompt updates.

## Acceptance Criteria
- Reviewed and agreed schema + indexes + API
- Migration plan drafted (v2)
- Data layer tasks created to implement CRUD + pruning (behind feature flag)


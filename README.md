# Legal Research & Similarity Finder

An agentic legal research workspace focused on Nepalese law. It searches configured legal sources on the live web, retrieves and sanitizes source pages, extracts provision references, indexes retrieved judgments for semantic similarity, and produces a report linked to the pages it actually fetched.

This is not legal advice. Results depend on external search coverage, source availability, and the local embedding model. No cases or legislation are bundled as real sample data.

## Architecture

- `frontend/`: Next.js App Router, TypeScript, Tailwind CSS, responsive research and report UI.
- `backend/app/agent/`: conditional research orchestration, web/legal search, safe retrieval, citation generation, and evidence-limited LLM synthesis.
- `backend/app/config.py`: configurable trusted-source allowlist; defaults prioritize the Nepal Law Commission, Supreme Court of Nepal, and government domains.
- `backend/app/retrieval/`: persistent Chroma vector search with local sentence embeddings.
- `backend/app/ingestion/`: text cleaning/chunking and verified JSONL ingestion.
- `backend/app/database/`: optional PostgreSQL report-history repository, scoped to a signed HttpOnly workspace cookie.
- `backend/tests/`: API, search filtering, extraction, citation, and chunking tests.

```text
Browser -> Next.js -> FastAPI research agent
                         |-> live web search (DDGS or Brave)
                         |-> HTTPS retrieval restricted to configured hosts
                         |-> provision extraction and citations
                         |-> ChromaDB + local embedding model for case similarity
                         |-> optional OpenAI-compatible, evidence-only synthesis
```

## Requirements

- Python 3.11+ recommended (Python 3.14 was used for basic API and unit checks; Chroma's embedding backend may require a supported ONNX Runtime wheel).
- Node.js 20.9+ and npm for the Next.js app.
- Network access for web search, source retrieval, and first-time model download.
- Optional PostgreSQL URL for server-side report history, an LLM API key for synthesis, and a Brave Search key for keyed web search.

## Run locally

### One-command launch

From the project root in PowerShell, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run.ps1
```

The launcher creates the backend virtual environment if needed, installs missing dependencies, and opens the API and web app in separate command windows. Node.js 20.9+ and Python with the `py` launcher must be installed. The portable Node runtime downloaded earlier is also detected if it remains in the Windows temp directory.

### Manual launch

1. Copy `.env.example` to `backend/.env` and configure optional service keys. Keep all secrets on the backend.
2. Install and run the API:

   ```powershell
   cd backend
   py -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements-dev.txt
   uvicorn app.main:app --reload --port 8000
   ```

3. In another terminal, configure the browser API URL in `frontend/.env.local` if it differs from the default:

   ```text
   NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
   ```

4. Install and run the frontend:

   ```powershell
   cd frontend
   npm install
   npm run dev
   ```

Open `http://localhost:3000`. The backend health check is at `http://localhost:8000/health`.

## Environment

`LLM_API_KEY` is optional; without it, the agent builds a citation-linked answer from extracted provisions, indexed cases, and retrieved source excerpts. If sources do not verify a rule or holding, it says so instead of guessing. The endpoint must be OpenAI-compatible and can be changed with `LLM_BASE_URL` and `LLM_MODEL`.

Search uses the free DDGS provider by default. Set `SEARCH_PROVIDER=brave` and `SEARCH_API_KEY` to use Brave Search. Search results are filtered against the configured domain allowlist before retrieval. Add approved sources with `LEGAL_SOURCES_JSON` as documented in `.env.example`.

`VECTOR_DB_PATH` defaults to `./data/chroma` (relative to the backend working directory). The first semantic search can download Chroma's local sentence embedding model. If model initialization fails, semantic matches are omitted and the report explains the limitation.

## How the agent works

1. Validates the question, keywords, and jurisdiction input.
2. Chooses how many configured domains to search based on the issue terms; it does not run unrelated tools or perform arbitrary URL retrieval.
3. Searches each selected trusted domain with DDGS or Brave. Non-allowlisted results are discarded.
4. Retrieves only HTTPS pages on configured hostnames, follows only same-allowlist redirects, strips active HTML elements, and limits response size. For official HTML pages that embed PDFs, it follows only PDFs on configured document hosts and extracts at most 100 pages / 1.5 MB of text.
5. Extracts English and Nepali section references and nearby Act/Code names from retrieved text. Extracted provisions carry a source ID and direct link; unverified law names are labeled as such.
6. Automatically chunks and indexes fetched judgment pages in Chroma. The user description is embedded and compared against indexed judgment chunks; repeated chunks from one judgment are collapsed. Similarity is a retrieval signal, not a legal conclusion.
7. If configured, asks an OpenAI-compatible LLM to synthesize only the retrieved material. Citation markers are checked against retrieved source IDs. Without an LLM key, the answer is assembled extractively from cited provisions, cases, and source previews; if evidence is insufficient, it declines to state a legal rule.
8. Returns findings, provisions, similar judgments (with relevance reasons), source citations, limitations, and the legal disclaimer.

## Similarity and document ingestion

Fetched judgment pages are ingested automatically when search returns them from an approved source. This database begins empty; no fabricated starter judgments are included. Semantic results only appear after the agent has fetched case pages or verified documents have been ingested.

For approved source documents, create a UTF-8 JSONL file with one record per line:

```json
{"text":"Full text copied from an approved judgment source","metadata":{"case_name":"Verified title","court":"Court name","date":"2024-01-01","case_number":"Verified number","source_url":"https://supremecourt.gov.np/...","url":"https://supremecourt.gov.np/...","legal_provisions":"Verified provisions","document_type":"case_judgment","authority":"official"}}
```

Then run from `backend/`:

```powershell
$env:PYTHONPATH = "."
py -m app.ingestion.ingest_jsonl path\to\verified-documents.jsonl
```

The ingestion command rejects records without an HTTPS source URL or an explicit `official` authority label. Do not label third-party or unverified text as official. The default source allowlist includes the Nepal government media CDN as a document-only host; it is not queried as a search domain.

## Database and history

Set `DATABASE_URL` to a PostgreSQL connection string and set a stable, high-entropy `AUTH_SECRET` to enable server-side report history. Tables are created at API startup. Browser-local history continues to work when PostgreSQL is not configured or temporarily unavailable. The signed workspace cookie scopes records but is not user authentication; do not expose this API to a public network without adding a real identity provider and deployment hardening. Set `SESSION_COOKIE_SECURE=true` behind HTTPS.

## Tests and checks

Backend:

```powershell
cd backend
py -m pytest -q
py -m ruff check app tests
```

Frontend:

```powershell
cd frontend
npm test
npm run lint
npm run typecheck
npm run build
```

## Security and limitations

- API credentials are backend-only; never put secrets in `NEXT_PUBLIC_*` values.
- Input lengths are bounded, the research endpoint is rate-limited, retrieved active HTML is discarded, and page size/content type/redirects are checked.
- Retrieval is restricted to explicitly configured hostnames. Review a source’s authority before adding it.
- Search indexing is not a complete Nepal case-law database. An empty vector store returns no similar judgments.
- Citation extraction is mechanical. Always open and verify the original judgment or legislation; OCR, dynamic portals, Nepali-language text, and poorly structured pages may not parse.
- A similarity score is not a precedent-strength score and does not predict how a court will decide.
- This app is intended for legal research and educational purposes only. It does not provide legal advice and does not replace a qualified lawyer or official legal authority. Similarity results and AI-generated analysis should be independently verified.
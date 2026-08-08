-- LobbyAI schema — multi-tenant hotel chatbot.
-- Structured tenant data → compiled per-language system prompt (context-stuffed at chat time).
-- No RAG / vector store: small-hotel data fits in one prompt.

CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- gen_random_uuid()

-- ── Tenants: one row per hotel/property ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tenants (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug            TEXT UNIQUE NOT NULL,            -- url-safe handle, e.g. "villa-mara"
    api_key         TEXT UNIQUE NOT NULL,            -- widget public key (data-hotel)
    name            TEXT NOT NULL,
    plan            TEXT NOT NULL DEFAULT 'starter', -- starter | pro
    status          TEXT NOT NULL DEFAULT 'draft',   -- draft | live
    allowed_domains TEXT[] NOT NULL DEFAULT '{}',    -- origin allowlist for the widget
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Config: single row per tenant, structured JSON blocks from the dashboard ────
CREATE TABLE IF NOT EXISTS tenant_config (
    tenant_id  UUID PRIMARY KEY REFERENCES tenants(id) ON DELETE CASCADE,
    basics     JSONB NOT NULL DEFAULT '{}',   -- {address, checkin, checkout, ...}
    services   JSONB NOT NULL DEFAULT '{}',   -- {transfer, parking, breakfast, wifi, pets, ...}
    languages  TEXT[] NOT NULL DEFAULT '{en}',
    welcome    JSONB NOT NULL DEFAULT '{}',   -- {en: "Hi!", de: "Hallo!"}
    fallback   JSONB NOT NULL DEFAULT '{}',   -- {email, phone, text: {en: "...", de: "..."}}
    branding   JSONB NOT NULL DEFAULT '{}',   -- {color, bot_name, logo_url}  (Pro)
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── Rooms: repeatable ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rooms (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id  UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    type       TEXT NOT NULL,
    capacity   INT,
    price      NUMERIC(10,2),
    currency   TEXT DEFAULT 'EUR',
    count      INT DEFAULT 1,
    amenities  JSONB NOT NULL DEFAULT '[]',
    sort       INT DEFAULT 0
);
CREATE INDEX IF NOT EXISTS rooms_tenant_idx ON rooms(tenant_id);

-- ── FAQs: repeatable Q/A, per language ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS faqs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id  UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    lang       TEXT NOT NULL DEFAULT 'en',
    question   TEXT NOT NULL,
    answer     TEXT NOT NULL,
    sort       INT DEFAULT 0
);
CREATE INDEX IF NOT EXISTS faqs_tenant_idx ON faqs(tenant_id);

-- ── Compiled context: what the chat runtime actually loads (per language) ───────
-- Rebuilt only on Publish. Chat never touches the raw tables above.
CREATE TABLE IF NOT EXISTS compiled_context (
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    lang        TEXT NOT NULL,
    prompt_text TEXT NOT NULL,
    compiled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (tenant_id, lang)
);

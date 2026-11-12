CREATE TABLE IF NOT EXISTS summaries (
    id BIGSERIAL PRIMARY KEY,
    message_id TEXT UNIQUE,
    subject TEXT NOT NULL,
    sender TEXT NOT NULL,
    summary TEXT NOT NULL,
    model TEXT NOT NULL,
    received_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS summaries_created_at_idx ON summaries (created_at DESC);

-- backend/db/migrations/002_additional_tables.sql
-- FCM tokens, music library, exports queue, reports, feature flags, A/B tests

-- ─── FCM TOKENS ──────────────────────────────────────────────────────────────
CREATE TABLE fcm_tokens (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    token       TEXT NOT NULL,
    platform    VARCHAR(10) DEFAULT 'android' CHECK (platform IN ('android','ios','web')),
    updated_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, token)
);
CREATE INDEX idx_fcm_user ON fcm_tokens(user_id);

-- ─── MUSIC LIBRARY ────────────────────────────────────────────────────────────
CREATE TABLE music_tracks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title           VARCHAR(255) NOT NULL,
    artist          VARCHAR(255),
    genre           VARCHAR(100),
    mood            VARCHAR(100),
    duration_seconds FLOAT NOT NULL,
    bpm             FLOAT,
    url             TEXT NOT NULL,          -- CDN URL
    waveform_url    TEXT,                   -- pre-rendered waveform image
    thumbnail_url   TEXT,
    tags            TEXT[] DEFAULT '{}',
    is_premium      BOOLEAN DEFAULT FALSE,
    is_active       BOOLEAN DEFAULT TRUE,
    download_count  INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_music_genre ON music_tracks(genre);
CREATE INDEX idx_music_mood  ON music_tracks(mood);
CREATE INDEX idx_music_bpm   ON music_tracks(bpm);
CREATE INDEX idx_music_tags  ON music_tracks USING GIN(tags);

-- ─── SOUND EFFECTS ────────────────────────────────────────────────────────────
CREATE TABLE sound_effects (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(255) NOT NULL,
    category        VARCHAR(100),
    duration_seconds FLOAT,
    url             TEXT NOT NULL,
    is_premium      BOOLEAN DEFAULT FALSE,
    is_active       BOOLEAN DEFAULT TRUE,
    tags            TEXT[] DEFAULT '{}',
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─── STICKER PACKS ───────────────────────────────────────────────────────────
CREATE TABLE sticker_packs (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(255) NOT NULL,
    category    VARCHAR(100),
    thumbnail_url TEXT,
    is_premium  BOOLEAN DEFAULT FALSE,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE stickers (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pack_id     UUID REFERENCES sticker_packs(id) ON DELETE CASCADE,
    name        VARCHAR(255),
    url         TEXT NOT NULL,              -- CDN URL (.png or .gif)
    thumbnail_url TEXT,
    tags        TEXT[] DEFAULT '{}',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_stickers_pack ON stickers(pack_id);

-- ─── FONT LIBRARY ────────────────────────────────────────────────────────────
CREATE TABLE fonts (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    family      VARCHAR(255) NOT NULL UNIQUE,
    display_name VARCHAR(255),
    url         TEXT NOT NULL,              -- CDN .ttf/.otf
    preview_url TEXT,                       -- preview image
    category    VARCHAR(50),                -- serif|sans|display|script|monospace
    is_premium  BOOLEAN DEFAULT FALSE,
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── EXPORTS QUEUE ────────────────────────────────────────────────────────────
CREATE TABLE export_jobs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id      UUID REFERENCES projects(id) ON DELETE CASCADE,
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    status          VARCHAR(20) DEFAULT 'queued' CHECK (status IN ('queued','processing','done','failed','cancelled')),
    quality         VARCHAR(10) NOT NULL CHECK (quality IN ('720p','1080p','4k')),
    watermarked     BOOLEAN DEFAULT FALSE,
    progress        FLOAT DEFAULT 0,
    output_url      TEXT,
    output_size_bytes BIGINT,
    error_message   TEXT,
    priority        INTEGER DEFAULT 0,      -- higher = more priority
    worker_id       TEXT,
    queued_at       TIMESTAMPTZ DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ
);
CREATE INDEX idx_export_jobs_status   ON export_jobs(status);
CREATE INDEX idx_export_jobs_user     ON export_jobs(user_id);
CREATE INDEX idx_export_jobs_project  ON export_jobs(project_id);
CREATE INDEX idx_export_jobs_priority ON export_jobs(priority DESC, queued_at ASC);

-- ─── CONTENT REPORTS ─────────────────────────────────────────────────────────
CREATE TABLE content_reports (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id     UUID REFERENCES users(id) ON DELETE SET NULL,
    target_type     VARCHAR(30) NOT NULL CHECK (target_type IN ('template','user','project','comment')),
    target_id       UUID NOT NULL,
    reason          VARCHAR(100) NOT NULL,
    description     TEXT,
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','reviewed','dismissed','actioned')),
    reviewed_by     UUID REFERENCES admins(id),
    reviewed_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_reports_status ON content_reports(status);
CREATE INDEX idx_reports_target ON content_reports(target_type, target_id);

-- ─── A/B TESTS ───────────────────────────────────────────────────────────────
CREATE TABLE ab_tests (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    variants    JSONB NOT NULL DEFAULT '["control","treatment"]',
    traffic_pct INTEGER DEFAULT 100 CHECK (traffic_pct BETWEEN 0 AND 100),
    is_active   BOOLEAN DEFAULT TRUE,
    started_at  TIMESTAMPTZ DEFAULT NOW(),
    ended_at    TIMESTAMPTZ
);

CREATE TABLE ab_assignments (
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    test_id     UUID REFERENCES ab_tests(id) ON DELETE CASCADE,
    variant     VARCHAR(50) NOT NULL,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, test_id)
);

-- ─── USER FAVORITES ───────────────────────────────────────────────────────────
CREATE TABLE user_favorites (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    type        VARCHAR(20) CHECK (type IN ('template','music','effect','font','sticker')),
    item_id     UUID NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, type, item_id)
);
CREATE INDEX idx_favorites_user ON user_favorites(user_id, type);

-- ─── SEARCH HISTORY ──────────────────────────────────────────────────────────
CREATE TABLE search_history (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    query       VARCHAR(255) NOT NULL,
    type        VARCHAR(20) DEFAULT 'template',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_search_user ON search_history(user_id, created_at DESC);

-- ─── Triggers ────────────────────────────────────────────────────────────────
CREATE TRIGGER trg_export_jobs_updated
BEFORE UPDATE ON export_jobs
FOR EACH ROW EXECUTE FUNCTION update_updated_at();
